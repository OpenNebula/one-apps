#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Bridge Type test" do
    def build_vnet_linux_bridge
        template=<<-EOF
         NAME   = "br_net"
         BRIDGE = br0
         VN_MAD = bridge
         AR = [ TYPE="IP4", SIZE="250", IP="192.168.0.1" ]
        EOF
    end

    def build_vnet_ovswitch
        template=<<-EOF
         NAME   = "ovs_net"
         BRIDGE = br0
         VN_MAD = ovswitch
         AR = [ TYPE="IP4", SIZE="250", IP="192.168.0.1" ]
        EOF
    end

    def build_vnet_eth
        template=<<-EOF
         NAME   = "ethernet_net"
         VN_MAD = ethernet
         AR = [ TYPE="IP4", SIZE="250", IP="192.168.0.1" ]
        EOF
    end

    prepend_before(:all) do
        @defaults = YAML::load(File.read("spec/functionality/virtual_network/defaults.yaml"))
        @defaults_yaml=File.realpath(File.join(File.dirname(__FILE__),'defaults.yaml'))

        eth_dir = "#{ONE_VAR_LOCATION}/remotes/vnm/ethernet/"
        FileUtils.mkdir_p(eth_dir) unless File.directory?(eth_dir)

        File.open("#{eth_dir}vnet_create",
                  File::CREAT|File::TRUNC|File::RDWR, 0744) { |f|
            f.write("#!/bin/bash\n")
            f.write("exit 0\n")
        }

        File.open("#{eth_dir}vnet_delete",
                  File::CREAT|File::TRUNC|File::RDWR, 0744) { |f|
            f.write("#!/bin/bash\n")
            f.write("exit 0\n")
        }
    end

    before(:all) do
        @info = {}
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "Should create a network with bridge as vnmad and check the bridge type" do
        @info[:linux_vn] = cli_create("onevnet create", build_vnet_linux_bridge)
        vn_xml = cli_action_xml("onevnet show -x #{@info[:linux_vn]}")
        expect(vn_xml['TEMPLATE/BRIDGE_TYPE']).to eq("linux")
    end

    it "Should create a network with ovswitch as vnmad and check the bridge type" do
        @info[:ovs_vn] = cli_create("onevnet create", build_vnet_ovswitch)
        vn_xml = cli_action_xml("onevnet show -x #{@info[:ovs_vn]}")
        expect(vn_xml['TEMPLATE/BRIDGE_TYPE']).to eq("openvswitch")
    end

    it "Should create a network with ethernet as vnmad and check the bridge type" do
        @info[:eth_vn] = cli_create("onevnet create", build_vnet_eth)
        vn_xml = cli_action_xml("onevnet show -x #{@info[:eth_vn]}")
        expect(vn_xml['TEMPLATE/BRIDGE_TYPE']).to eq("none")
    end

    it "Should create a VM with a bridge type network and check the bridge type of the nic" do
        @info[:linux_vm] = cli_create("onevm create --name br_test --cpu 1 --memory 1 --nic #{@info[:linux_vn]}")
        vm_xml = cli_action_xml("onevm show -x #{@info[:linux_vm]}")
        expect(vm_xml['TEMPLATE/NIC/BRIDGE_TYPE']).to eq("linux")
    end

    it "Should create a VM with a ovswith type network and check the bridge type of the nic" do
        @info[:ovs_vm] = cli_create("onevm create --name ovs_test --cpu 1 --memory 1 --nic #{@info[:ovs_vn]}")
        vm_xml = cli_action_xml("onevm show -x #{@info[:ovs_vm]}")
        expect(vm_xml['TEMPLATE/NIC/BRIDGE_TYPE']).to eq("openvswitch")
    end

    it "Should create a VM with a ethernet type network and check the bridge type of the nic" do
        @info[:eth_vm] = cli_create("onevm create --name ethernet_test --cpu 1 --memory 1 --nic #{@info[:eth_vn]}")
        vm_xml = cli_action_xml("onevm show -x #{@info[:eth_vm]}")
        expect(vm_xml['TEMPLATE/NIC/BRIDGE_TYPE']).to eq("none")
        expect(vm_xml['TEMPLATE/NIC/BRIDGE']).to eq("")
    end

    it "Should create a VM with a ovswith change bridge type and create VM with new type" do
        tmpl = <<-EOF
           BRIDGE_TYPE="openvswitch_dpdk"
        EOF

        cli_update("onevnet update #{@info[:ovs_vn]}", tmpl, true)

        vn_xml = cli_action_xml("onevnet show -x #{@info[:ovs_vn]}")
        expect(vn_xml['TEMPLATE/BRIDGE_TYPE']).to eq('openvswitch_dpdk')

        @info[:ovsd_vm] = cli_create("onevm create --name ovs_test --cpu 1 --memory 1 --nic #{@info[:ovs_vn]}")
        vm_xml = cli_action_xml("onevm show -x #{@info[:ovsd_vm]}")
        expect(vm_xml['TEMPLATE/NIC/BRIDGE_TYPE']).to eq('openvswitch_dpdk')
    end

    after(:all) do
        #Delete de VMs
        cli_action("onevm terminate --hard #{@info[:linux_vm]}")
        cli_action("onevm terminate --hard #{@info[:ovs_vm]}")
        cli_action("onevm terminate --hard #{@info[:ovsd_vm]}")

        #Delete de Networks
        cli_action("onevnet delete #{@info[:linux_vn]}")
        cli_action("onevnet delete #{@info[:ovs_vn]}")

        # Cleanup
        eth_dir = "#{ONE_VAR_LOCATION}/remotes/vnm/ethernet/"
        FileUtils.rm("#{eth_dir}vnet_create", :force => true)
        FileUtils.rm("#{eth_dir}vnet_delete", :force => true)
    end

end

