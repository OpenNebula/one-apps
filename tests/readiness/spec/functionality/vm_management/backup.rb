
require 'init_functionality'
require 'securerandom'
require 'image'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

describe "VM Backup and restore" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults_with_sched.yaml')
    end

    before(:all) do
        @defaults = RSpec.configuration.defaults
        @info = {}

        # Use custom cp script for this test
        @cp_dummy = "#{ONE_VAR_LOCATION}/remotes/datastore/dummy/cp"
        @rm_dummy = "#{ONE_VAR_LOCATION}/remotes/datastore/dummy/rm"

        FileUtils.mv(@cp_dummy, "#{@cp_dummy}.orig")

        File.open(@cp_dummy, File::CREAT|File::TRUNC|File::RDWR, 0744) { |f|
            f.write("#!/bin/bash\n")
            f.write("echo \"dummy_path QCOW2\"\n")
        }

        @ds_template = <<~EOT
            NAME="dummy backups #{SecureRandom.uuid}"
            DS_MAD=dummy
            TM_MAD=-
            TYPE=BACKUP_DS
        EOT

        cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)
        cli_update("onedatastore update system", "TM_MAD=dummy", false)

        cli_create("onehost create host0 --im dummy --vm dummy")
    end

    after(:all) do
        FileUtils.mv("#{@cp_dummy}.orig", @cp_dummy)
    end

    it 'creates datastore for backups' do
        id = cli_create("onedatastore create", @ds_template)

        expect(id.to_i).to be >= 100

        @info[:backup_ds_id] = id
    end

    ########
    # Main #
    ########

    it 'deploy VM' do
        img_id = cli_create("oneimage create -d 1", <<-EOT)
            NAME = "test_img"
            PATH = "/tmp/none"
        EOT

        @info[:img_id] = img_id

        wait_loop() do
            xml = cli_action_xml("oneimage show -x #{img_id}")
            Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
        end

        vm_template = <<-EOF
            NAME   = test_vm
            CPU    = 1
            MEMORY = 1024
            DISK   = [
                IMAGE_ID=#{img_id}
            ]
            BACKUP_CONFIG=[
                MODE = "FULL",
                KEEP_LAST = 2
            ]
        EOF

        @info[:vm_id] = cli_create("onevm create", vm_template)
        @info[:vm] = VM.new(@info[:vm_id])

        cli_action("onevm deploy #{@info[:vm_id]} host0")

        @info[:vm].running?
    end

    it 'backup VM' do
        cli_action("onevm backup #{@info[:vm_id]} -d #{@info[:backup_ds_id]}")

        @info[:vm].running?
        expect(@info[:vm].backup_ids.empty?).to be false

        xml = cli_action_xml("oneimage show -x #{@info[:vm].backup_id}")

        expect(xml['BACKUP_DISK_IDS/ID']).to eq('0')
    end

    it 'fail to delete used backup datastore' do
        cli_action("onedatastore delete #{@info[:backup_ds_id]}", false, true)
    end

    it 'restores a VM backup' do
        cmd = cli_action("oneimage restore #{@info[:vm].backup_id} -d 1")

        # parse "VM Template: 19\nImages: 92\n"
        @info[:backup_restored_id] = cmd.stdout.split("\n")[0].split(':')[1].gsub(' ', '')

        # dummy driver, we can't do anything with restored backup
    end

    it 'backup retention' do
        # Create second backup
        cli_action("onevm backup #{@info[:vm_id]} -d #{@info[:backup_ds_id]}")

        @info[:vm].running?

        expect(@info[:vm].backup_ids.size).to eq 2

        old_backup = @info[:vm].backup_ids[0]

        sleep 1 # Creating 2 backups in one second may cause image name collision

        # Create third backup
        cli_action("onevm backup #{@info[:vm_id]} -d #{@info[:backup_ds_id]}")

        @info[:vm].running?

        expect(@info[:vm].backup_ids.size).to eq 2

        cli_action("oneimage show #{old_backup}", false)
    end

    it 'fail to backup if not enough space on backup datastore' do
        # Set limit size on backup datastore
        cli_update("onedatastore update #{@info[:backup_ds_id]}", "LIMIT_MB=500\nDATASTORE_CAPACITY_CHECK=YES", true)

        # Fail to create backup
        cli_action("onevm backup #{@info[:vm_id]} -d #{@info[:backup_ds_id]}", false)

        # Set no check capacity on backup datastore
        cli_update("onedatastore update #{@info[:backup_ds_id]}", 'DATASTORE_CAPACITY_CHECK=NO', true)

        # Create backup
        cli_action("onevm backup #{@info[:vm_id]} -d #{@info[:backup_ds_id]}")
    end

    ################
    # regular user #
    ################

    # # Error creating VM backup: [one.vm.backup] User [18] : Not authorized to perform ADMIN VM [240]
    it 'fails to create instant backup as regular user' do
        cli_create_user('a', 'a')
        cli_action('oneuser chgrp a users')

        cli_action("onevm chown #{@info[:vm_id]} a users")
        cli_action("onedatastore chown #{@info[:backup_ds_id]} a users")

        as_user('a') do
            cli_action("onevm backup #{@info[:vm_id]} -d #{@info[:backup_ds_id]}", false)
        end
    end

    it 'creates scheduled backup as regular user' do
        quota_template = <<-EOF
            DATASTORE   = [
                ID = #{@info[:backup_ds_id]},
                IMAGES = 3,
                SIZE = 1500
            ]
        EOF

        cli_update('oneuser quota a', quota_template, false)

        last_backup = @info[:vm].backup_id

        as_user('a') do
            cli_action("onevm backup #{@info[:vm_id]} -d #{@info[:backup_ds_id]} --schedule now")
        end

        # Wait Scheduled Action executed
        wait_loop(:success => true, :timeout => 30) do
            @info[:vm].xml['TEMPLATE/SCHED_ACTION/DONE'].to_i > 0
        end

        @info[:vm].running?

        expect(@info[:vm].backup_id).not_to eq last_backup
    end

    it 'count datastore quota for regular user' do
        xml = cli_action_xml('oneuser show a -x')

        expect(xml['DATASTORE_QUOTA/DATASTORE/IMAGES_USED'].to_i).to eq(1)
        expect(xml['DATASTORE_QUOTA/DATASTORE/SIZE_USED'].to_i).to eq(1024)
    end

    it 'quota in case of backup failure' do
        @info[:vm].safe_undeploy

        cli_action("onevm backup #{@info[:vm_id]} -d #{@info[:backup_ds_id]}", false)

        xml = cli_action_xml('oneuser show a -x')

        expect(xml['DATASTORE_QUOTA/DATASTORE/IMAGES_USED'].to_i).to eq(1)
        expect(xml['DATASTORE_QUOTA/DATASTORE/SIZE_USED'].to_i).to eq(1024)
    end

    it 'fail to backup if exceeds quota' do
        cli_action("onevm deploy #{@info[:vm_id]} host0")
        @info[:vm].running?

        cli_action("onevm backup #{@info[:vm_id]} -d #{@info[:backup_ds_id]}", false)

        @info[:vm].running?

        xml = cli_action_xml('oneuser show a -x')

        expect(xml['DATASTORE_QUOTA/DATASTORE/IMAGES_USED'].to_i).to eq(1)
        expect(xml['DATASTORE_QUOTA/DATASTORE/SIZE_USED'].to_i).to eq(1024)
    end

    # todo: More quota tests: backup failed should revert quotas

    #######################
    # Incremental Backups #
    #######################

    it 'creates incremental backups' do
        # Remove user quotas
        quota_template = <<-EOF
            DATASTORE   = [
                ID = #{@info[:backup_ds_id]},
                IMAGES = -1,
                SIZE = -1
            ]
        EOF

        cli_update('oneuser quota a', quota_template, false)

        expect(@info[:vm].xml['BACKUPS/BACKUP_CONFIG/MODE']).to eq "FULL"

        cli_update("onevm updateconf #{@info[:vm_id]}",
                   'BACKUP_CONFIG=[MODE="INCREMENT"]',
                   true)

        xml = @info[:vm].xml
        expect(xml['BACKUPS/BACKUP_CONFIG/MODE']).to eq "INCREMENT"
        expect(xml['BACKUPS/BACKUP_CONFIG/KEEP_LAST']).to eq "2" # Bug in backup append

        last_backup = @info[:vm].backup_id

        # First incremental backup, creates a new backup id
        cli_action("onevm backup #{@info[:vm_id]} -d #{@info[:backup_ds_id]}")

        @info[:vm].running?
        expect(@info[:vm].backup_id).not_to eq last_backup
        expect(@info[:vm].xml['BACKUPS/BACKUP_CONFIG/LAST_INCREMENT_ID']).to eq "0"

        last_backup = @info[:vm].backup_id

        # Second incremental backup, just increase LAST_INCREMENT_ID
        cli_action("onevm backup #{@info[:vm_id]} -d #{@info[:backup_ds_id]}")

        @info[:vm].running?
        expect(@info[:vm].backup_id).to eq last_backup
        expect(@info[:vm].xml['BACKUPS/BACKUP_CONFIG/LAST_INCREMENT_ID']).to eq "1"
    end

    it 'reset creates full backup and continue with increments' do
        expect(@info[:vm].xml['BACKUPS/BACKUP_CONFIG/MODE']).to eq "INCREMENT"

        last_backup = @info[:vm].backup_id

        # First incremental backup, creates a new backup id
        cli_action("onevm backup --reset #{@info[:vm_id]} -d #{@info[:backup_ds_id]}")

        @info[:vm].running?
        expect(@info[:vm].backup_id).not_to eq last_backup
        expect(@info[:vm].xml['BACKUPS/BACKUP_CONFIG/LAST_INCREMENT_ID']).to eq "0"

        last_backup = @info[:vm].backup_id

        # Second incremental backup, just increase LAST_INCREMENT_ID
        cli_action("onevm backup #{@info[:vm_id]} -d #{@info[:backup_ds_id]}")

        @info[:vm].running?
        expect(@info[:vm].backup_id).to eq last_backup
        expect(@info[:vm].xml['BACKUPS/BACKUP_CONFIG/LAST_INCREMENT_ID']).to eq "1"
    end

    it 'should not allow snapshots with incremental backups' do
        cli_action("onevm disk-snapshot-create #{@info[:vm_id]} 0 fail_snap", false)
        cli_action("onevm snapshot-create #{@info[:vm_id]} fail_snap", false)
    end

    it 'reset increment chain if the active backup is deleted' do
        last = @info[:vm].backup_id

        img = CLIImage.new(last)
        img.ready?

        cli_action("oneimage delete #{last}")

        img.deleted?

        @info[:vm].info
        expect(@info[:vm].xml['BACKUPS/BACKUP_CONFIG/LAST_INCREMENT_ID']).to eq '-1'
        expect(@info[:vm].xml['BACKUPS/BACKUP_CONFIG/INCREMENTAL_BACKUP_ID']).to eq '-1'
    end

    it 'should not allow to change to incremental with snapshots' do
        vm_id = cli_create("onevm create --cpu 1 --memory 64 --disk #{@info[:img_id]}")
        vm    = VM.new(vm_id)

        cli_action("onevm deploy #{vm_id} host0")

        vm.running?

        cli_action("onevm disk-snapshot-create #{vm_id} 0 dsnap")

        vm.running?

        cli_update("onevm updateconf #{vm_id}",
                   'BACKUP_CONFIG=[MODE="INCREMENT"]',
                   true,
                   false)

        xml = vm.xml
        expect(xml['BACKUPS/BACKUP_CONFIG/MODE']).to be_nil

        vm.terminate_hard

        vm_id = cli_create("onevm create --cpu 1 --memory 64 --disk #{@info[:img_id]}")
        vm    = VM.new(vm_id)

        cli_action("onevm deploy #{vm_id} host0")

        vm.running?

        cli_action("onevm snapshot-create #{vm_id} ssnap")

        vm.running?

        cli_update("onevm updateconf #{vm_id}",
                   'BACKUP_CONFIG=[MODE="INCREMENT"]',
                   true,
                   false)

        xml = vm.xml
        expect(xml['BACKUPS/BACKUP_CONFIG/MODE']).to be_nil

        vm.terminate_hard
    end

    it 'delete backup image fails, check state' do
        # Modify driver action to fail delete
        FileUtils.mv(@rm_dummy, "#{@rm_dummy}.orig")

        sleep 1

        File.open(@rm_dummy, File::CREAT|File::TRUNC|File::RDWR, 0744) {|f|
            f.write("#!/bin/bash\n")
            f.write("exit 1\n")
        }

        img = CLIImage.new(@info[:vm].backup_id)
        img.ready?

        cli_action("oneimage delete #{@info[:vm].backup_id}")

        img.error?
    end

    ###################
    # Inplace restore #
    ###################

    it 'should do inplace restore from backup image (full)' do
        # Crate VM full backups
        cli_update("onevm updateconf #{@info[:vm_id]}",
                   'BACKUP_CONFIG=[MODE="FULL"]',
                   true)

        cli_action("onevm backup #{@info[:vm_id]} -d #{@info[:backup_ds_id]}")

        @info[:vm].running?

        # Create VM and disk snapshots
        cli_action("onevm snapshot-create #{@info[:vm_id]} test_snapshot")

        @info[:vm].running?

        cli_action("onevm disk-snapshot-create #{@info[:vm_id]} 0 test_disk_snapshot")

        @info[:vm].running?

        @info[:vm].poweroff

        cli_action("onevm restore #{@info[:vm_id]} #{@info[:vm].backup_id}")

        @info[:vm].poweroff?

        xml = @info[:vm].xml
        expect(xml['USER_TEMPLATE/ERROR']).to be_nil
        expect(xml['SNAPSHOTS']).to be_nil
    end

    it 'should do inplace restore from backup image (incremental)' do
        # Crate VM incremental backups
        cli_update("onevm updateconf #{@info[:vm_id]}",
                   'BACKUP_CONFIG=[MODE="INCREMENT"]',
                   true)

        @info[:vm].resume

        cli_action("onevm backup #{@info[:vm_id]} -d #{@info[:backup_ds_id]}")

        @info[:vm].running?
        cli_action("onevm backup #{@info[:vm_id]} -d #{@info[:backup_ds_id]}")

        @info[:vm].running?
        cli_action("onevm backup #{@info[:vm_id]} -d #{@info[:backup_ds_id]}")

        @info[:vm].running?

        @info[:vm].poweroff

        cli_action("onevm restore #{@info[:vm_id]} #{@info[:vm].backup_id}")

        @info[:vm].poweroff?

        xml = @info[:vm].xml
        expect(xml['USER_TEMPLATE/ERROR']).to be_nil

        cli_action("onevm restore #{@info[:vm_id]} #{@info[:vm].backup_id} --disk-id 0 --increment 1")

        @info[:vm].poweroff?

        xml = @info[:vm].xml
        expect(xml['USER_TEMPLATE/ERROR']).to be_nil
    end

    it 'should fail backup restore with wrong parameters' do
        # VM doesn't exists
        cli_action("onevm restore 999 #{@info[:vm].backup_id}", false)

        # Image doesn't exists
        cli_action("onevm restore #{@info[:vm_id]} 999", false)

        # Image is not a backup
        cli_action("onevm restore #{@info[:vm_id]} 0", false)

        # Wrong disk ID
        cli_action("onevm restore #{@info[:vm_id]} #{@info[:vm].backup_id} --disk-id 999", false)

        # Wrong incremental ID
        cli_action("onevm restore #{@info[:vm_id]} #{@info[:vm].backup_id} --increment 999", false)
    end

    it 'should run fsck without errors' do
        # The fsck checks consistency of quotas
        run_fsck
    end

    ###########
    # Cleanup #
    ###########

    it 'delete backup image' do
        # Restore the driver rm script
        FileUtils.cp("#{@rm_dummy}.orig", @rm_dummy)

        @info[:vm].terminate_hard

        @info[:vm].backup_ids.each do |backup|
            cli_action("oneimage delete #{backup}")
        end
    end

    it 'deletes backup datastore' do
        cli_action("onedatastore delete #{@info[:backup_ds_id]}")
    end
end
