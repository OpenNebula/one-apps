#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Mixed snapshots tests" do
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
        conf = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update("onedatastore update system", conf, false)
        cli_update("onedatastore update default", conf, false)

        conf = "ALLOW_ORPHANS=MIXED"

        cli_update("onedatastore update system", conf, false)
        cli_update("onedatastore update default", conf, false)

        @iid = cli_create("oneimage create -d default --type OS"\
                          " --name testimage --path /etc/passwd --persistent")
        wait_loop() {
            xml = cli_action_xml("oneimage show -x #{@iid}")
            xml['STATE'] == '1'
        }

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

    it "all the snapshots should be parentless" do
        xml = cli_action_xml("onevm show -x #{@vmid}")

        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn1']/PARENT"]).to eq("-1")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn2']/PARENT"]).to eq("-1")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn3']/PARENT"]).to eq("-1")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn4']/PARENT"]).to eq("-1")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn5']/PARENT"]).to eq("-1")
    end

    it "should delete the last snapshot" do
        cli_action("onevm disk-snapshot-delete #{@vmid} 0 4")
    end

    it "should change CURRENT_BASE after a revert" do
        @vm.poweroff?

        cli_action("onevm disk-snapshot-revert #{@vmid} 0 1", true)

        @vm.poweroff?

        expect(@vm["SNAPSHOTS/CURRENT_BASE"]).to eq("1")
    end

    it "should not delete the active snapshot" do
        cli_action("onevm disk-snapshot-delete #{@vmid} 0 1", false)
    end

    it "new snapshot should have the current_base as parent" do
        cli_action("onevm disk-snapshot-create #{@vmid} 0 sn6")

        @vm.poweroff?

        xml = @vm.xml

        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn6']/PARENT"]).to eq("1")
        expect(xml["SNAPSHOTS/SNAPSHOT[NAME = 'sn2']/CHILDREN"]).to eq("5")
    end
end

