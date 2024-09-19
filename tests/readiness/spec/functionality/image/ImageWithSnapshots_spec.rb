#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
require 'image'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Image snapshots tests" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update("onedatastore update system", mads, false)
        cli_update("onedatastore update default", mads, false)

        @iid = cli_create("oneimage create -d default --type OS --no_check_capacity"\
                          " --name testimage --path /etc/passwd --persistent")
        @image = CLIImage.new(@iid)

        @image.ready?

        @host_id = cli_create("onehost create dummy -i dummy -v dummy")

        @vmid = cli_create("onevm create --name test --cpu 1 --memory 128"\
                          " --disk testimage")

        cli_action("onevm deploy #{@vmid} #{@host_id}")

        @vm = VM.new(@vmid)

        @vm.running?

        @vm.poweroff
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should take snapshots" do
        ['sn1', 'sn2', 'sn3', 'sn4', 'sn5', 'sn-rename'].each do |i|
            cli_action("onevm disk-snapshot-create #{@vmid} 0 #{i}")
            @vm.poweroff?
        end
    end

    it "should rename a snapshot" do
        cli_action("onevm disk-snapshot-rename #{@vmid} 0 5 'renamed-snap'")
        xml = cli_action_xml("onevm show -x #{@vmid}")

        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'renamed-snap']"]).not_to eq(nil)

        cli_action("onevm disk-snapshot-revert #{@vmid} 0 4")

        @vm.poweroff?

        cli_action("onevm disk-snapshot-delete #{@vmid} 0 5")
    end

    it "should delete a snapshot with children" do
        @vm.poweroff?

        cli_action("onevm disk-snapshot-delete #{@vmid} 0 3")
    end

    it "should delete the active snapshot" do
        @vm.poweroff?

        cli_action("onevm disk-snapshot-delete #{@vmid} 0 4")
    end

    it "should save the snapshots into the image" do
        @vm.poweroff?

        cli_action("onevm terminate #{@vmid}")

        @image.ready?

        xml = @image.xml

        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn1']/PARENT"]).to eq("-1")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn2']/PARENT"]).to eq("0")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn3']/PARENT"]).to eq("1")
    end

    it "should not allow chtype" do
        cli_action("oneimage chtype #{@iid} CDROM", false)
    end

    it "should not allow clone" do
        cli_action("oneimage clone #{@iid} clone_test", false)
    end

    it "should not allow to be made non-persistent" do
        cli_action("oneimage nonpersistent #{@iid}", false)
    end

    it "should not allow to delete the active snapshot" do
        cli_action("oneimage snapshot-delete #{@iid} 2", false)
    end

    it "should not allow to delete a snapshot with children" do
        cli_action("oneimage snapshot-delete #{@iid} 1", false)
    end

    it "should copy the snapshots to the disk and snaphots in the saved image" do
        @vmid = cli_create("onevm create --name test --cpu 1 --memory 128"\
                          " --disk testimage")

        cli_action("onevm deploy #{@vmid} #{@host_id}")

        vm = VM.new(@vmid)

        vm.running?

        cli_action("onevm poweroff #{@vmid}")

        vm.poweroff?

        xml = cli_action_xml("onevm show -x #{@vmid}")

        next_snapshot = xml["SNAPSHOTS/NEXT_SNAPSHOT"].to_i

        cli_action("onevm disk-snapshot-create #{@vmid} 0 sn6")

        xml = cli_action_xml("onevm show -x #{@vmid}")

        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn1']/PARENT"]).to eq("-1")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn2']/PARENT"]).to eq("0")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn3']/PARENT"]).to eq("1")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn6']/PARENT"]).to eq("2")

        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn6']/ID"].to_i).to eq(next_snapshot)

        vm.poweroff?

        xml = cli_action_xml("onevm show -x #{@vmid}")

        next_snapshot+=1

        expect(xml["SNAPSHOTS/NEXT_SNAPSHOT"].to_i).to eq(next_snapshot)

        cli_action("onevm disk-snapshot-revert #{@vmid} 0 2")

        vm.poweroff?

        cli_action("onevm disk-snapshot-delete #{@vmid} 0 #{next_snapshot-1}")

        vm.poweroff?

        vm.terminate

        @image.ready?

        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn1']/PARENT"]).to eq("-1")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn2']/PARENT"]).to eq("0")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn3']/PARENT"]).to eq("1")

        expect(xml["SNAPSHOTS/NEXT_SNAPSHOT"].to_i).to eq(next_snapshot)
    end

    it "should copy the snapshots to the disk and changed these snapshots" do

        xml = cli_action_xml("oneimage show -x #{@iid}")

        next_snapshot = xml["SNAPSHOTS/NEXT_SNAPSHOT"].to_i

        vmid = cli_create("onevm create --name test_2 --cpu 1 --memory 128"\
                          " --disk testimage")

        cli_action("onevm deploy #{vmid} #{@host_id}")

        vm = VM.new(vmid)

        vm.running?

        cli_action("onevm poweroff #{vmid}")

        vm.poweroff?

        xml = cli_action_xml("onevm show -x #{vmid}")

        cli_action("onevm disk-snapshot-create #{vmid} 0 sn7")

        xml = cli_action_xml("onevm show -x #{vmid}")

        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn1']/PARENT"]).to eq("-1")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn2']/PARENT"]).to eq("0")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn3']/PARENT"]).to eq("1")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn7']/PARENT"]).to eq("2")

        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn7']/ID"].to_i).to eq(next_snapshot)

        vm.poweroff?

        xml = cli_action_xml("onevm show -x #{vmid}")

        next_snapshot+=1

        expect(xml["SNAPSHOTS/NEXT_SNAPSHOT"].to_i).to eq(next_snapshot)

        cli_action("onevm disk-snapshot-revert #{vmid} 0 1")

        vm.poweroff?

        cli_action("onevm disk-snapshot-delete #{vmid} 0 #{next_snapshot-1}")

        vm.poweroff?

        cli_action("onevm disk-snapshot-delete #{vmid} 0 2")

        vm.poweroff?

        vm.terminate

        @image.ready?

        xml = @image.xml

        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn1']/PARENT"]).to eq("-1")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn2']/PARENT"]).to eq("0")

        expect(xml["SNAPSHOTS/NEXT_SNAPSHOT"].to_i).to eq(next_snapshot)
    end
end

