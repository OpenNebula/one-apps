
require 'init_functionality'
require 'active_support/time'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

def history(vmxml, elem)
    return vmxml["HISTORY_RECORDS/HISTORY[last()]/#{elem}"]
end

describe "VirtualMachine create schedule actions" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults_with_sched.yaml')
    end

    before(:all) do
        cli_update("onedatastore update system", "TM_MAD=dummy", false)
        cli_update("onedatastore update default", "TM_MAD=dummy", false)
        cli_create("onehost create host01 --im dummy --vm dummy")
    end

    def get_template (name, type, repeat, end_type, end_value, action)
        # Delay the scheduled action a little bit to be able to detect VM running state
        execution_time = Time.now + 5

        today = Date.today

        if type === 0 # { now ----[RANGE] }
            prev_day = today.next_day(1)
            post_day = today.next_day(2)
        elsif type === 1 # { [RANGE] ---- now }
            prev_day = today.prev_day(3)
            post_day = today.prev_day(2)
        else # { [RANGE---now---RANGE] }
            prev_day = today.prev_day(1)
            post_day = today.next_day(1)
        end

        if repeat == 0 # weekly
            # Range [0..6]
            prev_day = prev_day.wday
            post_day = post_day.wday
        elsif repeat == 1 # monthly
            # Range [1..31]
            prev_day = prev_day.mday
            post_day = post_day.mday
        else # yearly
            # yday range [1..366], oned range [0..365]
            prev_day = prev_day.yday - 1
            post_day = post_day.yday - 1
        end

        template = <<-EOF
            NAME = "#{name}"
            CPU = 0.1
            MEMORY = 128
            SCHED_ACTION = [
                ACTION = "#{action}",
                TIME = "#{execution_time.to_i}",
                REPEAT = "#{repeat}",
                DAYS = "#{prev_day},#{post_day}",
                END_TYPE = "#{end_type}",
                END_VALUE = "#{end_value}"
            ]
        EOF

        return template
    end

    def check_scheduled_action(xml, vid, action, repeat, end_type, end_value)
        now = Time.now.to_i

        expect(xml['TEMPLATE/SCHED_ACTION/PARENT_ID'].to_i).to eq(vid)
        expect(xml['TEMPLATE/SCHED_ACTION/TYPE']).to eq('VM')
        expect(xml['TEMPLATE/SCHED_ACTION/ACTION']).to eq(action)
        expect(xml['TEMPLATE/SCHED_ACTION/TIME'].to_i).to be >= now
        expect(xml['TEMPLATE/SCHED_ACTION/TIME'].to_i).to be <= now + 10
        expect(xml['TEMPLATE/SCHED_ACTION/DONE']).to eq(nil).or eq("-1")
        expect(xml['TEMPLATE/SCHED_ACTION/REPEAT'].to_i).to eq(repeat)
        expect(xml['TEMPLATE/SCHED_ACTION/END_TYPE'].to_i).to eq(end_type)
        expect(xml['TEMPLATE/SCHED_ACTION/END_VALUE'].to_i).to eq(end_value)
        expect(xml['TEMPLATE/SCHED_ACTION/WARNING'].to_i).to eq(0)
    end

    it "should create new schedule action to poweroff the machine (weekly & monthly)" do
        now = Time.now
        vm_id = cli_create("onevm create", get_template("test_vm1_week", 0, 0, 1, 3, "poweroff-hard"))
        vm = VM.new(vm_id)

        check_scheduled_action(vm.xml, vm_id, "poweroff-hard", 0, 1, 3)

        cli_action("onevm deploy test_vm1_week host01")

        vm.running?

        vm.state?("POWEROFF", /FAIL/, :timeout => 30)

        vm_xml = cli_action_xml("onevm show test_vm1_week -x")

        new_time = Time.at(vm_xml['TEMPLATE/SCHED_ACTION/TIME'].to_i)

        expect(new_time.wday).to eq((now.wday+1)%7)
        expect(vm_xml['TEMPLATE/SCHED_ACTION/END_VALUE'].to_i).to eq(2)
        expect(vm_xml['TEMPLATE/SCHED_ACTION/DONE']).not_to be_nil

        now = Time.now
        vm_id = cli_create("onevm create", get_template("test_vm1_month", 0, 1, 1, 3, "poweroff-hard"))
        vm = VM.new(vm_id)

        check_scheduled_action(vm.xml, vm_id, "poweroff-hard", 1, 1, 3)

        cli_action("onevm deploy test_vm1_month host01")

        vm.running?

        vm.state?("POWEROFF", /FAIL/, :timeout => 30)

        vm_xml = cli_action_xml("onevm show test_vm1_month -x")

        new_time = Time.at(vm_xml['TEMPLATE/SCHED_ACTION/TIME'].to_i)

        expected_time = now + 60*60*24  # Expected day is tomorrow
        expect(new_time.mday).to eq(expected_time.mday)

        expect(vm_xml['TEMPLATE/SCHED_ACTION/END_VALUE'].to_i).to eq(2)
        expect(vm_xml['TEMPLATE/SCHED_ACTION/DONE']).not_to be_nil
    end

    it "should create new schedule action to poweroff the machine (monthly & yearly)" do
        vm_id = cli_create("onevm create", get_template("test_vm2_month", 1, 1, 1, 3, "poweroff-hard"))
        vm = VM.new(vm_id)

        check_scheduled_action(vm.xml, vm_id, "poweroff-hard", 1, 1, 3)

        cli_action("onevm deploy test_vm2_month host01")

        vm.running?

        vm.state?("POWEROFF", /FAIL/, :timeout => 30)

        vm_xml = cli_action_xml("onevm show test_vm2_month -x")

        new_time = Time.at(vm_xml['TEMPLATE/SCHED_ACTION/TIME'].to_i)

        # This test may fail if it's around midnight and
        # the summer time change is between Time.now and expected_date
        if (new_time.dst? != Time.now.dst?) &&
                ((new_time.dst? && new_time.hour == 0) ||
                (!new_time.dst? && new_time.hour == 23))
            skip "Daytime saving disturbs test"
        end

        expected_date = Date.today.prev_day(3)
        expected_date = expected_date.next_day(expected_date.end_of_month.mday)

        expect(new_time.mday).to eq(expected_date.mday)
        expect(new_time.month).to eq(expected_date.month)
        expect(vm_xml['TEMPLATE/SCHED_ACTION/END_VALUE'].to_i).to eq(2)
        expect(vm_xml['TEMPLATE/SCHED_ACTION/DONE']).not_to be_nil

        now = Time.now
        vm_id = cli_create("onevm create", get_template("test_vm2_year", 1, 2, 1, 3, "poweroff-hard"))
        vm = VM.new(vm_id)

        check_scheduled_action(vm.xml, vm_id, "poweroff-hard", 2, 1, 3)

        cli_action("onevm deploy test_vm2_year host01")

        vm.running?

        vm.state?("POWEROFF", /FAIL/, :timeout => 30)

        vm_xml = cli_action_xml("onevm show test_vm2_year -x")

        new_time = Time.at(vm_xml['TEMPLATE/SCHED_ACTION/TIME'].to_i)

        expected_date = Date.today.prev_day(3)
        expected_date = expected_date.next_day(expected_date.end_of_year.yday)

        expect(new_time.yday).to eq(expected_date.yday)
        expect(new_time.year).to eq(expected_date.year)

        expect(vm_xml['TEMPLATE/SCHED_ACTION/END_VALUE'].to_i).to eq(2)
        expect(vm_xml['TEMPLATE/SCHED_ACTION/DONE']).not_to be_nil
    end

    it "should create new schedule action to poweroff the machine (weekly & yearly)" do
        now = Time.now
        vm_id = cli_create("onevm create", get_template("test_vm3_week", 2, 0, 1, 3, "poweroff-hard"))
        vm = VM.new(vm_id)

        check_scheduled_action(vm.xml, vm_id, "poweroff-hard", 0, 1, 3)

        cli_action("onevm deploy test_vm3_week host01")

        vm.running?

        vm.state?("POWEROFF", /FAIL/, :timeout => 30)

        vm_xml = cli_action_xml("onevm show test_vm3_week -x")

        new_time = Time.at(vm_xml['TEMPLATE/SCHED_ACTION/TIME'].to_i)

        expect(new_time.wday).to eq((now.wday+1)%7)
        expect(vm_xml['TEMPLATE/SCHED_ACTION/END_VALUE'].to_i).to eq(2)
        expect(vm_xml['TEMPLATE/SCHED_ACTION/DONE']).not_to be_nil

        now = Time.now
        vm_id = cli_create("onevm create", get_template("test_vm3_year", 0, 2, 1, 3, "poweroff-hard"))
        vm = VM.new(vm_id)

        check_scheduled_action(vm.xml, vm_id, "poweroff-hard", 2, 1, 3)

        cli_action("onevm deploy test_vm3_year host01")

        vm.state?("POWEROFF", /FAIL/, :timeout => 30)

        vm_xml = cli_action_xml("onevm show test_vm3_year -x")

        new_time = Time.at(vm_xml['TEMPLATE/SCHED_ACTION/TIME'].to_i)

        expected_time = now + 60*60*24  # Expected day is tomorrow

        expect(new_time.yday).to eq(expected_time.yday)
        expect(new_time.year).to eq(expected_time.year)
        expect(vm_xml['TEMPLATE/SCHED_ACTION/END_VALUE'].to_i).to eq(2)
        expect(vm_xml['TEMPLATE/SCHED_ACTION/DONE']).not_to be_nil
    end

    it "should create new schedule action to poweroff the machine (hourly)" do
        now = Time.now
        vm_id_2 = cli_create("onevm create", <<-EOT)
            NAME = "test_vm1_hours"
            CPU = 0.1
            MEMORY = 128
            SCHED_ACTION = [
                ACTION = "poweroff-hard",
                TIME = "#{now.to_i}",
                REPEAT = "3",
                DAYS = "4",
                END_TYPE = "1",
                END_VALUE = "3"
            ]
        EOT
        vm_2 = VM.new(vm_id_2)

        cli_action("onevm deploy test_vm1_hours host01")

        vm_2.state?("POWEROFF", /FAIL/, :timeout => 30)

        vm_xml = cli_action_xml("onevm show test_vm1_hours -x")

        new_time = Time.at(vm_xml['TEMPLATE/SCHED_ACTION/TIME'].to_i)

        now_hour = now.hour > 19 ? now.hour - 20 : now.hour + 4

        expect(new_time.hour).to eq(now_hour)
        expect(vm_xml['TEMPLATE/SCHED_ACTION/DONE']).not_to be_nil
    end

    it "should fail to create new schedule action with errors" do
        # Wrong days
        tmpl_vm = <<-EOF
            NAME = "test_vm1_error"
            CPU = 0.1
            MEMORY = 128
            SCHED_ACTION = [
                ACTION = "poweroff-hard",
                TIME = "#{Time.now.to_i}",
                REPEAT = "0",
                DAYS = "8,9",
                END_TYPE = "1",
                END_VALUE = "3"
            ]
        EOF

        cli_create("onetemplate create", tmpl_vm, false)
        cli_create("onevm create", tmpl_vm, false)

        # Wrong repeat
        tmpl_vm = <<-EOF
            NAME = "test_vm2_error"
            CPU = 0.1
            MEMORY = 128
            SCHED_ACTION = [
                ACTION = "poweroff-hard",
                TIME = "#{Time.now.to_i}",
                REPEAT = "5",
                DAYS = "5,6",
                END_TYPE = "1",
                END_VALUE = "3"
            ]
        EOF

        cli_create("onetemplate create", tmpl_vm, false)
        cli_create("onevm create", tmpl_vm, false)

        # Wrong end type
        tmpl_vm = <<-EOF
            NAME = "test_vm2_error"
            CPU = 0.1
            MEMORY = 128
            SCHED_ACTION = [
                ACTION = "poweroff-hard",
                TIME = "#{Time.now.to_i}",
                REPEAT = "0",
                DAYS = "5,6",
                END_TYPE = "3",
                END_VALUE = "3"
            ]
        EOF

        cli_create("onetemplate create", tmpl_vm, false)
        cli_create("onevm create", tmpl_vm, false)

        # Wrong time
        tmpl_vm = <<-EOF
            NAME = "test_vm2_error"
            CPU = 0.1
            MEMORY = 128
            SCHED_ACTION = [
                ACTION = "poweroff-hard",
                TIME = "not a time",
                REPEAT = "0",
                DAYS = "5,6",
                END_TYPE = "0",
                END_VALUE = "3"
            ]
        EOF

        cli_create("onetemplate create", tmpl_vm, false)
        cli_create("onevm create", tmpl_vm, false)

        # Wrong warning
        tmpl_vm = <<-EOF
            NAME = "test_vm2_error"
            CPU = 0.1
            MEMORY = 128
            SCHED_ACTION = [
                ACTION = "poweroff-hard",
                TIME = "#{Time.now.to_i}",
                WARNING = "not a time",
                REPEAT = "0",
                DAYS = "5,6",
                END_TYPE = "3",
                END_VALUE = "3"
            ]
        EOF

        cli_create("onetemplate create", tmpl_vm, false)
        cli_create("onevm create", tmpl_vm, false)
    end

    it "should create new schedule action to terminate the vm in 60 seconds" do
        tmpl_vm = <<-EOF
            NAME = "test_vm1_60_seconds"
            CPU = 0.1
            MEMORY = 128
            SCHED_ACTION = [
                ACTION = "terminate-hard",
                TIME = "+60",
                WARNING = "+10"
            ]
        EOF

        time = Time.now

        vm_id = cli_create("onevm create", tmpl_vm)
        vm = VM.new(vm_id)

        cli_action("onevm deploy #{vm_id} host01")

        vm.running?

        vm_xml = vm.info
        expect(vm_xml['TEMPLATE/SCHED_ACTION/WARNING'].to_i).to be_between(time.to_i,vm_xml['TEMPLATE/SCHED_ACTION/TIME'].to_i)

        vm.state?('DONE')

        time_end = Time.now

        vm_xml = vm.info

        expect(time_end - time).to be_between(60,120).inclusive
        expect(vm_xml['TEMPLATE/SCHED_ACTION']).to be_nil
    end

    it "should schedule VM snapshot actions" do
        # Deploy VM
        vm = VM.new(cli_create('onevm create --mem 1 --cpu 1'))
        cli_action("onevm deploy #{vm.id} host01")

        vm.running?

        # Create Snapshot
        cli_action("onevm snapshot-create #{vm.id} snap_test --schedule now")

        # Wait Scheduled Action executed
        wait_loop(:success => true, :timeout => 30) do
            vm.xml['TEMPLATE/SCHED_ACTION/DONE'].to_i > 0
        end

        xml = vm.xml;
        sa_id = xml['TEMPLATE/SCHED_ACTION/ID']
        snap_id = xml['TEMPLATE/SNAPSHOT/SNAPSHOT_ID']
        expect(xml['TEMPLATE/SCHED_ACTION/MESSAGE'].to_s).to eq('')
        expect(xml['TEMPLATE/SNAPSHOT']).not_to be_nil

        cli_action("onevm delete-chart #{vm.id} #{sa_id}")

        # Revert Snapshot
        cli_action("onevm snapshot-revert #{vm.id} #{snap_id} --schedule now")

        # Wait Scheduled Action executed
        wait_loop(:success => true, :timeout => 30) do
            vm.xml['TEMPLATE/SCHED_ACTION/DONE'].to_i > 0
        end

        xml = vm.xml;
        sa_id = xml['TEMPLATE/SCHED_ACTION/ID']
        expect(xml['TEMPLATE/SCHED_ACTION/MESSAGE'].to_s).to eq('')
        expect(xml['TEMPLATE/SNAPSHOT']).not_to be_nil

        cli_action("onevm delete-chart #{vm.id} #{sa_id}")

        # Delete Snapshot
        cli_action("onevm snapshot-delete #{vm.id} #{snap_id} --schedule now")

        # Wait Scheduled Action executed
        wait_loop(:success => true, :timeout => 30) do
            vm.xml['TEMPLATE/SCHED_ACTION/DONE'].to_i > 0
        end

        vm.running?

        xml = vm.xml;
        sa_id = xml['TEMPLATE/SCHED_ACTION/ID']
        expect(xml['TEMPLATE/SCHED_ACTION/MESSAGE'].to_s).to eq('')
        expect(xml['TEMPLATE/SNAPSHOT']).to be_nil

        cli_action("onevm delete-chart #{vm.id} #{sa_id}")
    end

    it "should schedule VM disk snapshot actions" do
        img_id = cli_create("oneimage create -d 1", <<-EOT)
            NAME = "test_img"
            TYPE = "DATABLOCK"
            FSTYPE = "ext3"
            SIZE = 256
        EOT

        tmpl_vm = <<-EOF
            NAME = "test_vm_disk_snapshots"
            CPU = 0.1
            MEMORY = 128
            DISK = [ IMAGE_ID = #{img_id} ]
        EOF

        # Deploy VM
        vm = VM.new(cli_create('onevm create', tmpl_vm))
        cli_action("onevm deploy #{vm.id} host01")

        vm.running?

        # Create Snapshot
        cli_action("onevm disk-snapshot-create #{vm.id} 0 snap_test --schedule now")

        # Wait Scheduled Action executed
        wait_loop(:success => true, :timeout => 30) do
            vm.xml['TEMPLATE/SCHED_ACTION/DONE'].to_i > 0
        end

        xml = vm.xml;
        sa_id = xml['TEMPLATE/SCHED_ACTION/ID']
        expect(xml['TEMPLATE/SCHED_ACTION/MESSAGE'].to_s).to eq('')
        expect(xml['SNAPSHOTS/SNAPSHOT']).not_to be_nil

        cli_action("onevm delete-chart #{vm.id} #{sa_id}")

        # Revert Snapshot
        cli_action("onevm poweroff #{vm.id}")

        vm.stopped?

        cli_action("onevm disk-snapshot-create #{vm.id} 0 snap_test2")
        cli_action("onevm disk-snapshot-revert #{vm.id} 0 0 --schedule now")

        # Wait Scheduled Action executed
        wait_loop(:success => true, :timeout => 30) do
            vm.xml['TEMPLATE/SCHED_ACTION/DONE'].to_i > 0
        end

        xml = vm.xml;
        sa_id = xml['TEMPLATE/SCHED_ACTION/ID']
        expect(xml['TEMPLATE/SCHED_ACTION/MESSAGE'].to_s).to eq('')
        expect(xml['SNAPSHOTS/SNAPSHOT']).not_to be_nil

        cli_action("onevm delete-chart #{vm.id} #{sa_id}")

        # Delete Snapshot
        cli_action("onevm disk-snapshot-delete #{vm.id} 0 1 --schedule now")

        # Wait Scheduled Action executed
        wait_loop(:success => true, :timeout => 30) do
            vm.xml['TEMPLATE/SCHED_ACTION/DONE'].to_i > 0
        end

        xml = vm.xml;
        sa_id = xml['TEMPLATE/SCHED_ACTION/ID']
        expect(xml['TEMPLATE/SCHED_ACTION/MESSAGE'].to_s).to eq('')

        cli_action("onevm delete-chart #{vm.id} #{sa_id}")
    end

    it "should create Scheduled Action in Template and instantiate VM" do
        template = <<-EOF
            NAME = "Test sched action"
            MEMORY = 1024
            CPU = 1
            SCHED_ACTION = [
                ACTION = "poweroff",
                TIME = "+10",
                WARNING = "+1"
            ]
        EOF

        t_id = cli_create('onetemplate create', template)

        xml = cli_action_xml("onetemplate show -x #{t_id}")

        expect(xml['TEMPLATE/SCHED_ACTION/ACTION']).to eq('poweroff')
        expect(xml['TEMPLATE/SCHED_ACTION/TIME']).to eq('+10')
        expect(xml['TEMPLATE/SCHED_ACTION/WARNING']).to eq('+1')

        vm_id = cli_create("onetemplate instantiate #{t_id}")

        xml = cli_action_xml("onevm show -x #{vm_id}")

        expect(xml['TEMPLATE/SCHED_ACTION/ID']).not_to be_nil
        expect(xml['TEMPLATE/SCHED_ACTION/ACTION']).to eq('poweroff')
        expect(xml['TEMPLATE/SCHED_ACTION/TIME'].to_i).to be > 0
        expect(xml['TEMPLATE/SCHED_ACTION/WARNING'].to_i).to be > 0
    end

    it 'should fail to create Scheduled Action for VM in DONE state' do
        vm = VM.new(cli_create('onevm create --name test_done1 --memory 128 --cpu 1'))

        vm.terminate_hard

        cli_action("onevm backup #{vm.id} --schedule +100", false)
        cli_action("onevm poweroff #{vm.id} --schedule +100", false)
        cli_action("onevm snapshot-create #{vm.id} should_fail --schedule now", false)
    end

    it 'should fail to update or delete Scheduled Action for VM in DONE state' do
        vm = VM.new(cli_create('onevm create --name test_done2 --memory 128 --cpu 1'))

        cli_action("onevm poweroff #{vm.id} --schedule +100")

        sched_id = vm.xml['SCHED_ACTIONS/ID']

        vm.terminate

        cli_update("onevm sched-update #{vm.id} #{sched_id}", "END_TYPE=0", false, false)
        cli_action("onevm sched-delete #{vm.id} #{sched_id}", false)
    end

    it 'should run fsck to check Scheduled Action consistency' do
        run_fsck
    end
end
