
require 'init_functionality'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

describe 'Schedule Action Manager Backup Job' do
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do
        @info = {}

        @ua_id = cli_create_user('userA', 'abc')
        @ub_id = cli_create_user('userB', 'abc')

        @ga_id = cli_create('onegroup create gA')
        cli_action('oneuser chgrp userA gA')

        @gb_id = cli_create('onegroup create gB')
        cli_action('oneuser chgrp userB gB')

        @ds_template = <<~EOT
            NAME="dummy backups #{SecureRandom.uuid}"
            DS_MAD=dummy
            TM_MAD=-
            TYPE=BACKUP_DS
        EOT

        @backup_ds_id = cli_create("onedatastore create", @ds_template)

        cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)
        cli_update("onedatastore update system", "TM_MAD=dummy", false)

        cli_create("onehost create host0 --im dummy --vm dummy")

        @bj_template = <<-EOF
            NAME = bj_test
            BACKUP_VMS = "0"
            DATASTORE_ID = "#{@backup_ds_id}"
            FS_FREEZE  = "AGENT"
            KEEP_LAST  = "5"
            MODE       = "INCREMENTAL"
            BACKUP_VOLATILE = YES
        EOF
    end

    before(:each) do
        @bj_id = nil
        as_user('userA') do
            @bj_id = cli_create('onebackupjob create', @bj_template)
        end
    end

    after(:each) do
        cli_action("onebackupjob delete #{@bj_id}")
    end

    def deploy_vm(name)
        vm_template = <<-EOF
            NAME   = #{name}
            CPU    = 1
            MEMORY = 1024
            DISK   = [
                IMAGE_ID=#{@info[:img_id]}
            ]
            BACKUP_CONFIG=[
                MODE = "FULL",
                KEEP_LAST = 2
            ]
        EOF

        id = cli_create("onevm create", vm_template)

        cli_action("onevm deploy #{id} host0")

        VM.new(id)
    end

    it 'deploy VMs' do
        img_id = cli_create("oneimage create -d 1", <<-EOT)
            NAME = "test_img"
            PATH = "/tmp/none"
        EOT

        @info[:img_id] = img_id

        wait_image_ready(10, img_id)

        @info[:vm1] = deploy_vm('testvm1');
        @info[:vm2] = deploy_vm('testvm2');

        @info[:vm1].running?
        @info[:vm2].running?
    end

    it 'should do backups from Backup Jobs by priority' do
        bj_template2 = <<-EOF
            NAME = bj_test2
            BACKUP_VMS = "#{@info[:vm2].id}"
            DATASTORE_ID = "#{@backup_ds_id}"
        EOF

        @info[:bj_id2] = cli_create('onebackupjob create', bj_template2)

        cli_action("onebackupjob priority #{@bj_id} 2")
        cli_action("onebackupjob priority #{@info[:bj_id2]} 5")

        # Execute both BackupJobs, the second should do the backup first
        # due to higher priority
        cli_action("onebackupjob backup #{@bj_id},#{@info[:bj_id2]}")

        # test first Backup Job VMs lists
        xml = cli_action_xml("onebackupjob show #{@bj_id} -x")
        expect(xml['UPDATED_VMS/ID']).to be_nil
        expect(xml['OUTDATED_VMS/ID'].to_i).to eq(@info[:vm1].id)
        expect(xml['BACKING_UP_VMS/ID']).to be_nil

        # Wait second VM backup done
        wait_loop(:timeout => 60, :success => 1) do
            @info[:vm2].backup_ids.size
        end

        # Test first VM not backup
        expect(@info[:vm1].backup_ids).to match_array([])

        # Wait first VM backup
        wait_loop(:timeout => 60, :success => 1) do
            @info[:vm1].backup_ids.size
        end

        # test BJ waiting/pending lists are empty
        xml = cli_action_xml("onebackupjob show #{@bj_id} -x")
        expect(xml['UPDATED_VMS/ID'].to_i).to eq(@info[:vm1].id)
        expect(xml['OUTDATED_VMS/ID']).to be_nil
        expect(xml['BACKING_UP_VMS/ID']).to be_nil

        xml = cli_action_xml("onebackupjob show #{@info[:bj_id2]} -x")
        expect(xml['UPDATED_VMS/ID'].to_i).to eq(@info[:vm2].id)
        expect(xml['OUTDATED_VMS/ID']).to be_nil
        expect(xml['BACKING_UP_VMS/ID']).to be_nil
    end

    it 'should copy backup config values from BJ to VM' do
        cli_action("onebackupjob backup #{@bj_id}")

        # Wait first VM backup
        wait_loop(:timeout => 60, :success => @info[:vm1].id.to_s) do
            xml = cli_action_xml("onebackupjob show #{@bj_id} -x")
            xml['UPDATED_VMS/ID']
        end

        xml = @info[:vm1].xml

        expect(xml['BACKUPS/BACKUP_CONFIG/BACKUP_VOLATILE']).to eq('YES')
        expect(xml['BACKUPS/BACKUP_CONFIG/FS_FREEZE']).to eq('AGENT')
        expect(xml['BACKUPS/BACKUP_CONFIG/KEEP_LAST']).to eq('5')
        expect(xml['BACKUPS/BACKUP_CONFIG/MODE']).to eq('FULL') # Incremental not supported by driver
    end

    it 'should check quotas after Backup Job do backups' do
        # Change owner of VM to userA to apply quotas
        cli_action("onevm chown #{@info[:vm1].id} userA gA")

        # Set datastore image quotas for userA to 1
        quota_template = <<-EOF
            DATASTORE = [
                ID = #{@backup_ds_id},
                IMAGES = 1
            ]
        EOF

        cli_update('oneuser quota userA', quota_template, false)

        # Launch onebackupjob backup, wait for backup, check quotas
        last_backup_id = @info[:vm1].backup_id

        cli_action("onebackupjob backup #{@bj_id}")

        # Wait VM backup done
        wait_loop(:timeout => 60) do
            @info[:vm1].backup_id != last_backup_id
        end

        xml = cli_action_xml('oneuser show userA -x')

        expect(xml['DATASTORE_QUOTA/DATASTORE/IMAGES_USED'].to_i).to eq(1)
        expect(xml['DATASTORE_QUOTA/DATASTORE/SIZE_USED'].to_i).to eq(1024)

        # test BJ waiting/pending lists are empty
        xml = cli_action_xml("onebackupjob show #{@bj_id} -x")
        expect(xml['UPDATED_VMS/ID'].to_i).to eq(@info[:vm1].id)
        expect(xml['OUTDATED_VMS/ID']).to be_nil
        expect(xml['BACKING_UP_VMS/ID']).to be_nil
    end

    # Execute second time BackupJob, backup fails on quotas exceeded
    # VM stays in waiting state, error log in the BackupJob
    it 'should fail to do backups in case of exceed quota' do
        # Launch onebackupjob backup, wait for backup, check quotas
        cli_action("onebackupjob backup #{@bj_id}")

        # Wait BJ fail to run backup
        wait_loop(:timeout => 60) do
            xml = cli_action_xml("onebackupjob show #{@bj_id} -x")
            error = xml['TEMPLATE/ERROR'] || ''
            error != ''
        end

        xml = cli_action_xml('oneuser show userA -x')

        expect(xml['DATASTORE_QUOTA/DATASTORE/IMAGES_USED'].to_i).to eq(1)
        expect(xml['DATASTORE_QUOTA/DATASTORE/SIZE_USED'].to_i).to eq(1024)

        # check BJ waiting/pending lists
        xml = cli_action_xml("onebackupjob show #{@bj_id} -x")
        expect(xml['UPDATED_VMS/ID']).to be_nil
        expect(xml['OUTDATED_VMS/ID']).to be_nil
        expect(xml['BACKING_UP_VMS/ID']).to be_nil
        expect(xml['ERROR_VMS/ID'].to_i).to eq(@info[:vm1].id)
    end

    it 'should schedule backup job' do
        # Change owner back to oneadmin to avoid quotas
        cli_action("onevm chown #{@info[:vm1].id} oneadmin oneadmin")

        # Store VM last backup ID
        backup_id = @info[:vm1].backup_id

        # Schedule Backup Job
        time_start = Time.now.to_i
        cli_action("onebackupjob backup #{@bj_id} --schedule now --monthly 1,15 --end 1")
        time_end = Time.now.to_i

        # Check Backup Job contain Scheduled Action
        bj_xml = cli_action_xml("onebackupjob show #{@bj_id} -x")

        expect(bj_xml['TEMPLATE/SCHED_ACTION/ID']).to eq("0")
        expect(bj_xml['TEMPLATE/SCHED_ACTION/PARENT_ID'].to_i).to eq(@bj_id)
        expect(bj_xml['TEMPLATE/SCHED_ACTION/TYPE']).to eq('BACKUPJOB')
        expect(bj_xml['TEMPLATE/SCHED_ACTION/ACTION']).to eq("backup")
        expect(bj_xml['TEMPLATE/SCHED_ACTION/TIME'].to_i).to be_between(time_start, time_end)
        expect(bj_xml['TEMPLATE/SCHED_ACTION/DONE']).to eq("-1")
        expect(bj_xml['TEMPLATE/SCHED_ACTION/REPEAT']).to eq("1")
        expect(bj_xml['TEMPLATE/SCHED_ACTION/DAYS']).to eq("1,15")
        expect(bj_xml['TEMPLATE/SCHED_ACTION/END_TYPE']).to eq("1")
        expect(bj_xml['TEMPLATE/SCHED_ACTION/END_VALUE']).to eq("1")

        # Store the SA ID for later use
        sa_id = bj_xml['TEMPLATE/SCHED_ACTION/ID'];

        # Wait Scheduled Action started
        wait_loop(:timeout => 40) do
            bj_xml = cli_action_xml("onebackupjob show #{@bj_id} -x")
            bj_xml['TEMPLATE/SCHED_ACTION/DONE'] != "-1"
        end

        bj_xml = cli_action_xml("onebackupjob show #{@bj_id} -x")

        expect(bj_xml['TEMPLATE/SCHED_ACTION/ID']).to eq("0")
        expect(bj_xml['TEMPLATE/SCHED_ACTION/PARENT_ID'].to_i).to eq(@bj_id)
        expect(bj_xml['TEMPLATE/SCHED_ACTION/TYPE']).to eq('BACKUPJOB')
        expect(bj_xml['TEMPLATE/SCHED_ACTION/ACTION']).to eq("backup")
        expect(bj_xml['TEMPLATE/SCHED_ACTION/TIME'].to_i).to be > time_end # new value
        expect(bj_xml['TEMPLATE/SCHED_ACTION/DONE'].to_i).to be > 0        # new value
        expect(bj_xml['TEMPLATE/SCHED_ACTION/REPEAT']).to eq("1")
        expect(bj_xml['TEMPLATE/SCHED_ACTION/DAYS']).to eq("1,15")
        expect(bj_xml['TEMPLATE/SCHED_ACTION/END_TYPE']).to eq("1")
        expect(bj_xml['TEMPLATE/SCHED_ACTION/END_VALUE']).to eq("0")       # new value

        # Wait VM last backup ID change
        wait_loop(:timeout => 20) do
            @info[:vm1].backup_id != backup_id
        end

        # Update Backup Job Schedule Action
        cli_update("onebackupjob sched-update #{@bj_id} #{sa_id}", "REPEAT=2\nDAYS=\"2,16\"\n", false)

        bj_xml = cli_action_xml("onebackupjob show #{@bj_id} -x")

        expect(bj_xml['TEMPLATE/SCHED_ACTION/ID']).to eq(sa_id)
        expect(bj_xml['TEMPLATE/SCHED_ACTION/PARENT_ID'].to_i).to eq(@bj_id)
        expect(bj_xml['TEMPLATE/SCHED_ACTION/TYPE']).to eq('BACKUPJOB')
        expect(bj_xml['TEMPLATE/SCHED_ACTION/ACTION']).to eq("backup")
        expect(bj_xml['TEMPLATE/SCHED_ACTION/TIME'].to_i).to be > time_end
        expect(bj_xml['TEMPLATE/SCHED_ACTION/DONE'].to_i).to be > 0
        expect(bj_xml['TEMPLATE/SCHED_ACTION/REPEAT']).to eq("2")
        expect(bj_xml['TEMPLATE/SCHED_ACTION/DAYS']).to eq("2,16")
        expect(bj_xml['TEMPLATE/SCHED_ACTION/END_TYPE']).to eq("1")
        expect(bj_xml['TEMPLATE/SCHED_ACTION/END_VALUE']).to eq("0")

        # Delete scheduled action
        cli_action("onebackupjob sched-delete #{@bj_id} #{sa_id}")

        bj_xml = cli_action_xml("onebackupjob show #{@bj_id} -x")

        expect(bj_xml['TEMPLATE/SCHED_ACTION']).to be_nil
    end

    it 'check parsing of scheduled attributes' do
        sched_time = Time.now + 200
        cli_action("onebackupjob backup #{@bj_id} --schedule \"#{sched_time}\"")

        # Check Backup Job contain Scheduled Action
        bj_xml = cli_action_xml("onebackupjob show #{@bj_id} -x")

        expect(bj_xml['TEMPLATE/SCHED_ACTION/ID'].to_i).to be >= 0
        expect(bj_xml['TEMPLATE/SCHED_ACTION/PARENT_ID'].to_i).to eq(@bj_id)
        expect(bj_xml['TEMPLATE/SCHED_ACTION/TYPE']).to eq('BACKUPJOB')
        expect(bj_xml['TEMPLATE/SCHED_ACTION/ACTION']).to eq("backup")
        expect(bj_xml['TEMPLATE/SCHED_ACTION/TIME'].to_i).to eq(sched_time.to_i)
        expect(bj_xml['TEMPLATE/SCHED_ACTION/DONE']).to eq("-1")
        expect(bj_xml['TEMPLATE/SCHED_ACTION/REPEAT']).to eq("-1")
        expect(bj_xml['TEMPLATE/SCHED_ACTION/DAYS']).to eq("")
        expect(bj_xml['TEMPLATE/SCHED_ACTION/END_TYPE']).to eq("-1")
        expect(bj_xml['TEMPLATE/SCHED_ACTION/END_VALUE']).to eq("-1")

        cli_action("onebackupjob backup #{@bj_id} --schedule not_a_time", false)
        cli_action("onebackupjob backup #{@bj_id} --schedule +500", false)
        cli_action("onebackupjob backup #{@bj_id} --schedule \"#{sched_time}\" --hourly 2,22", false)
        cli_action("onebackupjob backup #{@bj_id} --schedule \"#{sched_time}\" --weekly 2,5,8", false)
        cli_action("onebackupjob backup #{@bj_id} --schedule \"#{sched_time}\" --monthly 33", false)
        cli_action("onebackupjob backup #{@bj_id} --schedule \"#{sched_time}\" --yearly 367", false)
    end

    it 'should clear waiting list on cancel action' do
        cli_action("onebackupjob backup #{@bj_id}")

        cli_action("onebackupjob cancel #{@bj_id}")

        # test BJ lists are empty
        xml = cli_action_xml("onebackupjob show #{@bj_id} -x")

        expect(xml['UPDATED_VMS/ID']).to be_nil
        expect(xml['OUTDATED_VMS/ID']).to be_nil
        expect(xml['BACKING_UP_VMS/ID']).to be_nil
    end

    it 'should retry failed backup job' do
        cli_action('onevm suspend 0')

        cli_action("onebackupjob backup #{@bj_id}")

        # Wait for backup error
        wait_loop(:timeout => 60, :success => '0') do
            xml = cli_action_xml("onebackupjob show #{@bj_id} -x")
            xml['ERROR_VMS/ID']
        end

        # test BJ lists are empty
        xml = cli_action_xml("onebackupjob show #{@bj_id} -x")

        expect(xml['UPDATED_VMS/ID']).to be_nil
        expect(xml['OUTDATED_VMS/ID']).to be_nil
        expect(xml['BACKING_UP_VMS/ID']).to be_nil
        expect(xml['TEMPLATE/ERROR']).not_to be_empty

        cli_action('onevm resume 0')

        cli_action("onebackupjob retry #{@bj_id}")

        # Wait for backup
        wait_loop(:timeout => 60, :success => '0') do
            xml = cli_action_xml("onebackupjob show #{@bj_id} -x")
            xml['UPDATED_VMS/ID']
        end

        # test BJ lists are empty
        xml = cli_action_xml("onebackupjob show #{@bj_id} -x")

        expect(xml['ERROR_VMS/ID']).to be_nil
        expect(xml['OUTDATED_VMS/ID']).to be_nil
        expect(xml['BACKING_UP_VMS/ID']).to be_nil
        expect(xml['TEMPLATE/ERROR']).to be_nil
    end

    it 'should run fsck to check Scheduled Action consistency' do
        run_fsck
    end
end

