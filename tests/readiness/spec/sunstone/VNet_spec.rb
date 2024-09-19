require 'init_functionality'
require 'sunstone_test'
require 'sunstone/VNet'
require 'sunstone/SecGroups'

RSpec.describe "Sunstone network tab", :type => 'skip' do

    before(:all) do
        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        sg = <<-TEXT
        NAME = test_secgroup

        RULE = [
            PROTOCOL = TCP,
            RULE_TYPE = inbound,
            RANGE = 1000:2000
        ]
      
        RULE = [
            PROTOCOL= TCP,
            RULE_TYPE = outbound,
            RANGE = 1000:2000
        ]
      
        RULE = [
            PROTOCOL = ICMP,
            RULE_TYPE = inbound,
            NETWORK_ID = 0
        ]
        TEXT

        File.open("sg.txt", "w") {|f| f.write(sg)}
        cli_action("onesecgroup create sg.txt")
        
        @sunstone_test = SunstoneTest.new(@auth)
        @sunstone_test.login
        @vnet = Sunstone::VNet.new(@sunstone_test)
        
        @sunstone_test.wait_resource_create("secgroup", "test_secgroup")
        @secGrID = cli_action_xml("onesecgroup show -x test_secgroup")['ID']
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "should create a vnet with IPAM driver" do
        hash = {
            bridge: "br0",
            mode: "bridge",
            phydev: "test-phydev"
        }
        ars = [
            { type: "ip4", ip: "192.168.0.1", size: "100" },
            { type: "ip6", mac: "00:03:c4:c9:d7:9f", ip6: "2001::", size: "10" },
            { type: "ip4", size: "100", ipam: "dummy" }
        ]

        @vnet.create("test_ipam", hash, ars)

        #Check vnet with IPAM driver
        @sunstone_test.wait_resource_create("vnet", "test_ipam")
        vnet = cli_action_xml("onevnet show -x test_ipam") rescue nil

        expect(vnet['TEMPLATE/VN_MAD']).to eql "bridge"
        expect(vnet['TEMPLATE/PHYDEV']).to eql "test-phydev"
        expect(vnet['AR_POOL/AR[IP="192.168.0.1"]/SIZE']).to eql "100"
        expect(vnet['AR_POOL/AR[IP="192.168.0.1"]/TYPE']).to eql "IP4"
        expect(vnet['AR_POOL/AR[MAC="00:03:c4:c9:d7:9f"]/SIZE']).to eql "10"
        expect(vnet['AR_POOL/AR[MAC="00:03:c4:c9:d7:9f"]/TYPE']).to eql "IP6"
        expect(vnet['AR_POOL/AR[IP="10.0.0.1"]/TYPE']).to eql "IP4"
        expect(vnet['AR_POOL/AR[IP="10.0.0.1"]/SIZE']).to eql "100"
        expect(vnet['AR_POOL/AR[IP="10.0.0.1"]/IPAM_MAD']).to eql "dummy"
    end

    it "should create a vnet with bridge driver" do
        hash = {
            bridge: "br0",
            mode: "bridge",
            phydev: "test-phydev"
        }
        ars = [
            { type: "ip4", ip: "192.168.0.1", size: "100" },
            { type: "ip6", mac: "00:03:c4:c9:d7:9f", ip6: "2001::", size: "10" }
        ]

        @vnet.create("test_bridge", hash, ars)
        @sunstone_test.wait_resource_create("vnet", "test_bridge")
    end

    it "should check a vnet with bridge driver via UI" do
        hash_info = [
            { key: "BRIDGE", value: "br0" }
        ]

        ars = [
            { IP: "192.168.0.1", SIZE: "100" }
        ]

        @vnet.check("test_bridge", hash_info, ars)
    end

    it "should update a vnet with bridge driver" do
        hash = {
            attrs: []
        }

        @vnet.update("test_bridge", "", hash)

        #Check a vnet update with bridge driver
        @sunstone_test.wait_resource_update("vnet", "test_bridge", { :key=>"TEMPLATE/VN_MAD", :value=>"bridge" })
        vnet = cli_action_xml("onevnet show -x test_bridge") rescue nil

        expect(vnet['TEMPLATE/VN_MAD']).to eql "bridge"
        expect(vnet['TEMPLATE/PHYDEV']).to eql "test-phydev"
        expect(vnet['AR_POOL/AR[IP="192.168.0.1"]/SIZE']).to eql "100"
        expect(vnet['AR_POOL/AR[IP="192.168.0.1"]/TYPE']).to eql "IP4"
        expect(vnet['AR_POOL/AR[MAC="00:03:c4:c9:d7:9f"]/SIZE']).to eql "10"
        expect(vnet['AR_POOL/AR[MAC="00:03:c4:c9:d7:9f"]/TYPE']).to eql "IP6"
    end

    it "should add a security group" do
        @vnet.add_security_group("test_bridge","test_secgroup")

        @sunstone_test.wait_resource_update("vnet", "test_bridge", { :key=>"TEMPLATE/SECURITY_GROUPS", :value=>"0,#{@secGrID.to_s}" })
        vnet = cli_action_xml("onevnet show -x test_bridge") rescue nil

        expect(vnet['TEMPLATE/VN_MAD']).to eql "bridge"
        expect(vnet['TEMPLATE/PHYDEV']).to eql "test-phydev"
        expect(vnet['AR_POOL/AR[IP="192.168.0.1"]/SIZE']).to eql "100"
        expect(vnet['AR_POOL/AR[IP="192.168.0.1"]/TYPE']).to eql "IP4"
        expect(vnet['AR_POOL/AR[MAC="00:03:c4:c9:d7:9f"]/SIZE']).to eql "10"
        expect(vnet['AR_POOL/AR[MAC="00:03:c4:c9:d7:9f"]/TYPE']).to eql "IP6"
        expect(vnet['TEMPLATE/SECURITY_GROUPS']).to eql "0," + @secGrID
    end

    it "should remove a security group" do
        @vnet.remove_security_group("test_bridge","test_secgroup")

        @sunstone_test.wait_resource_update("vnet", "test_bridge", { :key=>"TEMPLATE/SECURITY_GROUPS", :value=>"0" })
        vnet = cli_action_xml("onevnet show -x test_bridge") rescue nil

        expect(vnet['TEMPLATE/VN_MAD']).to eql "bridge"
        expect(vnet['TEMPLATE/PHYDEV']).to eql "test-phydev"
        expect(vnet['AR_POOL/AR[IP="192.168.0.1"]/SIZE']).to eql "100"
        expect(vnet['AR_POOL/AR[IP="192.168.0.1"]/TYPE']).to eql "IP4"
        expect(vnet['AR_POOL/AR[MAC="00:03:c4:c9:d7:9f"]/SIZE']).to eql "10"
        expect(vnet['AR_POOL/AR[MAC="00:03:c4:c9:d7:9f"]/TYPE']).to eql "IP6"
        expect(vnet['TEMPLATE/SECURITY_GROUPS']).to eql "0"
    end

    it "should delete a vnet" do
        @vnet.delete("test_bridge")

        @sunstone_test.wait_resource_delete("vnet", "test_bridge")
        xml = cli_action_xml("onevnet list -x") rescue nil
        if !xml.nil?
            expect(xml['IMAGE[NAME="test_bridge"]']).to be(nil)
        end
    end

    it "should create a vnet with fw driver" do
        hash = {
            bridge: "br0-fw",
            mode: "fw",
            mac_spoofing: true,
            ip_spoofing: false,
            phydev: "test-phydev-fw"
        }

        ars = [
            { type: "ip4", ip: "192.168.0.1", size: "128" }
        ]

        @vnet.create("test_fw", hash, ars)

        #Check vnet with fw driver
        @sunstone_test.wait_resource_create("vnet", "test_fw")
        vnet = cli_action_xml("onevnet show -x test_fw") rescue nil

        expect(vnet['TEMPLATE/BRIDGE']).to eql "br0-fw"
        expect(vnet['TEMPLATE/VN_MAD']).to eql "fw"
        expect(vnet['TEMPLATE/PHYDEV']).to eql "test-phydev-fw"
        expect(vnet['TEMPLATE/FILTER_MAC_SPOOFING']).to eql "YES"
        expect(vnet['AR_POOL/AR[IP="192.168.0.1"]/SIZE']).to eql "128"
        expect(vnet['AR_POOL/AR[IP="192.168.0.1"]/TYPE']).to eql "IP4"
    end

    it "should create a vnet with 802.1Q driver" do
        hash = {
            bridge: "br0-802.1Q",
            mode: "802.1Q",
            mac_spoofing: false,
            ip_spoofing: true,
            phydev: "test-phydev-802.1Q",
            automatic_vlan: "YES",
            mtu: "1400"
        }

        ars = [
            { type: "ip4", ip: "192.168.0.1", size: "128" }
        ]

        @vnet.create("test_802.1Q", hash, ars)

        #Check vnet with 802.1Q driver
        @sunstone_test.wait_resource_create("vnet", "test_802.1Q")
        vnet = cli_action_xml("onevnet show -x test_802.1Q") rescue nil

        expect(vnet['TEMPLATE/BRIDGE']).to eql "br0-802.1Q"
        expect(vnet['TEMPLATE/VN_MAD']).to eql "802.1Q"
        expect(vnet['TEMPLATE/PHYDEV']).to eql "test-phydev-802.1Q"
        expect(vnet['TEMPLATE/FILTER_IP_SPOOFING']).to eql "YES"
        expect(vnet['TEMPLATE/MTU']).to eql "1400"
    end

    it "should create a vnet with VXLAN driver" do
        hash = {
            bridge: "br0-vxlan",
            mode: "vxlan",
            mac_spoofing: true,
            ip_spoofing: false,
            phydev: "test-phydev-vxlan",
            automatic_vlan: "", # manual vlan id
            vlan_id: "1",
            mtu: "2400"
        }

        ars = [
            { type: "ip4", ip: "192.168.0.1", size: "128" }
        ]

        @vnet.create("test_vxlan", hash, ars)

        #Check vnet with VXLAN driver
        @sunstone_test.wait_resource_create("vnet", "test_vxlan")
        vnet = cli_action_xml("onevnet show -x test_vxlan") rescue nil

        expect(vnet['TEMPLATE/BRIDGE']).to eql "br0-vxlan"
        expect(vnet['TEMPLATE/VN_MAD']).to eql "vxlan"
        expect(vnet['TEMPLATE/PHYDEV']).to eql "test-phydev-vxlan"
        expect(vnet['TEMPLATE/FILTER_MAC_SPOOFING']).to eql "YES"
        expect(vnet['TEMPLATE/VLAN_ID']).to eql "1"
        expect(vnet['TEMPLATE/MTU']).to eql "2400"
    end

    it "should create a vnet with ovswitch driver" do
        hash = {
            bridge: "br0-ovswitch",
            mode: "ovswitch",
            mac_spoofing: false,
            ip_spoofing: false,
            phydev: "test-phydev-ovswitch",
            automatic_vlan: "", # manual vlan id
            vlan_id: "2"
        }

        ars = [
            { type: "ip4", ip: "192.168.0.1", size: "128" }
        ]

        @vnet.create("test_ovswitch", hash, ars)

        #Check vnet with ovswitch driver
        @sunstone_test.wait_resource_create("vnet", "test_ovswitch")
        vnet = cli_action_xml("onevnet show -x test_ovswitch") rescue nil
    
        expect(vnet['TEMPLATE/BRIDGE']).to eql "br0-ovswitch"
        expect(vnet['TEMPLATE/VN_MAD']).to eql "ovswitch"
        expect(vnet['TEMPLATE/PHYDEV']).to eql "test-phydev-ovswitch"
        expect(vnet['TEMPLATE/VLAN_ID']).to eql "2"
    end

    it "should create a vnet with ovswitch-vxlan driver" do
        hash = {
            bridge: "br0-ovswitch-vxlan",
            mode: "ovswitch_vxlan",
            mac_spoofing: false,
            ip_spoofing: false,
            phydev: "test-phydev-ovswitch-vxlan",
            automatic_vlan: "NO",
            mtu: "200"
        }

        ars = [
            { type: "ip4", ip: "192.168.0.1", size: "128" }
        ]

        @vnet.create("test_ovswitch-vxlan", hash, ars)

        #Check vnet with ovswitch-vxlan driver
        @sunstone_test.wait_resource_create("vnet", "test_ovswitch-vxlan")
        vnet = cli_action_xml("onevnet show -x test_ovswitch-vxlan") rescue nil
    
        expect(vnet['TEMPLATE/BRIDGE']).to eql "br0-ovswitch-vxlan"
        expect(vnet['TEMPLATE/VN_MAD']).to eql "ovswitch_vxlan"
        expect(vnet['TEMPLATE/PHYDEV']).to eql "test-phydev-ovswitch-vxlan"
        expect(vnet['TEMPLATE/MTU']).to eql "200"
    end

    it "should create a vnet in advanced mode" do
        vnet_template = <<-EOF
            NAME = "test-vnet-advanced"
            DESCRIPTION = "Testing advanced mode"
            PHYDEV = "test-phydev"
            NETWORK_ADDRESS = "192.168.83.0"
            NETWORK_MASK = "255.255.255.0"
            GATEWAY = "192.168.83.1"
            DNS = "212.56.129.228 212.56.132.20"
            AR = [TYPE = "IP4", IP = "192.168.83.1", SIZE = "250"]
            SECURITY_GROUPS = "0"
            AUTOMATIC_VLAN_ID = "YES"
            VN_MAD = "802.1Q"
        EOF

        @vnet.create_advanced(vnet_template)

        @sunstone_test.wait_resource_create("vnet", "test-vnet-advanced")
        vnet = cli_action_xml("onevnet show -x test-vnet-advanced") rescue nil

        expect(vnet['TEMPLATE/PHYDEV']).to eql "test-phydev"
        expect(vnet['TEMPLATE/NETWORK_ADDRESS']).to eql "192.168.83.0"
        expect(vnet['TEMPLATE/DNS']).to eql "212.56.129.228 212.56.132.20"
    end

    it "should create a vnet with ip hold" do
        vnet_template = <<-EOF
            NAME = "test_vnet_ip_hold"
            DESCRIPTION = "Testing advanced mode"
            PHYDEV = "test-phydev"
            NETWORK_ADDRESS = "192.168.83.0"
            NETWORK_MASK = "255.255.255.0"
            GATEWAY = "192.168.83.1"
            DNS = "212.56.129.228 212.56.132.20"
            AR = [
                IPAM_MAD = "dummy",
                TYPE = "IP4",
                IP   = "10.0.0.1",
                SIZE = "255"
              ]
            SECURITY_GROUPS = "0"
            AUTOMATIC_VLAN_ID = "YES"
            VN_MAD = "802.1Q"
        EOF

        @vnet.create_advanced(vnet_template)

        @sunstone_test.wait_resource_create("vnet", "test_vnet_ip_hold")
        cli_action('onevnet hold "test_vnet_ip_hold" 10.0.0.123 -a 0')

        vnet = cli_action_xml("onevnet show -x test_vnet_ip_hold") rescue nil
        expect(vnet['AR_POOL/AR[AR_ID="0"]/LEASES/LEASE/IP']).to eql "10.0.0.123"
    end

    it "should delete AR without force option" do
        force = false
        ar_id = "0"
        @vnet.delete_ar("test_vnet_ip_hold",ar_id,force)

        @sunstone_test.wait_resource_update("vnet", "test_vnet_ip_hold", { :key=>"AR_POOL/AR[AR_ID='0']/LEASES/LEASE/IP", :value=>"10.0.0.123" })
        vnet = cli_action_xml("onevnet show -x test_vnet_ip_hold") rescue nil
        expect(vnet['AR_POOL/AR[AR_ID="0"]/LEASES/LEASE/IP']).to eql "10.0.0.123"
    end

    it "should delete AR with force option" do
        force = true
        ar_id = "0"
        @vnet.delete_ar("test_vnet_ip_hold",ar_id,force)

        @sunstone_test.wait_resource_update("vnet", "test_vnet_ip_hold", { :key=>"AR_POOL/AR[AR_ID='0']/LEASES", :value=>nil })
        vnet = cli_action_xml("onevnet show -x test_vnet_ip_hold") rescue nil
        expect(vnet['AR_POOL/AR[AR_ID="0"]/LEASES']).to be(nil)
    end
    
end
