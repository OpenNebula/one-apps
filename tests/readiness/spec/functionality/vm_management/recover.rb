require 'init_functionality'
require 'VN'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

require 'pry'

describe "VirtualMachine recover section test" do

    before(:all) do
        @tmp_file = Tempfile.new('one-recover-deletedb')
        tmp_file_path = @tmp_file.path

        cli_create("onehost create host_recov --im dummy --vm dummy")

        cli_update("onedatastore update system", "TM_MAD=dummy", false)
        cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)

        @image = cli_create("oneimage create --name test-recover-image --type os " <<
                            "--target hda --path #{tmp_file_path} -d default --no_check_capacity")

        wait_loop do
            xml = cli_action_xml("oneimage show -x #{@image}")
            xml["STATE"] == "1"
        end

        net = VN.create(<<-EOT)
            NAME = test_vnet_recov
            BRIDGE = vbr0
            NETWORK_ADDRESS = "10.0.0.0"
            VN_MAD = dummy
            AR = [
                TYPE = "IP4",
                SIZE = 255,
                IP = "10.0.0.1" ]
        EOT
        net.ready?
        @vnet = net.id

        @tmpl = <<-EOF
            NAME = test
            CPU  = 1
            MEMORY = 1
            GRAPHICS = [
                TYPE = "vnc",
                LISTEN = "127.0.0.1"
            ]
            NIC = [ NETWORK_ID = #{@vnet} ]
            DISK = [ IMAGE_ID = #{@image} ]
        EOF

        cli_create_user('uA', 'abc')
        cli_action('oneuser addgroup uA oneadmin')
    end

    after(:all) do
        run_fsck
    end

    before(:each) do
        as_user('uA') do
            @vm = VM.new(cli_create('onevm create', @tmpl))
        end
    end

    after(:each) do
        @vm.terminate_hard
    end

    def check_resources
        xml = cli_action_xml("oneimage show -x #{@image}")
        expect(xml["VMS/ID[1]"]).to eq @vm.id.to_s

        xml = cli_action_xml("onehost show -x host_recov")
        expect(xml["VMS/ID[1]"]).to eq @vm.id.to_s

        xml = cli_action_xml("onevnet show -x #{@vnet}")
        expect(xml["AR_POOL/AR/LEASES/LEASE[1]/VM"]).to eq @vm.id.to_s

        xml = @vm.xml
        expect(xml["TEMPLATE/GRAPHICS/PORT"]).not_to be_nil
    end

    def check_resources_empty
        xml = cli_action_xml("oneimage show -x #{@image}")
        expect(xml["VMS"]).to be_empty

        xml = cli_action_xml("onehost show -x host_recov")
        expect(xml["VMS"]).to be_empty

        xml = cli_action_xml("onevnet show -x #{@vnet}")
        expect(xml["AR_POOL/AR/LEASES"]).to be_empty

        xml = @vm.xml
        expect(xml["TEMPLATE/GRAPHICS/PORT"]).to be_nil
    end

    it "should check that onevm recover --delete free the resources" do
        as_user('uA') do
            cli_action("onevm deploy #{@vm.id} host_recov")

            @vm.running?

            check_resources

            cli_action("onevm recover --delete #{@vm.id}")

            check_resources_empty
        end
    end

    it "should check that onevm recover --delete-db free the resources" do
        as_user('uA') do
            cli_action("onevm deploy #{@vm.id} host_recov")

            @vm.running?

            check_resources

            cli_action("onevm recover --delete-db #{@vm.id}")

            check_resources_empty
        end
    end

    it "should check resources after onevm recover --recreate" do
        as_user('uA') do
            cli_action("onevm deploy #{@vm.id} host_recov")

            @vm.running?

            check_resources

            # Recover and deploy
            cli_action("onevm recover --recreate #{@vm.id}")

            cli_action("onevm deploy #{@vm.id} host_recov")

            @vm.running?

            check_resources
        end
    end

    it "should check resources after onevm recover --recreate in pending state" do
        as_user('uA') do
            # Recover and deploy
            cli_action("onevm recover --recreate #{@vm.id}")

            cli_action("onevm deploy #{@vm.id} host_recov")

            @vm.running?

            check_resources
        end
    end

    it "should check resources after onevm recover --recreate in stopped state" do
        as_user('uA') do
            cli_action("onevm deploy #{@vm.id} host_recov")

            @vm.running?

            check_resources

            cli_action("onevm stop #{@vm.id}")
            @vm.state?('STOPPED')

            # Recover and deploy
            cli_action("onevm recover --recreate #{@vm.id}")

            @vm.state?('PENDING')

            cli_action("onevm deploy #{@vm.id} host_recov")

            @vm.running?

            check_resources
        end
    end

    it "should check resources after onevm recover --recreate in undeployed state" do
        as_user('uA') do
            cli_action("onevm deploy #{@vm.id} host_recov")

            @vm.running?

            check_resources

            @vm.undeploy

            # Recover and deploy
            cli_action("onevm recover --recreate #{@vm.id}")

            @vm.state?('PENDING')

            cli_action("onevm deploy #{@vm.id} host_recov")

            @vm.running?

            check_resources
        end
    end

    it "should check resources after onevm recover --recreate in poweroff state" do
        as_user('uA') do
            cli_action("onevm deploy #{@vm.id} host_recov")

            @vm.running?

            check_resources

            @vm.poweroff

            # Recover and deploy
            cli_action("onevm recover --recreate #{@vm.id}")

            @vm.state?('PENDING')

            cli_action("onevm deploy #{@vm.id} host_recov")

            @vm.running?

            check_resources
        end
    end

    it "should check resources after onevm recover --recreate in suspended state" do
        as_user('uA') do
            cli_action("onevm deploy #{@vm.id} host_recov")

            @vm.running?

            check_resources

            cli_action("onevm suspend #{@vm.id}")

            @vm.state?('SUSPENDED')

            # Recover and deploy
            cli_action("onevm recover --recreate #{@vm.id}")

            @vm.state?('PENDING')

            cli_action("onevm deploy #{@vm.id} host_recov")

            @vm.running?

            check_resources
        end
    end
end
