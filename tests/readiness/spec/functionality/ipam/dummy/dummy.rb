#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
require 'nokogiri'
#-------------------------------------------------------------------------------
#  Dummy IPAM driver - use to test core and driver protocol
#    - Register Address Range: with an IP will preserve the IP and will not add
#      any attribute. Without IP will assign:
#      AR=[TYPE="IP4", IP="10.0.0.10", SIZE="100", NETWORK_MASK="255.255.255.0",
#          GATEWAY="10.0.0.1", DNS="10.0.0.1", IPAM_MAD="dummy" ]
#
#    - Get address will return a random address in the range of the AddressRange
#      as for a class C network: IP=$BASE_IP.$HOST_ID. IT MAY BE IN USE!!!
#
#-------------------------------------------------------------------------------

RSpec.describe "IPAM functionality test" do
    def check_reservation(i, name, ip, size, pid, dns)
        vnet = cli_action_xml("onevnet show -x #{name}")

        test(vnet, 'TEMPLATE/BRIDGE', "br0")
        test(vnet, 'PARENT_NETWORK_ID', "0")
        test(vnet, "AR_POOL/AR[AR_ID=\"#{i}\"]/TYPE", "IP4")
        test(vnet, "AR_POOL/AR[AR_ID=\"#{i}\"]/IP", "#{ip}") if !ip.empty?
        test(vnet, "AR_POOL/AR[AR_ID=\"#{i}\"]/SIZE", "#{size}")
        test(vnet, "AR_POOL/AR[AR_ID=\"#{i}\"]/DNS", dns) if !dns.empty?
        test(vnet, "AR_POOL/AR[AR_ID=\"#{i}\"]/PARENT_NETWORK_AR_ID", "#{pid}")
        expect(vnet["AR_POOL/AR[AR_ID=\"#{i}\"]/IPAM_MAD"]).to be_nil
    end

    def test(xml, xpath, str)
        expect(xml[xpath]).to eq(str)
    end
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        @dummy_touch = "#{File.dirname(__FILE__)}/unregister_address_range"
        @dummy_pass  = "#{File.dirname(__FILE__)}/register_address_range"
        @dummy_u = "#{ONE_VAR_LOCATION}/remotes/ipam/dummy/unregister_address_range"
        @dummy_r = "#{ONE_VAR_LOCATION}/remotes/ipam/dummy/register_address_range"

        FileUtils.cp(@dummy_u, "#{@dummy_u}.orig")
        FileUtils.cp(@dummy_touch, @dummy_u)
        FileUtils.cp(@dummy_r, "#{@dummy_r}.orig")
        FileUtils.cp(@dummy_pass, @dummy_r)

        template=<<-EOF
         NAME   = "all_net"
         BRIDGE = br0
         VN_MAD = dummy
         AR = [ TYPE="IP4", SIZE="64", IPAM_MAD = "dummy" ]
         AR = [ TYPE="IP4", SIZE="250", IP="192.168.0.1", IPAM_MAD="dummy" ]
         AR = [ TYPE="IP4", SIZE="128", IP="172.16.0.2" ]
         AR = [ TYPE="IP4", SIZE="50", IP="192.168.1.1", IPAM_MAD="dummy" ]
        EOF

        @vnet_id = cli_create("onevnet create", template)
    end

    after(:all) do
        FileUtils.cp("#{@dummy_r}.orig", @dummy_r)
        FileUtils.cp("#{@dummy_u}.orig", @dummy_u)
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should use IPAM action register_address_range when allocating a VNET" do
        wait_loop(:success => 'READY', :break => 'ERROR') do
            xml = cli_action_xml("onevnet show -x #{@vnet_id}")
            VirtualNetwork::VN_STATES[xml['STATE'].to_i]
        end

        vnet_xml = cli_action_xml("onevnet show -x #{@vnet_id}")

        expect(vnet_xml['NAME']).to eq("all_net")
        expect(vnet_xml['BRIDGE']).to eq("br0")

        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/TYPE']).to eq("IP4")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/IP']).to eq("10.0.0.1")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/DNS']).to eq("10.0.0.1")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/GATEWAY']).to eq("10.0.0.1")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/SIZE']).to eq("100")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/IPAM_MAD']).to eq("dummy")

        expect(vnet_xml['AR_POOL/AR[AR_ID="1"]/TYPE']).to eq("IP4")
        expect(vnet_xml['AR_POOL/AR[AR_ID="1"]/IP']).to eq("192.168.0.1")
        expect(vnet_xml['AR_POOL/AR[AR_ID="1"]/SIZE']).to eq("250")
        expect(vnet_xml['AR_POOL/AR[AR_ID="1"]/IPAM_MAD']).to eq("dummy")

        expect(vnet_xml['AR_POOL/AR[AR_ID="2"]/TYPE']).to eq("IP4")
        expect(vnet_xml['AR_POOL/AR[AR_ID="2"]/IP']).to eq("172.16.0.2")
        expect(vnet_xml['AR_POOL/AR[AR_ID="2"]/SIZE']).to eq("128")
        expect(vnet_xml['AR_POOL/AR[AR_ID="2"]/IPAM_MAD']).to be_nil

        expect(vnet_xml['AR_POOL/AR[AR_ID="3"]/TYPE']).to eq("IP4")
        expect(vnet_xml['AR_POOL/AR[AR_ID="3"]/IP']).to eq("192.168.1.1")
        expect(vnet_xml['AR_POOL/AR[AR_ID="3"]/SIZE']).to eq("50")
        expect(vnet_xml['AR_POOL/AR[AR_ID="3"]/IPAM_MAD']).to eq("dummy")
    end

    it "should use IPAM action unregister_address_range when deleting an AR" do
        cli_action("onevnet rmar #{@vnet_id} 3")
        vnet_xml = cli_action_xml("onevnet show -x #{@vnet_id}")

        expect(vnet_xml['AR_POOL/AR[AR_ID="3"]']).to be_nil
        expect(File.exist?("/tmp/unregister_test"))
    end

    it "data should be passed decrypted to the IPAM driver" do
        doc = File.open("/tmp/unregister_test") { |f| Nokogiri::XML(f) }

        expect(doc.at_xpath("//ONE_PASSWORD").text).to eq("password")
        FileUtils.rm("/tmp/unregister_test")
    end

    it "should use IPAM actions: allocate_address, get_address and free_address" do
        template=<<-EOF
         NAME   = "vmtest"
         CPU    = 1
         MEMORY = 128
         NIC    = [ NETWORK = "all_net" ]
         NIC    = [ NETWORK = "all_net", IP = "192.168.0.15" ]
         NIC    = [ NETWORK = "all_net", IP = "172.16.0.44" ]
         CONTEXT= [ NETWORK = "YES" ]
        EOF

        vm_id  = cli_create("onevm create", template)
        wait_loop(:success => false) {
            cmd = cli_action("onevm show #{vm_id} 2>/dev/null", nil)
            cmd.fail?
        }
        vm_xml = cli_action_xml("onevm show -x #{vm_id}")

        expect(vm_xml['TEMPLATE/NIC[1]/NETWORK']).to eq("all_net")
        expect(vm_xml['TEMPLATE/NIC[1]/NETWORK_ID']).to eq("0")
        expect(vm_xml['TEMPLATE/NIC[1]/IP']).to match(/10\.0\.0\.[0-9]+/)
        expect(vm_xml['TEMPLATE/NIC[1]/BRIDGE']).to eq("br0")
        expect(vm_xml['TEMPLATE/NIC[1]/PHYDEV']).to eq(nil)
        expect(vm_xml['TEMPLATE/NIC[1]/AR_ID']).to eq("0")

        expect(vm_xml['TEMPLATE/CONTEXT/ETH0_DNS']).to eq("10.0.0.1")
        expect(vm_xml['TEMPLATE/CONTEXT/ETH0_GATEWAY']).to eq("10.0.0.1")
        expect(vm_xml['TEMPLATE/CONTEXT/ETH0_IP']).to match(/10\.0\.0\.[0-9]+/)
        expect(vm_xml['TEMPLATE/CONTEXT/ETH0_MASK']).to eq("255.255.255.0")
        expect(vm_xml['TEMPLATE/CONTEXT/NETWORK']).to eq("YES")
        expect(vm_xml['TEMPLATE/CONTEXT/ETH1_IP']).to eq("192.168.0.15")
        expect(vm_xml['TEMPLATE/CONTEXT/ETH2_IP']).to eq("172.16.0.44")

        vnet_xml = cli_action_xml("onevnet show -x #{@vnet_id}")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/USED_LEASES']).to eq("1")
        expect(vnet_xml['AR_POOL/AR[AR_ID="1"]/USED_LEASES']).to eq("1")
        expect(vnet_xml['AR_POOL/AR[AR_ID="2"]/USED_LEASES']).to eq("1")

        cli_action("onevm terminate 0")
        wait_loop() {
            xml = cli_action_xml("onevm show -x 0")
            OpenNebula::VirtualMachine::VM_STATE[xml['STATE'].to_i] == 'DONE'
        }

        vnet_xml = cli_action_xml("onevnet show -x #{@vnet_id}")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/USED_LEASES']).to eq("0")
        expect(vnet_xml['AR_POOL/AR[AR_ID="1"]/USED_LEASES']).to eq("0")
        expect(vnet_xml['AR_POOL/AR[AR_ID="2"]/USED_LEASES']).to eq("0")
    end

    it "IPAM should lease addresses for reservations" do
        cli_action("onevnet reserve 0 -n r1 -s 2 -a 0")
        wait_loop(:success => false) {
            cmd = cli_action("onevnet show r1 2>/dev/null", nil)
            cmd.fail?
        }
        wait_loop() {
            xml   = cli_action_xml("onevnet show -x #{@vnet_id}")
            xml['USED_LEASES'].to_i >= 2
        }
        cli_action("onevnet reserve 0 -n r2 -s 5 -a 1")
        wait_loop(:success => false) {
            cmd = cli_action("onevnet show r2 2>/dev/null", nil)
            cmd.fail?
        }

        check_reservation(0, "r1", "", "2", 0, "10.0.0.1")
        check_reservation(0, "r2", "", "5", 1, "")

        xml = cli_action_xml("onevnet show -x all_net")

        test(xml,'AR_POOL/AR[AR_ID="0"]/USED_LEASES',"2")
        test(xml,'AR_POOL/AR[AR_ID="1"]/USED_LEASES', "5")

        test(xml,'USED_LEASES', "7")

        cli_action("onevnet delete r1")
        wait_loop(:success => true) {
            cmd = cli_action("onevnet show r1 2>/dev/null", nil)
            cmd.fail?
        }
        cli_action("onevnet delete r2")
        wait_loop(:success => true) {
            cmd = cli_action("onevnet show r2 2>/dev/null", nil)
            cmd.fail?
        }
    end

    it "IPAM should lease addresses for reservations (specific IP)" do
        cli_action("onevnet reserve 0 -n r1 -s 20 -a 0 -i 10.0.0.20")
        wait_loop(:success => false) {
            cmd = cli_action("onevnet show r1 2>/dev/null", nil)
            cmd.fail?
        }
        wait_loop() {
            xml   = cli_action_xml("onevnet show -x #{@vnet_id}")
            xml['USED_LEASES'].to_i >= 20
        }
        cli_action("onevnet reserve 0 -n r2 -s 50 -a 1 -i 192.168.0.40")

        check_reservation(0, "r1", "", "20", 0, "10.0.0.1")
        check_reservation(0, "r2", "", "50", 1, "")

        xml = cli_action_xml("onevnet show -x all_net")

        test(xml,'AR_POOL/AR[AR_ID="0"]/USED_LEASES',"20")
        test(xml,'AR_POOL/AR[AR_ID="1"]/USED_LEASES', "50")

        test(xml,'USED_LEASES', "70")

        cli_action("onevnet delete r1")
        wait_loop(:success => true) {
            cmd = cli_action("onevnet show r1 2>/dev/null", nil)
            cmd.fail?
        }
        cli_action("onevnet delete r2")
    end
end
