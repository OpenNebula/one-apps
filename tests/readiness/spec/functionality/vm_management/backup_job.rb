require 'securerandom'
require 'init_functionality'
require 'time'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

describe 'Backup Job' do
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

        cli_create("onevm create --cpu 1 --memory 128")
        cli_create("onevm create --cpu 1 --memory 128")
        cli_create("onevm create --cpu 1 --memory 128")

        @bj_template = <<-EOF
            NAME = bj_test
            PRIORITY   = 7
            BACKUP_VMS = "4,2,0"
            DATASTORE_ID = "#{@backup_ds_id}"
            FS_FREEZE  = "AGENT"
            KEEP_LAST  = "5"
            MODE       = "INCREMENT"
            BACKUP_VOLATILE = YES
            DESCRIPTION = "Test remove attribute"
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

    it 'should create a backjob with schedule actions and defaults' do
        template = <<-EOF
            NAME = bj_test2
            BACKUP_VMS = "1,3,5"
            DATASTORE_ID = "#{@backup_ds_id}"
            FS_FREEZE  = "AGENT"
            KEEP_LAST  = "5"

            SCHED_ACTION = [
              REPEAT="3",
              DAYS="1",
              TIME="1995478500"
            ]

            SCHED_ACTION = [
              REPEAT="0",
              DAYS="3,5",
              TIME="1986838600"
            ]
        EOF

        as_user('userA') do
            id = cli_create('onebackupjob create', template)

            xml = cli_action_xml("onebackupjob show -x #{id}")

            expect(xml['NAME']).to eq('bj_test2')
            expect(xml['PRIORITY']).to eq('50')

            expect(xml['TEMPLATE/BACKUP_VMS']).to eq('1,3,5')
            expect(xml['TEMPLATE/FS_FREEZE']).to eq('AGENT')
            expect(xml['TEMPLATE/KEEP_LAST']).to eq('5')
            expect(xml['TEMPLATE/MODE']).to eq('FULL')
            expect(xml['TEMPLATE/BACKUP_VOLATILE']).to eq('NO')
            expect(xml['TEMPLATE/EXECUTION']).to eq('SEQUENTIAL')

            expect(xml['TEMPLATE/SCHED_ACTION[ID = 0]/PARENT_ID']).to eq(id.to_s)
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 0]/REPEAT']).to eq('3')
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 0]/DAYS']).to eq('1')
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 0]/TIME']).to eq('1995478500')
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 0]/ACTION']).to eq('backup')

            expect(xml['TEMPLATE/SCHED_ACTION[ID = 1]/PARENT_ID']).to eq(id.to_s)
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 1]/REPEAT']).to eq('0')
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 1]/DAYS']).to eq('3,5')
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 1]/TIME']).to eq('1986838600')
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 1]/ACTION']).to eq('backup')

            cli_action("onebackupjob delete #{id}")
        end
    end

    it 'should add/del/update schedule actions to the backupjob' do
        as_user('userA') do
            t1 = Time.parse('33/09/23 14:15').to_i
            t2 = Time.parse('33/06/15/33 14:15').to_i

            cli_action("onebackupjob backup #{@bj_id} --schedule '33/09/23 14:15' --hourly 1")

            xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

            expect(xml['TEMPLATE/SCHED_ACTION[ID = 2]/PARENT_ID']).to eq(@bj_id.to_s)
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 2]/REPEAT']).to eq('3')
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 2]/DAYS']).to eq('1')
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 2]/TIME'].to_i).to eq(t1)
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 2]/ACTION']).to eq('backup')

            cli_action("onebackupjob backup #{@bj_id} --schedule '33/06/15 14:15' --weekly 3,5")

            xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

            expect(xml['TEMPLATE/SCHED_ACTION[ID = 2]/PARENT_ID']).to eq(@bj_id.to_s)
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 2]/REPEAT']).to eq('3')
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 2]/DAYS']).to eq('1')
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 2]/TIME'].to_i).to eq(t1)
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 2]/ACTION']).to eq('backup')

            expect(xml['TEMPLATE/SCHED_ACTION[ID = 3]/PARENT_ID']).to eq(@bj_id.to_s)
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 3]/REPEAT']).to eq('0')
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 3]/DAYS']).to eq('3,5')
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 3]/TIME'].to_i).to eq(t2)
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 3]/ACTION']).to eq('backup')

            cli_action("onebackupjob sched-delete #{@bj_id} 2")

            xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

            expect(xml['TEMPLATE/SCHED_ACTION[ID = 2]/PARENT_ID']).to be_nil

            expect(xml['TEMPLATE/SCHED_ACTION[ID = 3]/PARENT_ID']).to eq(@bj_id.to_s)
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 3]/REPEAT']).to eq('0')
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 3]/DAYS']).to eq('3,5')
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 3]/TIME'].to_i).to eq(t2)
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 3]/ACTION']).to eq('backup')

            template_update = <<~EOS
                DAYS="2,4"
                REPEAT="0"
                TIME="1986838500"
            EOS

            cli_update("onebackupjob sched-update #{@bj_id} 3", template_update, false)
            xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

            expect(xml['TEMPLATE/SCHED_ACTION[ID = 3]/PARENT_ID']).to eq(@bj_id.to_s)
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 3]/REPEAT']).to eq('0')
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 3]/DAYS']).to eq('2,4')
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 3]/TIME']).to eq('1986838500')
            expect(xml['TEMPLATE/SCHED_ACTION[ID = 3]/ACTION']).to eq('backup')
        end
    end

    it 'should be visible for users with permissions' do
        as_user('userA') do
            # List
            list = cli_action('onebackupjob list')

            expect(list.stdout).to match(/bj_test/)

            # Show
            xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

            expect(xml['NAME']).to eq('bj_test')
            expect(xml['PRIORITY']).to eq('7')
            expect(xml['TEMPLATE/BACKUP_VMS']).to eq('4,2,0')
        end
    end

    it 'should update priority and check priority value' do
        as_user('userA') do
            # Show
            xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

            expect(xml['NAME']).to eq('bj_test')
            expect(xml['PRIORITY']).to eq('7')

            cli_action("onebackupjob priority #{@bj_id} 49")

            cli_action("onebackupjob priority #{@bj_id} 73", false)

            cli_action("onebackupjob priority #{@bj_id} 1223", false)

            xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

            expect(xml['PRIORITY']).to eq('49')
        end

        cli_action("onebackupjob priority #{@bj_id} '1223'", false)

        cli_action("onebackupjob priority #{@bj_id} 99")

        as_user('userB') do
            cli_action("onebackupjob priority #{@bj_id} 13", false)
        end

        xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

        expect(xml['PRIORITY']).to eq('99')

        cli_action("onebackupjob priority #{@bj_id} 0")

        xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

        expect(xml['PRIORITY']).to eq('0')
    end

    it 'should update template' do
        template1 = <<-EOF
            NAME = "Should not rename by template update"
            KEEP_LAST = 8
            FS_FREEZE  = "SUSPEND"
            PRIORITY   = "25"
            EXECUTION  = "PARALLEL"
        EOF

        template2 = <<-EOF
            NAME = "Should not rename by template update"
            KEEP_LAST = 10
            FS_FREEZE  = "AGENT"
        EOF

        template3 = <<-EOF
            SCHED_ACTION = [
                TIME = "1695478500"
            ]
        EOF

        as_user('userA') do
            xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

            expect(xml['NAME']).to eq('bj_test')
            expect(xml['TEMPLATE/KEEP_LAST']).to eq('5')
            expect(xml['TEMPLATE/FS_FREEZE']).to eq('AGENT')

            # Append
            cli_update("onebackupjob update #{@bj_id}", template1, true)

            xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

            expect(xml['NAME']).to eq('bj_test')
            expect(xml['TEMPLATE/NAME']).to be_nil
            expect(xml['TEMPLATE/KEEP_LAST']).to eq('8')
            expect(xml['TEMPLATE/FS_FREEZE']).to eq('SUSPEND')
            expect(xml['TEMPLATE/BACKUP_VMS']).to eq('4,2,0')
            expect(xml['TEMPLATE/BACKUP_VOLATILE']).to eq('YES')
            expect(xml['TEMPLATE/MODE']).to eq('INCREMENT')
            expect(xml['TEMPLATE/EXECUTION']).to eq('PARALLEL')
            expect(xml['TEMPLATE/PRIORITY']).to be_nil
            expect(xml['PRIORITY']).to eq('7') # Not changed, use `onebackupjob priority`
            expect(xml.retrieve_xmlelements('TEMPLATE/SCHED_ACTION').size).to eq(0)

            # Replace - it resets unspecified attributes to default value
            cli_update("onebackupjob update #{@bj_id}", template2, false)

            xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

            expect(xml['NAME']).to eq('bj_test')
            expect(xml['TEMPLATE/NAME']).to be_nil
            expect(xml['TEMPLATE/KEEP_LAST']).to eq('10')
            expect(xml['TEMPLATE/FS_FREEZE']).to eq('AGENT')
            expect(xml['TEMPLATE/BACKUP_VMS']).to eq('')
            expect(xml['TEMPLATE/BACKUP_VOLATILE']).to eq('NO')
            expect(xml['TEMPLATE/MODE']).to eq('FULL')
            expect(xml['TEMPLATE/EXECUTION']).to eq('SEQUENTIAL')
            expect(xml['TEMPLATE/PRIORITY']).to be_nil
            expect(xml['PRIORITY']).to eq('7') # Not changed, use `onebackupjob priority`
            expect(xml.retrieve_xmlelements('TEMPLATE/SCHED_ACTION').size).to eq(0)

            # Update should not add Scheduled Action
            cli_update("onebackupjob update #{@bj_id}", template3, true)

            xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

            expect(xml['NAME']).to eq('bj_test')
            expect(xml['TEMPLATE/NAME']).to be_nil
            expect(xml['TEMPLATE/KEEP_LAST']).to eq('10')
            expect(xml['TEMPLATE/FS_FREEZE']).to eq('AGENT')
            expect(xml['TEMPLATE/BACKUP_VMS']).to eq('')
            expect(xml['TEMPLATE/BACKUP_VOLATILE']).to eq('NO')
            expect(xml['TEMPLATE/MODE']).to eq('FULL')
            expect(xml['TEMPLATE/EXECUTION']).to eq('SEQUENTIAL')
            expect(xml.retrieve_xmlelements('TEMPLATE/SCHED_ACTION').size).to eq(0)
        end
    end

    it 'should rename' do
        as_user('userA') do
            cli_action("onebackupjob rename #{@bj_id} new_name")

            xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

            expect(xml['NAME']).to eq('new_name')
        end
    end

    it 'should change owner' do
        # Check initial valuse
        xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

        expect(xml['UID'].to_i).to eq(@ua_id)
        expect(xml['UNAME']).to eq('userA')
        expect(xml['GID'].to_i).to eq(@ga_id)
        expect(xml['GNAME']).to eq('gA')

        # Change owner
        cli_action("onebackupjob chown #{@bj_id} userB gB")

        # Test new values
        xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

        expect(xml['UID'].to_i).to eq(@ub_id)
        expect(xml['UNAME']).to eq('userB')
        expect(xml['GID'].to_i).to eq(@gb_id)
        expect(xml['GNAME']).to eq('gB')
    end

    it 'should change group' do
        # Check initial values
        xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

        expect(xml['GID'].to_i).to eq(@ga_id)
        expect(xml['GNAME']).to eq('gA')

        # Change group
        cli_action("onebackupjob chgrp #{@bj_id} gB")

        # Test new values
        xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

        expect(xml['GID'].to_i).to eq(@gb_id)
        expect(xml['GNAME']).to eq('gB')
    end

    it 'should change permissions' do
        as_user('userA') do
            # Check initial values
            xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

            expect(xml['PERMISSIONS/OWNER_U'].to_i).to eq(1)
            expect(xml['PERMISSIONS/OWNER_M'].to_i).to eq(1)
            expect(xml['PERMISSIONS/OWNER_A'].to_i).to eq(0)
            expect(xml['PERMISSIONS/GROUP_U'].to_i).to eq(0)
            expect(xml['PERMISSIONS/GROUP_M'].to_i).to eq(0)
            expect(xml['PERMISSIONS/GROUP_A'].to_i).to eq(0)
            expect(xml['PERMISSIONS/OTHER_U'].to_i).to eq(0)
            expect(xml['PERMISSIONS/OTHER_M'].to_i).to eq(0)
            expect(xml['PERMISSIONS/OTHER_A'].to_i).to eq(0)

            # Change permissions
            cli_action("onebackupjob chmod #{@bj_id} 666")

            # Test new values
            xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

            expect(xml['PERMISSIONS/OWNER_U'].to_i).to eq(1)
            expect(xml['PERMISSIONS/OWNER_M'].to_i).to eq(1)
            expect(xml['PERMISSIONS/OWNER_A'].to_i).to eq(0)
            expect(xml['PERMISSIONS/GROUP_U'].to_i).to eq(1)
            expect(xml['PERMISSIONS/GROUP_M'].to_i).to eq(1)
            expect(xml['PERMISSIONS/GROUP_A'].to_i).to eq(0)
            expect(xml['PERMISSIONS/OTHER_U'].to_i).to eq(1)
            expect(xml['PERMISSIONS/OTHER_M'].to_i).to eq(1)
            expect(xml['PERMISSIONS/OTHER_A'].to_i).to eq(0)
        end
    end

    it 'should lock/unlock' do
        as_user('userA') do
            # Check initial lock state
            xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

            expect(xml['LOCK']).to be_nil

            # Lock
            cli_action("onebackupjob lock #{@bj_id}")

            xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

            expect(xml['LOCK/LOCKED'].to_i).to eq(1)

            # Unlock
            cli_action("onebackupjob unlock #{@bj_id}")

            xml = cli_action_xml("onebackupjob show -x #{@bj_id}")

            expect(xml['LOCK']).to be_nil
        end
    end

    it 'should not execute any command without permissions' do
        template = <<-EOF
            KEEP_LAST = 9
        EOF

        as_user('userB') do
            list = cli_action('onebackupjob list')

            expect(list.stdout).not_to match(/bj_test/)

            cli_action("onebackupjob show -x #{@bj_id}", false)
            cli_action("onebackupjob delete #{@bj_id}", false)
            cli_update("onebackupjob update #{@bj_id}", template, false, false)
            cli_action("onebackupjob rename #{@bj_id} new_name", false)
            cli_action("onebackupjob chown #{@bj_id} userB", false)
            cli_action("onebackupjob chgrp #{@bj_id} gB", false)
            cli_action("onebackupjob chmod #{@bj_id} 666", false)
            cli_action("onebackupjob lock #{@bj_id}", false)
            cli_action("onebackupjob unlock #{@bj_id}", false)
            cli_action("onebackupjob priority #{@bj_id} 22", false)
            cli_action("onebackupjob backup #{@bj_id}", false)
        end
    end

    it 'should remove non-existing VMs from Backup Job' do
        cli_action("onebackupjob backup #{@bj_id}")

        # Wait BJ fail to run backup
        wait_loop(:success => '2,0', :timeout => 60) do
            xml = cli_action_xml("onebackupjob show #{@bj_id} -x")
            xml['TEMPLATE/BACKUP_VMS']
        end

        # test BJ lists
        xml = cli_action_xml("onebackupjob show #{@bj_id} -x")
        expect(xml['TEMPLATE/ERROR']).to be_nil
        expect(xml['UPDATED_VMS/ID']).to be_nil
        expect(xml['OUTDATED_VMS/ID']).to eq ("02")
        expect(xml['BACKING_UP_VMS/ID']).to be_nil
        expect(xml.retrieve_elements('ERROR_VMS/ID')).to be_nil
    end

    def test_backup_job_id(vmid, bjid)
        xml = cli_action_xml("onevm show #{vmid} -x")
        expect(xml['BACKUPS/BACKUP_CONFIG/BACKUP_JOB_ID'].to_i).to eq(bjid)
    end

    def test_backup_job_id_nil(vmid)
        xml = cli_action_xml("onevm show #{vmid} -x")
        expect(xml['BACKUPS/BACKUP_CONFIG/BACKUP_JOB_ID']).to be_nil
    end

    it 'should assign Backup Job ID to VMs' do
        # Test Backup Job ID in VMs after creating Backup Job
        test_backup_job_id(0, @bj_id)
        test_backup_job_id_nil(1)
        test_backup_job_id(2, @bj_id)

        # Test Backup Job ID in VMs after update append
        cli_update("onebackupjob update #{@bj_id}", 'BACKUP_VMS="0"', true)

        test_backup_job_id(0, @bj_id)
        test_backup_job_id_nil(1)
        test_backup_job_id_nil(2)

        # Test Backup Job ID in VMs after update replace
        cli_update("onebackupjob update #{@bj_id}", 'BACKUP_VMS="0,1"', true)

        test_backup_job_id(0, @bj_id)
        test_backup_job_id(1, @bj_id)
        test_backup_job_id_nil(2)

        # Fail to create Backup Job with the same VM
        template1 = <<-EOF
            NAME = bj_test2
            BACKUP_VMS = "3,2,1"
        EOF

        cli_create('onebackupjob create', template1, false)

        # Create Backup Job with distinct VMs
        template2 = <<-EOF
            NAME = bj_test3
            BACKUP_VMS = "3,2"
        EOF

        bj_id2 = cli_create('onebackupjob create', template2)

        test_backup_job_id(0, @bj_id)
        test_backup_job_id(1, @bj_id)
        test_backup_job_id(2, bj_id2)

        # Fail to update Backup Job with VMs already in other Backup Job
        cli_update("onebackupjob update #{bj_id2}", 'BACKUP_VMS="3,2,1"', true, false)

        # Delete Backup Job should delete Backup Job ID from VMs
        cli_action("onebackupjob delete #{bj_id2}")

        test_backup_job_id(0, @bj_id)
        test_backup_job_id(1, @bj_id)
        test_backup_job_id_nil(2)

        # Update with empty BACKUP_VMS should clear Backup Job ID from VMs
        cli_update("onebackupjob update #{@bj_id}", 'BACKUP_VMS=""', true)

        test_backup_job_id_nil(0)
        test_backup_job_id_nil(1)
        test_backup_job_id_nil(2)
    end

    it 'should fail to run Single backup for VM in Backup Job' do
        cli_action('onevm deploy 0 0')
        cli_action("onevm backup 0 --datastore #{@backup_ds_id}", false)

        cli_action("onevm backup 0 --datastore #{@backup_ds_id} --schedule now")

        wait_loop(:success => false, :timeout => 60) do
            xml = cli_action_xml("onevm show 0 -x")
            xml['USER_TEMPLATE/ERROR'].nil?
        end
    end

    it 'user should fail to create Backup Job with elevated priority' do
        template = <<-EOF
            NAME = bj_test2
            PRIORITY = 66
        EOF

        as_user('userA') do
            cli_create('onebackupjob create', template, false)
        end

        cli_create('onebackupjob create', template)
    end
end
