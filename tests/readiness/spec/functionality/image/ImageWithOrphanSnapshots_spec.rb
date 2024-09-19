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
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        mads = "TM_MAD=dummy\nDS_MAD=dummy\nDATASTORE_CAPACITY_CHECK=NO"

        cli_update("onedatastore update system", mads, false)
        cli_update("onedatastore update default", mads, false)

        mads = "TM_MAD=dummy\nDS_MAD=dummy\nDATASTORE_CAPACITY_CHECK=NO"
        cli_update("onedatastore update default", mads, false)

        @iid = cli_create("oneimage create -d default --type OS"\
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
        ['sn1', 'sn2', 'sn3', 'sn4', 'sn5'].each do |i|
            cli_action("onevm disk-snapshot-create #{@vmid} 0 #{i}")
            @vm.poweroff?
        end
    end

    it "should save the snapshots into the image" do
        cli_action("onevm terminate #{@vmid}")

        @image.ready?
        xml = @image.xml

        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn1']/PARENT"]).to eq("-1")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn2']/PARENT"]).to eq("-1")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn3']/PARENT"]).to eq("-1")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn4']/PARENT"]).to eq("-1")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn5']/PARENT"]).to eq("-1")
    end

    it "should not allow chtype" do
        cli_action("oneimage chtype #{@iid} CDROM", false)
    end

    it "should not allow clone" do
        cli_action("oneimage clone #{@iid} clone_test", false)

        @image.ready?
    end

    it "should not allow to be made non-persistent" do
        cli_action("oneimage nonpersistent #{@iid}", false)
    end

    it "should allow to delete the active snapshot" do
        cli_action("oneimage snapshot-delete #{@iid} 4", true)

        @image.ready?
    end

    it "should allow to delete a snapshot with children" do
        cli_action("oneimage snapshot-delete #{@iid} 0", true)

        @image.ready?
    end

    it "should copy the snapshots to the disk and snaphots in the saved image" do
        @vmid = cli_create("onevm create --name test --cpu 1 --memory 128"\
                          " --disk testimage")

        cli_action("onevm deploy #{@vmid} #{@host_id}")

        vm = VM.new(@vmid)

        vm.running?

        cli_action("onevm poweroff #{@vmid}")

        vm.poweroff?

        cli_action("onevm disk-snapshot-create #{@vmid} 0 sn6")

        xml = cli_action_xml("onevm show -x #{@vmid}")

        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn2']/PARENT"]).to eq("-1")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn3']/PARENT"]).to eq("-1")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn4']/PARENT"]).to eq("-1")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn6']/PARENT"]).to eq("-1")

        vm.poweroff?

        vm.terminate

        @image.ready?
        xml = @image.xml

        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn2']/PARENT"]).to eq("-1")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn3']/PARENT"]).to eq("-1")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn4']/PARENT"]).to eq("-1")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn6']/PARENT"]).to eq("-1")
    end
end

