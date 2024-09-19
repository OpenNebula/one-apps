require 'init_functionality'

RSpec.describe 'Showback tests' do
    before(:all) do
        # Update TM_MADs
        cli_update('onedatastore update 0', "TM_MAD=dummy\nDS_MAD=dummy", false)
        cli_update('onedatastore update 1', "TM_MAD=dummy\nDS_MAD=dummy", false)

        # Create dummy host
        @host_id = cli_create('onehost create localhost -i dummy -v dummy')

        @img_id = cli_create('oneimage create -d default --name test_flow --size 32 --no_check_capacity')

        # Create VM template
        @template = <<-EOF
                    NAME   = vm_template
                    CPU    = 1
                    MEMORY = 128
                    DISK = [ IMAGE_ID = #{@img_id} ]
        EOF

    end

    before(:each) do
        @vm = VM.new(cli_create("onevm create", @template))

        cli_action("onevm deploy #{@vm.id} #{@host_id}")

        @vm.running?
    end

    after(:each) do
        replace_in_file("#{ONE_VAR_LOCATION}/remotes/tm/dummy/mkimage", /exit 1/, 'exit 0')
        replace_in_file("#{ONE_VAR_LOCATION}/remotes/tm/dummy/delete", /exit 1/, 'exit 0')
        replace_in_file("#{ONE_VAR_LOCATION}/remotes/tm/dummy/snap_create", /exit 1/, 'exit 0')
        replace_in_file("#{ONE_VAR_LOCATION}/remotes/tm/dummy/snap_delete", /exit 1/, 'exit 0')
        replace_in_file("#{ONE_VAR_LOCATION}/remotes/tm/dummy/resize", /exit 1/, 'exit 0')

        cli_action("onevm terminate #{@vm.id}")
    end

    after(:all) do
        FileUtils.rm_r(Dir['/tmp/opennebula_dummy_actions/*'])
    end

    def replace_in_file(filename, patern, replacement)
        text = File.read(filename)
        content = text.gsub(patern, replacement)
        File.open(filename, "w") { |file| file << content }
    end

    it 'VM should have a record in accouting ' do
        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id}]/VM/ID"]).to eq(@vm.id.to_s)
        expect(xml["HISTORY[OID=#{@vm.id}]/VM/TEMPLATE/MEMORY"]).to eq('128')
        expect(xml["HISTORY[OID=#{@vm.id}]/VM/TEMPLATE/CPU"]).to eq('1')
        expect(xml["HISTORY[OID=#{@vm.id}]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
    end

    it 'VM disk attach and detach should create new records in accouting ' do
        # Disk attach
        disk_template = <<-EOF
            DISK = [ TYPE = fs, SIZE = 64 ]
        EOF

        cli_update("onevm disk-attach #{@vm.id} --file", disk_template, false)

        @vm.running?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=0]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/DISK[DISK_ID=0]/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/DISK[DISK_ID=1]/SIZE"]).to eq('64')

        # Disk detach
        cli_action("onevm disk-detach #{@vm.id} 1")

        @vm.running?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=0]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/DISK[DISK_ID=0]/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/DISK[DISK_ID=1]/SIZE"]).to eq('64')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=2]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')

        # Disk attach in poweroff
        @vm.poweroff

        cli_update("onevm disk-attach #{@vm.id} --file", disk_template, false)

        @vm.poweroff?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=2]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=3]/VM/TEMPLATE/DISK[DISK_ID=0]/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=3]/VM/TEMPLATE/DISK[DISK_ID=1]/SIZE"]).to eq('64')

        # Disk detach in poweroff
        cli_action("onevm disk-detach #{@vm.id} 1")

        @vm.poweroff?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=3]/VM/TEMPLATE/DISK[DISK_ID=0]/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=3]/VM/TEMPLATE/DISK[DISK_ID=1]/SIZE"]).to eq('64')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=4]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
    end

    it 'VM disk snapshot create and delete should create new records in accouting' do
        # Snapshot create
        cli_action("onevm disk-snapshot-create #{@vm.id} 0 snapshot1")

        @vm.running?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=0]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=0]/VM/TEMPLATE/DISK/DISK_SNAPSHOT_TOTAL_SIZE"]).to eq('0')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/DISK/DISK_SNAPSHOT_TOTAL_SIZE"]).to eq('32')

        # Snapshot delete
        cli_action("onevm disk-snapshot-delete #{@vm.id} 0 0")

        @vm.running?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/DISK/DISK_SNAPSHOT_TOTAL_SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=2]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=2]/VM/TEMPLATE/DISK/DISK_SNAPSHOT_TOTAL_SIZE"]).to eq('0')

        # Snapshot create in poweroff
        @vm.poweroff

        cli_action("onevm disk-snapshot-create #{@vm.id} 0 snapshot1")

        @vm.poweroff?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=2]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=2]/VM/TEMPLATE/DISK/DISK_SNAPSHOT_TOTAL_SIZE"]).to eq('0')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=3]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=3]/VM/TEMPLATE/DISK/DISK_SNAPSHOT_TOTAL_SIZE"]).to eq('32')

        # Snapshot delete in poweroff
        cli_action("onevm disk-snapshot-delete #{@vm.id} 0 1")

        @vm.poweroff?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=3]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=3]/VM/TEMPLATE/DISK/DISK_SNAPSHOT_TOTAL_SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=4]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=4]/VM/TEMPLATE/DISK/DISK_SNAPSHOT_TOTAL_SIZE"]).to eq('0')
    end

    it 'VM disk resize should create new record in accouting' do
        # Disk resize
        cli_action("onevm disk-resize #{@vm.id} 0 64")

        @vm.running?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=0]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/DISK/SIZE"]).to eq('64')

        # Disk resize in poweroff
        @vm.poweroff

        cli_action("onevm disk-resize #{@vm.id} 0 128")

        @vm.poweroff?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/DISK/SIZE"]).to eq('64')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=2]/VM/TEMPLATE/DISK/SIZE"]).to eq('128')
    end

    it 'VM resize should create new record in accouting' do
        # CPU and memory hotplug resize
        cli_action("onevm resize #{@vm.id} --cpu 2 --memory 256")

        @vm.running?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=0]/VM/TEMPLATE/MEMORY"]).to eq('128')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=0]/VM/TEMPLATE/CPU"]).to eq('1')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/MEMORY"]).to eq('256')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/CPU"]).to eq('2')

        # CPU and memory resize in poweroff
        @vm.poweroff

        cli_action("onevm resize #{@vm.id} --cpu 3 --memory 512")

        @vm.poweroff?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/MEMORY"]).to eq('256')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/CPU"]).to eq('2')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=2]/VM/TEMPLATE/MEMORY"]).to eq('512')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=2]/VM/TEMPLATE/CPU"]).to eq('3')
    end

    it 'VM disk fail to (de)attach should create history record' do
        # Fail disk-attach
        File.write('/tmp/opennebula_dummy_actions/attach_disk', 'failure')

        disk_template = <<-EOF
            DISK = [ TYPE = fs, SIZE = 64 ]
        EOF

        cli_update("onevm disk-attach #{@vm.id} --file", disk_template, false)

        @vm.running?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=0]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/DISK[DISK_ID=0]/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/DISK[DISK_ID=1]"]).to be_nil

        # Fail disk-detach
        File.write('/tmp/opennebula_dummy_actions/detach_disk', 'failure')

        cli_action("onevm disk-detach #{@vm.id} 0")

        @vm.running?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/DISK[DISK_ID=0]/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=2]/VM/TEMPLATE/DISK[DISK_ID=0]/SIZE"]).to eq('32')

        # Fail disk-attach in poweroff
        replace_in_file("#{ONE_VAR_LOCATION}/remotes/tm/dummy/mkimage", /exit 0/, 'exit 1')

        @vm.poweroff

        cli_update("onevm disk-attach #{@vm.id} --file", disk_template, false)

        @vm.poweroff?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=2]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=3]/VM/TEMPLATE/DISK[DISK_ID=0]/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=3]/VM/TEMPLATE/DISK[DISK_ID=1]"]).to be_nil

        # Fail disk-detach in poweroff
        replace_in_file("#{ONE_VAR_LOCATION}/remotes/tm/dummy/delete", /exit 0/, 'exit 1')

        cli_action("onevm disk-detach #{@vm.id} 0")

        @vm.poweroff?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=3]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=4]/VM/TEMPLATE/DISK[DISK_ID=0]/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=4]/VM/TEMPLATE/DISK[DISK_ID=1]"]).to be_nil
    end

    it 'VM disk snapshot fail to create or delete should create history record' do
        # Prepare a snapshot
        cli_action("onevm disk-snapshot-create #{@vm.id} 0 snapshot1")

        @vm.running?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=0]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=0]/VM/TEMPLATE/DISK/DISK_SNAPSHOT_TOTAL_SIZE"]).to eq('0')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/DISK/DISK_SNAPSHOT_TOTAL_SIZE"]).to eq('32')

        # Fail to create disk-snapshot
        File.write('/tmp/opennebula_dummy_actions/disk_snapshot_create', 'failure')

        cli_action("onevm disk-snapshot-create #{@vm.id} 0 snapshot2")

        @vm.running?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/DISK/DISK_SNAPSHOT_TOTAL_SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=2]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=2]/VM/TEMPLATE/DISK/DISK_SNAPSHOT_TOTAL_SIZE"]).to eq('32')

        # Fail to delete disk-snapshot
        replace_in_file("#{ONE_VAR_LOCATION}/remotes/tm/dummy/snap_delete", /exit 0/, 'exit 1')

        cli_action("onevm disk-snapshot-delete #{@vm.id} 0 0")

        @vm.running?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=2]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=2]/VM/TEMPLATE/DISK/DISK_SNAPSHOT_TOTAL_SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=3]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=3]/VM/TEMPLATE/DISK/DISK_SNAPSHOT_TOTAL_SIZE"]).to eq('32')

        # Fail disk-snapshot-create in poweroff
        replace_in_file("#{ONE_VAR_LOCATION}/remotes/tm/dummy/snap_create", /exit 0/, 'exit 1')

        @vm.poweroff

        cli_action("onevm disk-snapshot-create #{@vm.id} 0 snapshot3")

        @vm.poweroff?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=3]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=3]/VM/TEMPLATE/DISK/DISK_SNAPSHOT_TOTAL_SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=4]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=4]/VM/TEMPLATE/DISK/DISK_SNAPSHOT_TOTAL_SIZE"]).to eq('32')

        # Fail disk-snapshot-delete in poweroff
        cli_action("onevm disk-snapshot-delete #{@vm.id} 0 0")

        @vm.poweroff?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=4]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=4]/VM/TEMPLATE/DISK/DISK_SNAPSHOT_TOTAL_SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=5]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=5]/VM/TEMPLATE/DISK/DISK_SNAPSHOT_TOTAL_SIZE"]).to eq('32')
    end

    it 'VM disk fail to resize should create history record' do
        # Fail to resize
        File.write('/tmp/opennebula_dummy_actions/resize_disk', 'failure')

        cli_action("onevm disk-resize #{@vm.id} 0 64")

        @vm.running?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=0]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')

        # Fail disk resize in poweroff/undeployed state
        @vm.poweroff

        replace_in_file("#{ONE_VAR_LOCATION}/remotes/tm/dummy/resize", /exit 0/, 'exit 1')

        cli_action("onevm disk-resize #{@vm.id} 0 64")

        @vm.poweroff?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=2]/VM/TEMPLATE/DISK/SIZE"]).to eq('32')
    end

    it 'VM disk fail to resize should create history record' do
        # Fail resize
        File.write('/tmp/opennebula_dummy_actions/resize', 'failure')

        cli_action("onevm resize #{@vm.id} --cpu 2 --memory 256")

        @vm.running?

        xml = cli_action_xml('oneacct -x')

        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=0]/VM/TEMPLATE/MEMORY"]).to eq('128')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=0]/VM/TEMPLATE/CPU"]).to eq('1')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/MEMORY"]).to eq('128')
        expect(xml["HISTORY[OID=#{@vm.id} and SEQ=1]/VM/TEMPLATE/CPU"]).to eq('1')
    end
end
