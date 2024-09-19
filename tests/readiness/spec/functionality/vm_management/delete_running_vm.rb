
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

describe "VirtualMachine delete operation test" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do
        cli_update("onedatastore update system", "TM_MAD=dummy", false)
        cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)
        wait_loop() {
            xml = cli_action_xml("onedatastore show -x default")
            xml['FREE_MB'].to_i > 0
        }

        @vnet_id = cli_create("onevnet create", <<-EOT)
            NAME = "network"
            AR = [
               TYPE = "IP4",
               IP = "10.0.0.1",
               SIZE = "200"
            ]
            BRIDGE = "eth0"
            NETWORK_ADDRESS = "10.0.0.0"
            GATEWAY = "10.0.0.1"
            VN_MAD = "dummy"
        EOT

        @image_id = cli_create("oneimage create -d default", <<-EOT)
            NAME = "testimage"
            TYPE = "OS"
            TARGET = "hda"
            PATH = "http://services/images/alpine-vrouter.raw.gz"
        EOT

        wait_loop do
            xml = cli_action_xml("oneimage show -x #{@image_id}")

            xml["STATE"] == "1"
        end

        @host_id = cli_create("onehost create host0 --im dummy --vm dummy")

        @id = cli_create("onevm create --name test --cpu 1 --memory 1 " <<
                   "  --disk #{@image_id} --nic #{@vnet_id}")
        @vm = VM.new(@id)

        cli_action("onevm deploy #{@id} host0")
        @vm.running?

        vm_xml = @vm.info
        @vm_cpu = vm_xml["TEMPLATE/CPU"].to_i
        @vm_mem = vm_xml["TEMPLATE/MEMORY"].to_i

        img_xml = cli_action_xml("oneimage show -x #{@image_id}")
        @im_rvms = img_xml["RUNNING_VMS"].to_i

        vnet_xml = cli_action_xml("onevnet show -x #{@vnet_id}")
        expect(vnet_xml["AR_POOL/AR/LEASES/LEASE/IP"]).to be

        host_xml = cli_action_xml("onehost show -x #{@host_id}")
        @pre_host_cpu = host_xml["HOST_SHARE/CPU_USAGE"].to_i
        @pre_host_mem = host_xml["HOST_SHARE/MEM_USAGE"].to_i
        @pre_host_rvms = host_xml["HOST_SHARE/RUNNING_VMS"].to_i
    end

    it "should delete a running VirtualMachine and then, check the new" <<
        " values of the Host where it was deployed and that the Image " <<
        "and the VirtualNetwork is correctly updated" do

        @vm.terminate_hard

        host_xml = cli_action_xml("onehost show -x #{@host_id}")
        host_cpu = host_xml["HOST_SHARE/CPU_USAGE"].to_i
        host_mem = host_xml["HOST_SHARE/MEM_USAGE"].to_i
        host_rvms = host_xml["HOST_SHARE/RUNNING_VMS"].to_i

        expect(host_cpu).to eql(@pre_host_cpu - @vm_cpu*100)
        expect(host_mem).to eql(@pre_host_mem - @vm_mem*1024)
        expect(host_rvms).to eql(@pre_host_rvms - 1)

        img_xml = cli_action_xml("oneimage show -x #{@image_id}")
        running_vms = img_xml["RUNNING_VMS"].to_i

        expect(running_vms).to eql(@im_rvms - 1)

        vnet_xml = cli_action_xml("onevnet show -x #{@vnet_id}")
        expect(vnet_xml["AR_POOL/AR/LEASES/LEASE/IP"]).to be_falsey
    end
end