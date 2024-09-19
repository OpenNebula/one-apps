require 'init'
require_relative '../../lib/image'
require_relative '../../lib/VMTemplate'
require 'date'
require 'securerandom'

# can cause oom, happens rarely with 20
stress_backups = 5

#
# Things that are hard to pass to rspec as arguments due to rspec things
# and also not suitable as defaults in yamls
#
module BackupTests

    #
    # VM generation code to test in incremental backup tests. Blame rspec for ugly name
    #
    # @return [Array] vm instantiation code that when called will return a CLITester::VM
    #
    def self.incremental_vms
        vm_instantiations = []
        log_msg = 'testing incremental backups with:'

        vm_instantiations << proc do |mode|
            pp "#{log_msg} default VM - #{mode}"

            VM.instantiate(0, true)
        end

        # TODO: test diff file on disk 2
        vm_instantiations << proc do |mode|
            pp "#{log_msg} 2 disks VM - #{mode}"

            vm = VM.instantiate(0, true)

            args = []
            args << CLIImage.random_name('datablock')
            args << 1
            args << '--type DATABLOCK --format qcow2 --size 100M'

            # TODO: Delete after tests finish
            image = CLIImage.create(*args)
            image.ready?

            vm.disk_attach(image.id)

            vm
        end

        vm_instantiations << proc do |mode|
            pp "#{log_msg} Persistent Disk - #{mode}"

            VM.instantiate(0, true, "--persistent --name incp_#{SecureRandom.uuid}")
        end

        # TODO: Test VM with volatile disk
        # TODO: Test VM with SWAP disk
        # TODO: Test VM with file/kernel disk

        vm_instantiations
    end

    # @return [Array] vm instantiation code that when called will return a CLITester::VM
    def self.inplace_vms
        vm_instantiations = []
        log_msg = 'testing inplace restore with:'

        vm_instantiations << proc do |defaults, backup_mode|
            pp "#{log_msg} 2 disks VM - #{backup_mode}"

            vm = VM.instantiate(defaults[:template], true)

            args = []
            args << CLIImage.random_name('datablock')
            args << 1
            args << '--type DATABLOCK --format qcow2 --size 100M --fs ext4'

            image = CLIImage.create(*args)
            image.ready?

            vm.disk_attach(image.id, 'target' => 'vdb')

            vm.set_backup_mode(backup_mode, 4, 'CBT')

            cmds = ['mkdir -p /var/tmp/mnt', 'mount /dev/vdb /var/tmp/mnt']

            cmds.each do |c|
                vm.ssh(c)
            end

            [vm, image]
        end

        vm_instantiations << proc do |defaults, backup_mode|
            pp "#{log_msg} 2 persistent disks VM"

            vm = VM.instantiate(defaults[:template], true,
                                "--persistent --name incp_#{SecureRandom.uuid}")

            args = []
            args << CLIImage.random_name('datablock')
            args << 1
            args << '--type DATABLOCK --format qcow2 --size 100M --fs ext4 --persistent'

            # TODO: Delete after tests finish
            image = CLIImage.create(*args)
            image.ready?

            vm.disk_attach(image.id, 'target' => 'vdb')

            vm.set_backup_mode(backup_mode, 4, 'CBT')

            cmds = ['mkdir -p /var/tmp/mnt',
                    'mount /dev/vdb /var/tmp/mnt']

            cmds.each do |c|
                vm.ssh(c)
            end

            [vm, image]
        end

        vm_instantiations
    end

end

# ------------------------------------------------------------------------------
# INCREMENTAL BACKUP TESTS
# ------------------------------------------------------------------------------
# Accepts VM instantiation code, for example VM.instantiate(0) passed as a block
# backup_ds_type is ResticDS or RsyncDS depending ton the backup drive CLITester interface
shared_examples_for 'incremental backups' do |instantiation, backup_ds_type, imode|
    def backup_iteration(it, vm, ds_id, junk, poff)
        pp "[#{it}] creates diff file inside guest OS"

        vm.file_write("test_file#{it}")

        pp "[#{it}] creates incremental backup"

        vm.poweroff if poff

        b_img_id = vm.backup(ds_id)
        b_img    = CLIImage.new(b_img_id)

        if poff
            vm.resume
            vm.reachable?
        end

        pp "[#{it}] restores incremental backup"

        r_name = "restored_#{SecureRandom.uuid}"
        ids    = b_img.restore(1, "--no_nic --name #{r_name}")

        tmpl = VMTemplate.new(ids[0])

        junk[:templates] << tmpl

        pp "[#{it}] restored backup contains diff files"

        r_vm = tmpl.instantiate(true, '--nic public')

        (0..it).each {|i| r_vm.file_check("test_file#{i}") }

        junk[:vms] << r_vm

        return b_img
    end

    before(:all) do
        @junk = { :datastores => [],
                  :templates  => [],
                  :images     => [],
                  :vms        => [] }
        @info[:n] = @defaults[:keep_last].to_i * 2
    end

    it 'creates datastore for backups' do
        @info[:backup_ds] = backup_ds_type.create(backup_ds_type.random_name, Host.private_ip)
        @junk[:datastores] << @info[:backup_ds]

        @info[:diff_file] = '/var/tmp/asdf'
    end

    it 'creates VM' do
        @info[:vm] = instantiation.call(imode)
        @junk[:vms] << @info[:vm]
    end

    it 'updates VM for incremental backup mode' do
        @info[:vm].set_backup_mode('INCREMENT', nil, imode)
    end

    #####################
    # File verification #
    #####################

    it 'performs incremental backups and check restores' do
        @info[:backup_image] = backup_iteration(0, @info[:vm], @info[:backup_ds].id, @junk, false)
        backup_iteration(1, @info[:vm], @info[:backup_ds].id, @junk, false)
    end

    it 'check poweroff after incremental backups' do
        @info[:vm].poweroff_hard

        @info[:vm].resume

        @info[:vm].reachable?

        @info[:vm].file_check('test_file1')
    end

    it 'check migration after incremental backups' do
        @info[:vm].migrate

        @info[:vm].reachable?

        @info[:vm].file_check('test_file1')

        @info[:vm].migrate_live

        @info[:vm].reachable?

        @info[:vm].file_check('test_file1')
    end

    it 'performs incremental backups and check restores (live/poweroff)' do
        backup_iteration(2, @info[:vm], @info[:backup_ds].id, @junk, false)
        backup_iteration(3, @info[:vm], @info[:backup_ds].id, @junk, true)
        backup_iteration(4, @info[:vm], @info[:backup_ds].id, @junk, true)
    end

    it 'CLI improvements' do
        raw = cli_action('oneimage  list -f type=BK | wc -l').stdout
        sugar = cli_action('oneimage  list --backup | wc -l').stdout

        expect(sugar).to eq(raw)
    end

    it 'deletes incremental backup' do
        @info[:backup_image].delete

        deleted = false

        3.times do
            if @info[:backup_image].deleted_no_fail?(180)
                deleted = true
                break
            end

            @info[:backup_image].delete
        end

        expect(deleted).to be true
    end

    it 'deletes backup operation subproducts' do
        @junk[:vms].flatten!
        @junk[:vms].select! do |vm|
            vm.terminate_hard
            false
        end

        @junk[:templates].flatten!
        @junk[:templates].select! do |template|
            template.delete(true)
            false
        end
    end

    ############################
    # Parallel VMs + KEEP_LAST #
    ############################

    it 'creates VMs (parallel VMs + KEEP_LAST)' do
        @info[:vms] = []
        @defaults[:parallel_vms].to_i.times do
            @info[:vms] << instantiation.call(imode)
        end
        @junk[:vms] << @info[:vms]
    end

    it 'updates VMs for incremental backup mode (parallel VMs + KEEP_LAST)' do
        @info[:vms].each do |vm|
            vm.set_backup_mode('INCREMENT', @defaults[:keep_last], imode)
        end
    end

    it 'creates incremental backups (parallel VMs + KEEP_LAST)' do
        ids_mutex = Mutex.new
        image_ids = []
        threads   = []

        @info[:vms].each do |vm|
            threads << Thread.new do
                @info[:n].times do |t|
                    vm.file_write("#{@info[:diff_file]}#{t}-parallel-VMs-KEEP_LAST")

                    image_id = vm.backup(@info[:backup_ds].id)

                    vm.flatten_inactive?

                    ids_mutex.synchronize { image_ids << image_id }
                end
            end
        end

        threads.each {|t| t.join }

        image_ids.flatten!

        image_ids.uniq!

        @info[:backup_images] = image_ids.map do |image_id|
            CLIImage.new(image_id)
        end

        @junk[:images] << @info[:backup_images]
    end

    it 'confirms counts of increments are exact (parallel VMs + KEEP_LAST)' do
        @info[:backup_images].each do |image|
            count = image.xml.to_hash['IMAGE']['BACKUP_INCREMENTS']['INCREMENT'].size
            expect(count).to eq(@defaults[:keep_last].to_i)
        end
    end

    it 'restores incremental backup (parallel VMs + KEEP_LAST)' do
        @info[:restored_templates] = @info[:backup_images].map do |backup_image|
            name = "restored_#{SecureRandom.uuid}"
            ids  = backup_image.restore(1, "--no_nic --name #{name}")

            VMTemplate.new(ids[0])
        end

        @junk[:templates] << @info[:restored_templates]
    end

    it 'restored backup contains diff files (parallel VMs + KEEP_LAST)' do
        @info[:restored_vms] = @info[:restored_templates].map do |template|
            template.instantiate(true, '--nic public')
        end

        @junk[:vms] << @info[:restored_vms]

        @info[:restored_vms].each do |vm|
            @info[:n].times do |t|
                vm.file_check("#{@info[:diff_file]}#{t}-parallel-VMs-KEEP_LAST")
            end
        end
    end

    it 'restores incremental backup from previous increment (parallel VMs + KEEP_LAST)' do
        @info[:restored_templates] = @info[:backup_images].map do |backup_image|
            name = "restored_#{SecureRandom.uuid}"
            ids  = backup_image.restore(1, "--increment=#{@info[:n] - 2} --no_nic --name #{name}")

            VMTemplate.new(ids[0])
        end

        @junk[:templates] << @info[:restored_templates]
    end

    it 'restored backup contains diff files (parallel VMs + KEEP_LAST)' do
        @info[:restored_vms] = @info[:restored_templates].map do |template|
            template.instantiate(true, '--nic public')
        end

        @junk[:vms] << @info[:restored_vms]

        @info[:restored_vms].each do |vm|
            vm.file_check("#{@info[:diff_file]}#{@info[:n] - 2}-parallel-VMs-KEEP_LAST")
            vm.file_check("#{@info[:diff_file]}#{@info[:n] - 1}-parallel-VMs-KEEP_LAST", false)
        end
    end

    it 'deletes backup operation subproducts (parallel VMs + KEEP_LAST)' do
        @junk[:vms].flatten!
        @junk[:vms].select! do |vm|
            vm.terminate_hard
            false
        end

        @junk[:templates].flatten!
        @junk[:templates].select! do |template|
            template.delete(true)
            false
        end
    end

    ###########
    # Cleanup #
    ###########

    it 'deletes backup datastore' do
        @junk[:images].flatten!
        @junk[:images].select! do |image|
            deleted = false
            12.times do
                image.delete
                if image.deleted_no_fail?(5)
                    deleted = true
                    break
                end
            end
            expect(deleted).to be true
            false
        end
        @junk[:datastores].flatten!
        @junk[:datastores].select! do |datastore|
            datastore.delete
            false
        end
    end
end

# ------------------------------------------------------------------------------
# IN-PLACE RESTORE TESTS
# ------------------------------------------------------------------------------

shared_examples_for 'inplace restore' do |instantiation, backup_ds_type, backup_mode|
    # --------------------------------------------------------------------------
    #  Test initialization
    # --------------------------------------------------------------------------
    it 'creates datastore for backups' do
        @info[:backup_ds] = backup_ds_type.create(backup_ds_type.random_name,
                                                  Host.private_ip)
    end

    it 'creates and setup testing VM ' do
        @info[:vm], @info[:image] = instantiation.call(@defaults, backup_mode)
    end

    it 'creates 3 backups' do
        @info[:backup_id] = []

        # initial backup: clean drives
        @info[:backup_id] << @info[:vm].backup(@info[:backup_ds].id)

        # first backup
        @info[:vm].file_write('/var/tmp/digits', '1234567890')
        @info[:vm].file_write('/var/tmp/mnt/digits', '1234567890')

        @info[:backup_id] << @info[:vm].backup(@info[:backup_ds].id)

        # second backup
        @info[:vm].file_write('/var/tmp/vowels', 'aeiou')
        @info[:vm].file_write('/var/tmp/mnt/vowels', 'aeiou')

        @info[:backup_id] << @info[:vm].backup(@info[:backup_ds].id)
    end

    it 'powers off the VM' do
        @info[:vm].poweroff
    end

    # --------------------------------------------------------------------------
    #  Test cases for inplace restore
    # --------------------------------------------------------------------------
    it 'restores the VM: all disks, selected backup/increment' do
        if backup_mode == 'FULL'
            cmd = "onevm restore #{@info[:vm].id} #{@info[:backup_id][1]}"
        else
            cmd = "onevm restore #{@info[:vm].id} #{@info[:backup_id][0]} --increment 1"
        end

        cli_action(cmd)

        @info[:vm].poweroff?

        @info[:vm].resume

        @info[:vm].running?

        @info[:vm].reachable?

        @info[:vm].ssh('mount /dev/vdb /var/tmp/mnt')

        @info[:vm].file_check('/var/tmp/vowels', false)
        @info[:vm].file_check('/var/tmp/mnt/vowels', false)

        @info[:vm].file_check_contents('/var/tmp/digits', '1234567890')
        @info[:vm].file_check_contents('/var/tmp/mnt/digits', '1234567890')

        @info[:vm].poweroff
    end

    it 'restores the VM: all disks, selected backup/increment (II)' do
        if backup_mode == 'FULL'
            cmd = "onevm restore #{@info[:vm].id} #{@info[:backup_id][2]}"
        else
            # tests last increment by default
            cmd = "onevm restore #{@info[:vm].id} #{@info[:backup_id][0]}"
        end

        cli_action(cmd)

        @info[:vm].poweroff?

        @info[:vm].resume

        @info[:vm].running?

        @info[:vm].reachable?

        @info[:vm].ssh('mount /dev/vdb /var/tmp/mnt')

        @info[:vm].file_check_contents('/var/tmp/vowels', 'aeiou')
        @info[:vm].file_check_contents('/var/tmp/mnt/vowels', 'aeiou')

        @info[:vm].file_check_contents('/var/tmp/digits', '1234567890')
        @info[:vm].file_check_contents('/var/tmp/mnt/digits', '1234567890')

        @info[:vm].poweroff
    end

    it 'restores the VM: a single disk, selected backup/increment' do
        if backup_mode == 'FULL'
            cmd = "onevm restore #{@info[:vm].id} #{@info[:backup_id][0]} --disk-id 2"
        else
            cmd = "onevm restore #{@info[:vm].id} #{@info[:backup_id][0]} --increment 0 --disk-id 2"
        end

        cli_action(cmd)

        @info[:vm].poweroff?

        @info[:vm].resume

        @info[:vm].running?

        @info[:vm].reachable?

        @info[:vm].ssh('mount /dev/vdb /var/tmp/mnt')

        @info[:vm].file_check_contents('/var/tmp/vowels', 'aeiou')
        @info[:vm].file_check('/var/tmp/mnt/vowels', false)

        @info[:vm].file_check_contents('/var/tmp/digits', '1234567890')
        @info[:vm].file_check('/var/tmp/mnt/digits', false)

        @info[:vm].poweroff
    end

    it 'restores the VM: a single disk, selected backup/increment (II)' do
        if backup_mode == 'FULL'
            cmd = "onevm restore #{@info[:vm].id} #{@info[:backup_id][2]} --disk-id 2"
        else
            # tests last increment by default
            cmd = "onevm restore #{@info[:vm].id} #{@info[:backup_id][0]} --disk-id 2"
        end

        cli_action(cmd)

        @info[:vm].poweroff?

        @info[:vm].resume

        @info[:vm].running?

        @info[:vm].reachable?

        @info[:vm].ssh('mount /dev/vdb /var/tmp/mnt')

        @info[:vm].file_check_contents('/var/tmp/vowels', 'aeiou')
        @info[:vm].file_check_contents('/var/tmp/mnt/vowels', 'aeiou')

        @info[:vm].file_check_contents('/var/tmp/digits', '1234567890')
        @info[:vm].file_check_contents('/var/tmp/mnt/digits', '1234567890')

        @info[:vm].poweroff
    end

    # --------------------------------------------------------------------------
    #  Clean up
    # --------------------------------------------------------------------------
    it 'deletes backup operation subproducts (VM, image, datastore)' do
        @info[:vm].terminate_hard

        @info[:image].delete
        @info[:image].deleted_no_fail? 10

        if backup_mode == 'FULL'
            @info[:backup_id].each do |id|
                img = CLIImage.new(id)
                img.delete
                img.deleted_no_fail? 10
            end
        else
            img = CLIImage.new(@info[:backup_id][0])
            img.delete
            img.deleted_no_fail? 10
        end

        @info[:backup_ds].delete
    end
end

# ------------------------------------------------------------------------------
# FULL BACKUP TESTS
# ------------------------------------------------------------------------------
shared_examples_for 'full backups' do |backup_ds_type|
    after(:all) do
        # May fail if some other tests left image on the DS
        @info[:backup_ds].delete
    end

    it 'creates datastore for backups' do
        @info[:backup_ds] = backup_ds_type.create(backup_ds_type.random_name, Host.private_ip)
    end

    ########
    # Main #
    ########

    context "Full backup live" do
        it 'creates VM with SSH access' do
            @info[:vm] = VM.instantiate("#{@defaults[:template]}-cd", true)
            # Attach volatile disk, do not backup it
            cli_update("onevm disk-attach #{@info[:vm].id} --file",
                    'DISK = [ TYPE = fs, SIZE = 32 ]', false)
            @info[:vm].running?
        end

        it 'creates file diff file inside Guest OS' do
            @info[:vm].file_write
        end

        # Error creating backup: [one.vm.backup]
        # Could not create a new backup for VM 98, wrong state BACKUP.
        it 'VM is locked on backup status' do
            cmd = "onevm backup #{@info[:vm].id} -d #{@info[:backup_ds].id}"
            cli_action(cmd)
            cli_action(cmd, false)
        end

        it 'backs up VM' do
            @info[:vm].running?
            expect(@info[:vm].backups?).to be true

            image = CLIImage.new(@info[:vm].backup_id)
            expect(image.xml['BACKUP_DISK_IDS/ID']).to eq('0')
        end

        it 'deletes VM' do
            @info[:vm].terminate_hard
        end

        it 'deletes backup datastore, it should fail' do
            @info[:backup_ds].delete_fail
        end

        it 'restores a single disk from backup image' do
            image = CLIImage.new(@info[:vm].backup_id)
            ids = image.restore(1, '--disk_id 0 --name single_disk_restore')

            expect(ids.size).to eq (1)

            @info[:restored_image] = CLIImage.new(ids[0])
        end

        it 'delete restored image' do
            @info[:restored_image].ready?

            @info[:restored_image].delete
        end

        it 'restores a VM backup from backup image' do
            image = CLIImage.new(@info[:vm].backup_id)
            ids = image.restore
            @info[:restored_template] = VMTemplate.new(ids[0])

            @info[:backup_image] = image
        end

        it 'deploys restored VM Template' do
            @info[:vm] = @info[:restored_template].instantiate(true)
        end

        it 'restored backup contains diff file' do
            expect(@info[:vm].xml['TEMPLATE/DISK/DISK_ID']).to eq('012')
            @info[:vm].file_check
        end

        it 'deletes restored VM Template' do
            @info[:restored_template].delete(true)
        end

        it 'deletes backup image' do
            @info[:backup_image].delete
        end

        it 'deletes VM' do
            @info[:vm].terminate_hard
        end
    end

    #############
    # Power Off #
    #############
    context "Full backup poweroff" do
        it 'creates VM with SSH access' do
            @info[:vm] = VM.instantiate(@defaults[:template], true)
            # Attach volatile disk, do not backup it
            cli_update("onevm disk-attach #{@info[:vm].id} --file",
                    'DISK = [ TYPE = fs, SIZE = 32 ]', false)
            @info[:vm].running?
        end

        it 'creates file diff file inside Guest OS' do
            @info[:vm].file_write
        end

        # Error creating backup: [one.vm.backup]
        it 'creates backup in poweroff state' do
            @info[:vm].poweroff

            cmd = "onevm backup #{@info[:vm].id} -d #{@info[:backup_ds].id}"
            cli_action(cmd)

            @info[:vm].poweroff?
            expect(@info[:vm].backups?).to be true

            @info[:vm].terminate_hard
        end

        it 'restores a VM backup from backup image and check file' do
            image = CLIImage.new(@info[:vm].backup_id)
            ids = image.restore
            @info[:restored_template] = VMTemplate.new(ids[0])

            @info[:backup_image] = image

            @info[:vm] = @info[:restored_template].instantiate(true)

            @info[:vm].file_check
        end

        it 'deletes backup files and VM' do
            @info[:restored_template].delete(true)

            @info[:backup_image].delete

            @info[:vm].terminate_hard
        end
    end

    ###############
    # CUSTOM PATH #
    ###############
    context "Full backup custom path" do
        it 'Backup datastore config' do
            path = '/var/lib/one/remotes/etc/datastore/datastore.conf'

            system("cp #{path} #{path}.backup")

            File.open(path, 'a') do |f|
                f.write('BACKUP_BASE_PATH="/var/tmp/backups"')
            end

            system('onehost forceupdate')
        end

        it 'creates VM with SSH access' do
            @info[:vm] = VM.instantiate(@defaults[:template], true)
        end

        it 'creates file diff file inside Guest OS' do
            @info[:vm].file_write
        end

        # Error creating backup: [one.vm.backup]
        it 'creates backup in poweroff state' do
            @info[:vm].poweroff

            cmd = "onevm backup #{@info[:vm].id} -d #{@info[:backup_ds].id}"
            cli_action(cmd)

            @info[:vm].poweroff?
            expect(@info[:vm].backups?).to be true

            @info[:vm].terminate_hard
        end

        it 'restores a VM backup from backup image and check file' do
            image = CLIImage.new(@info[:vm].backup_id)
            ids = image.restore
            @info[:restored_template] = VMTemplate.new(ids[0])

            @info[:backup_image] = image

            @info[:vm] = @info[:restored_template].instantiate(true)

            @info[:vm].file_check
        end

        it 'deletes backup files and VM' do
            @info[:restored_template].delete(true)

            @info[:backup_image].delete

            @info[:vm].terminate_hard
        end

        it 'Restore datastore config' do
            path = '/var/lib/one/remotes/etc/datastore/datastore.conf'

            system("cp #{path}.backup #{path}")

            system('onehost forceupdate')
        end
    end

    ###############
    # Persistency #
    ###############

    context "Full backup persistency" do
        it 'creates VM with persitent image' do
            name = "persistent_#{SecureRandom.uuid}"
            options = "--persistent --name #{name}"

            @info[:vm] = VM.instantiate(@defaults[:template], true, options)
            @info[:persistent_template] = VMTemplate.new(name)
        end

        it 'creates file diff file inside Guest OS' do
            @info[:vm].file_write
        end

        it 'backs up VM with persitent image' do
            @info[:vm].backup(@info[:backup_ds].id)
        end

        it 'deletes VM with persitent image' do
            @info[:vm].terminate_hard
        end

        it 'restores a VM backup from backup image' do
            image = CLIImage.new(@info[:vm].backup_id)
            ids = image.restore
            @info[:restored_template] = VMTemplate.new(ids[0])

            @info[:backup_image] = image
        end

        it 'deploys restored VM Template' do
            @info[:vm] = @info[:restored_template].instantiate(true)
        end

        it 'restored backup contains diff file' do
            @info[:vm].file_check
        end

        it 'deletes restored VM Template' do
            @info[:restored_template].delete(true)
        end

        it 'deletes backup image' do
            @info[:backup_image].delete
        end

        it 'deletes VM' do
            @info[:vm].terminate_hard
        end

        it 'deletes persistent VM Template' do
            @info[:persistent_template].delete(true)
        end
    end

    #################
    # Volatile disk #
    #################

    context "Full backup volatile disk" do
        it 'creates VM with SSH access' do
            @info[:vm] = VM.instantiate(@defaults[:template], true)
            # Attach volatile disk, do not backup it
            cli_update("onevm disk-attach #{@info[:vm].id} --target vdb --file",
                    'DISK = [ TYPE = fs, SIZE = 32 ]', false)
            @info[:vm].running?

            cli_update("onevm updateconf #{@info[:vm].id}", "BACKUP_CONFIG=[BACKUP_VOLATILE=YES]", true)
        end

        it 'creates file diff file inside Guest OS' do
            @info[:vm].file_write
        end

        it 'backs up VM' do
            cmd = "onevm backup #{@info[:vm].id} -d #{@info[:backup_ds].id}"
            cli_action(cmd)
            @info[:vm].running?
            expect(@info[:vm].backups?).to be true

            image = CLIImage.new(@info[:vm].backup_id)
            expect(image.xml['BACKUP_DISK_IDS/ID']).to eq('02')
        end

        it 'deletes VM' do
            @info[:vm].terminate_hard
        end

        it 'restores a single disk from backup image' do
            image = CLIImage.new(@info[:vm].backup_id)
            ids = image.restore(1, '--disk_id 0 --name single_disk_restore')

            expect(ids.size).to eq (1)

            @info[:restored_image] = CLIImage.new(ids[0])
        end

        it 'delete restored image' do
            @info[:restored_image].ready?

            @info[:restored_image].delete
        end

        it 'restores a VM backup from backup image' do
            image = CLIImage.new(@info[:vm].backup_id)
            ids = image.restore
            @info[:restored_template] = VMTemplate.new(ids[0])

            @info[:backup_image] = image
        end

        it 'deploys restored VM Template' do
            @info[:vm] = @info[:restored_template].instantiate(true)
        end

        it 'restored backup contains diff file' do
            expect(@info[:vm].xml['TEMPLATE/DISK/DISK_ID']).to eq('01')
            @info[:vm].file_check
        end

        it 'deletes restored VM Template' do
            @info[:restored_template].delete(true)
        end

        it 'deletes backup image' do
            @info[:backup_image].delete
        end

        it 'deletes VM' do
            @info[:vm].terminate_hard
        end
    end

    # TODO: Move to func ?
    ################
    # regular user #
    ################

    context "Full backup regular user" do
        it 'setup readiness user' do
            user = "readiness_#{SecureRandom.uuid}"
            password = 'readiness'

            pp "using user: #{user}"

            cmds = []
            cmds << "oneuser create #{user} #{password}"
            cmds << "oneimage chown 0 #{user} users"
            cmds << "onedatastore chown #{@info[:backup_ds].id} #{user} users"
            cmds << "onedatastore chown 0 #{user} users"

            cmds.each do |cmd|
                cli_action(cmd)
            end

            @info[:user]   = user
            @info[:auth] = "--user #{user} --password #{password}"
        end

        it 'creates vm as readiness user' do
            @info[:vm] = VM.create('readiness_vm', "--cpu 1 --memory 128 --disk 0 #{@info[:auth]}")
        end

        # Error creating VM backup: [one.vm.backup] User [18] : Not authorized to perform ADMIN VM [240]
        it 'fails to create instant backup as readiness user' do
            @info[:vm].backup_fail(@info[:backup_ds].id, args: @info[:auth])
        end

        it 'creates scheduled backup as readiness user' do
            @info[:vm].backup(@info[:backup_ds].id, args: "--schedule now #{@info[:auth]}")
        end

        it 'deletes readiness user VM' do
            @info[:vm].terminate_hard
        end

        it 'restores VM backup as readiness user' do
            image = CLIImage.new(@info[:vm].backup_id)
            ids = image.restore(1, @info[:auth])
            @info[:restored_template] = VMTemplate.new(ids[0])

            @info[:backup_image] = image
        end

        it 'deletes restored template as readiness user' do
            @info[:restored_template].delete(true, @info[:auth])
        end

        it 'deletes backup image as readiness user' do
            @info[:backup_image].delete
        end

        it 'uninstall readiness user' do
            cmds = []
            cmds << 'oneimage chown 0 oneadmin oneadmin'
            cmds << 'onedatastore chown 0 oneadmin oneadmin'
            cmds << "oneuser delete #{@info[:user]}"

            cmds.each do |cmd|
                cli_action(cmd)
            end
        end
    end

    ##########
    # Stress #
    ##########

    context "Full backup stress" do
        it 'instantiates VM' do
            @info[:vm] = VM.instantiate(@defaults[:template])
        end

        # Backups are not concurrent as the VM.backup waits for the VM to return to its previous state
        it "STRESS: Creates #{stress_backups} backups" do
            stress_backups.times do |t|
                pp "creating backup #{t}"
                @info[:vm].backup(@info[:backup_ds].id)
            end
        end

        # Restores are issued 1 by 1
        it "STRESS: Restores #{stress_backups} backups" do
            restored_templates = [] # restored VM template IDs from image backup

            backup_image = CLIImage.new(@info[:vm].backup_id)
            backup_image.rename(CLIImage.random_name)

            stress_backups.times do
                ids  = backup_image.restore(1)
                name = "restored_#{SecureRandom.uuid}"

                template = VMTemplate.new(ids[0])
                template.rename(name)

                ids[1..-1].each do |i|
                    image = CLIImage.new(i)
                    image.rename("#{i}_#{name}")
                end

                restored_templates << template
            end

            @info[:restored_templates] = restored_templates
        end

        it "STRESS: Deletes #{stress_backups} restored templates" do
            @info[:restored_templates].each do |template|
                pp "deleting template #{template.name}"
                template.delete(true)
            end
        end

        it 'deletes VM' do
            @info[:vm].terminate_hard
        end

        # Deletion is concurrent
        it "STRESS: Deletes #{stress_backups} backups" do
            threads = []

            filter = "-l ID -f TYPE=BK,DATASTORE=#{@info[:backup_ds].name}  --size \"DATASTORE=50\""

            backup_images = CLIImage.list(filter)
            backup_images.each {|i| i.delete!(' ') }

            expect(backup_images.size >= stress_backups).to be(true)

            t_ini = Time.now.to_i

            backup_images.each do |i|
                threads << Thread.new do
                    image = CLIImage.new(i)
                    pp "deleting image #{image.name}"

                    image.delete

                    deleted = false

                    3.times do
                        if image.deleted_no_fail?(180)
                            deleted = true
                            break
                        end

                        image.delete
                    end

                    expect(deleted).to be true
                end
            end

            pp 'Waiting for images to be deleted from image_pool'
            threads.each {|t| t.join }
            pp "took #{Time.now.to_i - t_ini}s to delete #{backup_images.size} backups"
        end
    end
end

shared_examples_for 'prebackup cancel' do |backup_ds_type|
    before(:all) do
        @info[:datablock_size] = 20 * 1024

        @info[:increment] = 0

        @info[:timeout] = 60

        @to_timestamp = ->(line) {
            tokens = line.strip.split(%[ ], 7)[0..5]
            if tokens.count == 6
                DateTime.parse(tokens.join(%[ ])).to_time.to_i
            else
                0
            end
        }

        @init_datablocks = ->(vm, dev) {
            vm.ssh <<~CMD
                mkfs.ext4 /dev/#{dev};
                install -d /#{dev};
                if ! grep -m1 /dev/#{dev} /etc/fstab; then
                    echo '/dev/#{dev} /#{dev} ext4 defaults,noatime,nodiratime 0 1' >> /etc/fstab
                fi
                mount /dev/#{dev}
            CMD
        }

        @replace_data = ->(vm, dev, incr = 2) {
            vm.ssh <<~CMD
                dd if=/dev/urandom bs=1024 count=#{incr*1024**2} > /#{dev}/data;
            CMD
        }

        @append_data = ->(vm, dev, incr = 2) {
            vm.ssh <<~CMD
                dd if=/dev/urandom bs=1024 count=#{incr*1024**2} >> /#{dev}/data;
            CMD
        }

        @junk = {:datastores => [],
                 :images     => [],
                 :vms        => []}
    end

    it 'creates datastore for backups' do
        @info[:backup_ds] = backup_ds_type.create backup_ds_type.random_name,
                                                  Host.private_ip
        @junk[:datastores] << @info[:backup_ds]
    end

    it 'creates VM with datablocks' do
        @info[:vms] = []
        @info[:vms] << VM.instantiate(@defaults[:template], true)
        @junk[:vms] << @info[:vms]

        db1 = CLIImage.create(CLIImage.random_name, 1,
                              "--type DATABLOCK --format qcow2 --prefix vd --size #{@info[:datablock_size]}")
        db1.ready?

        db2 = CLIImage.create(CLIImage.random_name, 1,
                              "--type DATABLOCK --format qcow2 --prefix vd --size #{@info[:datablock_size]}")
        db2.ready?

        @junk[:images] << [db1.id, db2.id]

        @info[:vms][0].running?
        @info[:vms][0].disk_attach(db1.id)
        @info[:vms][0].running?
        @info[:vms][0].disk_attach(db2.id)

        @info[:vms][0].running?
        @init_datablocks.call(@info[:vms][0], 'vdb')
        @init_datablocks.call(@info[:vms][0], 'vdc')

        @info[:host] = Host.new(@info[:vms][0].host_id)
    end

    it "pushes data increment into each datablock, creates full backups (live), measures time, repeats until the duration is enough" do
        @info[:vms][0].set_backup_mode('FULL')
        10.times do |index|
            @info[:increment] += 2 # GiB
            @append_data.call(@info[:vms][0], 'vdb', 2)
            @append_data.call(@info[:vms][0], 'vdc', 2)

            @info[:vms][0].running?
            @info[:vms][0].backup(@info[:backup_ds].id, wait: true)
            @junk[:images] << @info[:vms][0].backup_ids

            vm_log = cli_action("cat /var/log/one/#{@info[:vms][0].id}.log").stdout.lines

            start = @to_timestamp.call vm_log.grep(/New LCM state is BACKUP/)&.last
            stop  = @to_timestamp.call vm_log.grep(/Successfully execute transfer manager driver operation: prebackup_live/)&.last

            warn "stop - start = #{stop - start}"

            break if stop - start >= 10 # seconds
        end
        @info[:vms][0].running?
    end

    it 'creates full backups and cancels them early (poff)' do
        @info[:vms][0].set_backup_mode('FULL')
        @info[:vms][0].poweroff_hard
        2.times do
            @info[:vms][0].state?('POWEROFF', timeout: @info[:timeout])
            @info[:vms][0].backup(@info[:backup_ds].id, wait: false)
            @info[:vms][0].backing_up?('POWEROFF')
            sleep 3
            @info[:vms][0].backup_cancel('POWEROFF')
            sleep @info[:timeout]
        end
        @info[:vms][0].state?('POWEROFF', timeout: @info[:timeout])
    end

    it 'creates full backups and cancels them early (live)' do
        @info[:vms][0].set_backup_mode('FULL')
        @info[:vms][0].resume
        2.times do
            @info[:vms][0].running?(timeout: @info[:timeout])
            @info[:vms][0].backup(@info[:backup_ds].id, wait: false)
            @info[:vms][0].backing_up?('RUNNING')
            sleep 3
            @info[:vms][0].backup_cancel('RUNNING')
            sleep @info[:timeout]
        end
        @info[:vms][0].running?(timeout: @info[:timeout])
    end

    it 'creates full backup (poff)' do
        @info[:vms][0].set_backup_mode('FULL')
        @info[:vms][0].poweroff_hard
        @info[:vms][0].backup(@info[:backup_ds].id, wait: true)
        @junk[:images] << @info[:vms][0].backup_ids
        @info[:vms][0].state?('POWEROFF', timeout: @info[:timeout])
    end

    it 'creates full backup (live)' do
        @info[:vms][0].set_backup_mode('FULL')
        @info[:vms][0].resume
        @info[:vms][0].backup(@info[:backup_ds].id, wait: true)
        @junk[:images] << @info[:vms][0].backup_ids
        @info[:vms][0].running?(timeout: @info[:timeout])
    end

    it "pushes data increment into each datablock, triggers incremental backups and stops them in pre-backup (live)" do
        skip 'unsupported' unless @info[:host].incremental_backups?
        @info[:vms][0].set_backup_mode('INCREMENT')
        @info[:vms][0].running?
        @replace_data.call(@info[:vms][0], 'vdb', @info[:increment])
        @replace_data.call(@info[:vms][0], 'vdc', @info[:increment])
        3.times do
            @info[:vms][0].running?(timeout: @info[:timeout])
            @info[:vms][0].backup(@info[:backup_ds].id, wait: false)
            @info[:vms][0].backing_up?('RUNNING')
            sleep 3
            @info[:vms][0].backup_cancel('RUNNING')
            sleep @info[:timeout]
        end
        @info[:vms][0].running?(timeout: @info[:timeout])
    end

    it 'creates incremental backup (live)' do
        skip 'unsupported' unless @info[:host].incremental_backups?
        @info[:vms][0].set_backup_mode('INCREMENT')
        @info[:vms][0].backup(@info[:backup_ds].id, wait: true)
        @junk[:images] << @info[:vms][0].backup_ids
        @info[:vms][0].running?(timeout: @info[:timeout])
    end

    it 'pushes data increment into each datablock, triggers incremental backups and stops them in pre-backup (poff)' do
        skip 'unsupported' unless @info[:host].incremental_backups?
        @info[:vms][0].set_backup_mode('INCREMENT')
        @info[:vms][0].running?
        @replace_data.call(@info[:vms][0], 'vdb', @info[:increment])
        @replace_data.call(@info[:vms][0], 'vdc', @info[:increment])
        @info[:vms][0].poweroff_hard
        3.times do
            @info[:vms][0].state?('POWEROFF', timeout: @info[:timeout])
            @info[:vms][0].backup(@info[:backup_ds].id, wait: false)
            @info[:vms][0].backing_up?('POWEROFF')
            sleep 3
            @info[:vms][0].backup_cancel('POWEROFF')
            sleep @info[:timeout]
        end
        @info[:vms][0].state?('POWEROFF', timeout: @info[:timeout])
    end

    it 'creates incremental backup (poff)' do
        skip 'unsupported' unless @info[:host].incremental_backups?
        @info[:vms][0].set_backup_mode('INCREMENT')
        @info[:vms][0].backup(@info[:backup_ds].id, wait: true)
        @junk[:images] << @info[:vms][0].backup_ids
        @info[:vms][0].state?('POWEROFF', timeout: @info[:timeout])
    end

    it 'looks for common exceptions in the VM log' do
        vm_log = cli_action("cat /var/log/one/#{@info[:vms][0].id}.log").stdout.lines
        expect(vm_log.grep(%r{No space left on .*device}i)).to be_empty
        expect(vm_log.grep(%r{Error preparing disk files}i)).to be_empty
    end

    it 'checks if there are no leftover backup_qcow2.rb processes' do
        @defaults[:hosts].each do |host|
            found = cli_action("ssh #{host} ps --no-headers -o cmd -C ruby").stdout.lines.select do |cmd|
                cmd.include?('backup_qcow2.rb')
            end
            expect(found).to be_empty
        end
    end

    ###########
    # Cleanup #
    ###########
    it 'deletes backup datastore' do
        @junk[:vms].flatten!
        @junk[:vms].select! {|vm| vm.terminate_hard; false }
        @junk[:images].flatten!
        @junk[:images].uniq!
        @junk[:images].map! do |image_id|
            CLIImage.new(image_id)
        end
        @junk[:images].each do |image|
            image.delete
        end
        @junk[:images].select! do |image|
            deleted = false
            3.times do
                if image.deleted_no_fail?(30)
                    deleted = true
                    break
                end

                image.delete
            end

            expect(deleted).to be true
        end
        @junk[:datastores].flatten!
        @junk[:datastores].select! {|datastore| datastore.delete; false }
    end
end

shared_examples_for 'backup cancel' do |backup_ds_type|
    before(:all) do
        @junk = {:datastores => [],
                 :images     => [],
                 :vms        => []}
    end

    it 'creates slow datastore for backups' do
        @info[:backup_ds] = backup_ds_type.create_slow backup_ds_type.random_name,
                                                       Host.private_ip
        @junk[:datastores] << @info[:backup_ds]
    end

    it 'creates VMs' do
        @info[:vms] = []
        @defaults[:parallel_vms].to_i.times do
            @info[:vms] << VM.instantiate(@defaults[:template], true)
        end
        @junk[:vms] << @info[:vms]
    end

    it 'starts backups then cancels them asynchronously' do
        @info[:vms].each do |vm|
            vm.backup(@info[:backup_ds].id, wait: false)
        end
        @info[:vms].each do |vm|
            vm.backup_cancel('RUNNING')
        end
        @info[:vms].each do |vm|
            vm.running?
        end
        @info[:backup_images] = @info[:vms].map do |vm|
            vm.backup_ids
        end.flatten.map do |image_id|
            CLIImage.new(image_id)
        end
        @junk[:images] << @info[:backup_images]
    end

    it 'verifies that the list of backup images is empty' do
        expect(@info[:backup_images]).to be_empty
    end

    ###########
    # Cleanup #
    ###########

    it 'deletes backup datastore' do
        @junk[:vms].flatten!
        @junk[:vms].select! {|vm| vm.terminate_hard; false }
        @junk[:images].flatten!
        @junk[:images].each do |image|
            image.delete
        end
        @junk[:images].select! do |image|
            deleted = false
            3.times do
                if image.deleted_no_fail?(30)
                    deleted = true
                    break
                end

                image.delete
            end

            expect(deleted).to be true
        end
        @junk[:datastores].flatten!
        @junk[:datastores].select! {|datastore| datastore.delete; false }
    end
end

shared_examples_for 'backup job' do |backup_ds_type|
    it 'creates datastore for backups' do
        @info[:backup_ds] = backup_ds_type.create(backup_ds_type.random_name, Host.private_ip)
    end

    it 'creates VMs' do
        @info[:vm1] = VM.instantiate(@defaults[:template], true)
        @info[:vm2] = VM.instantiate(@defaults[:template], true)
    end

    it 'creates Backup Job' do
        bj_template = <<-EOT
            NAME = backup_job_#{SecureRandom.uuid}
            DATASTORE_ID = "#{@info[:backup_ds].id}"
            BACKUP_VMS = "#{@info[:vm1].id},#{@info[:vm2].id}"
            MODE       = "FULL"
        EOT

        @info[:bj] = cli_create('onebackupjob create', bj_template)
    end

    it 'execute Backup Job' do
        cli_action("onebackupjob backup #{@info[:bj]}")
    end

    it 'backs up VMs' do
        wait_loop() do
            @info[:vm1].backups?
        end

        wait_loop() do
            @info[:vm2].backups?
        end
    end

    it 'cleans up' do
        image1 = CLIImage.new(@info[:vm1].backup_id)
        image1.delete

        image2 = CLIImage.new(@info[:vm2].backup_id)
        image2.delete

        image1.deleted_no_fail?(30)
        image2.deleted_no_fail?(30)

        @info[:vm1].terminate_hard
        @info[:vm2].terminate_hard

        cli_action("onebackupjob delete #{@info[:bj]}")

        @info[:backup_ds].delete
    end
end
