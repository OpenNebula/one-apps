require 'init_functionality'
require 'sunstone_test'
require 'sunstone/VNTemplate'

RSpec.describe "Sunstone vnet template tab", :type => 'skip' do

    before(:all) do
        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        @sunstone_test = SunstoneTest.new(@auth)
        @sunstone_test.login
        @vntemplate = Sunstone::VNTemplate.new(@sunstone_test)
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "should create a vnet template with bridge driver" do
        hash = {
            bridge: "br0",
            mode: "bridge",
            phydev: "test-phydev"
        }
        ars = [
            { type: "ip4", ip: "192.168.0.1", size: "100" },
            { type: "ip6", mac: "00:03:c4:c9:d7:9f", ip6: "2001::", size: "10" }
        ]

        @vntemplate.create("test_bridge", hash, ars)
        @sunstone_test.wait_resource_create("vntemplate", "test_bridge")
    end

    it "should check a vnet template with bridge driver via UI" do
        hash_info = [
            { key: "BRIDGE", value: "br0" }
        ]

        ars = [
            { IP: "192.168.0.1", SIZE: "100" }
        ]

        @vntemplate.check("test_bridge", hash_info, ars)
    end

    it "should update a vnet template with bridge driver" do
        hash = {
            attrs: []
        }

        @vntemplate.update("test_bridge", "", hash)

        @sunstone_test.wait_resource_update("vntemplate", "test_bridge", { :key=>"TEMPLATE/VN_MAD", :value=>"bridge"})
        vntemplate = cli_action_xml("onevntemplate show -x test_bridge") rescue nil
    
        expect(vntemplate['TEMPLATE/VN_MAD']).to eql "bridge"
        expect(vntemplate['TEMPLATE/PHYDEV']).to eql "test-phydev"
        expect(vntemplate['TEMPLATE/AR[IP="192.168.0.1"]/SIZE']).to eql "100"
        expect(vntemplate['TEMPLATE/AR[IP="192.168.0.1"]/TYPE']).to eql "IP4"
        expect(vntemplate['TEMPLATE/AR[MAC="00:03:c4:c9:d7:9f"]/SIZE']).to eql "10"
        expect(vntemplate['TEMPLATE/AR[MAC="00:03:c4:c9:d7:9f"]/TYPE']).to eql "IP6"
    end

    it "should update a vnet template AR" do
        new_ar = {
            :id => "0",
            :size => "23"
        }
        @vntemplate.updateAR("test_bridge", new_ar)

        hash_info = [
            { key: "BRIDGE", value: "br0" }
        ]

        ars = [
            { IP: "192.168.0.1", SIZE: "23" }
        ]

        @vntemplate.check("test_bridge", hash_info, ars)
    end

    it "should delete a vnet template" do
        @vntemplate.delete("test_bridge")

        @sunstone_test.wait_resource_delete("vntemplate", "test_bridge")
        xml = cli_action_xml("onevntemplate list -x") rescue nil
        if !xml.nil?
            expect(xml['IMAGE[NAME="test_bridge"]']).to be(nil)
        end
    end

    it "should create a vnet template with fw driver" do
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

        @vntemplate.create("test_fw", hash, ars)

        @sunstone_test.wait_resource_create("vntemplate", "test_fw")
        vntemplate = cli_action_xml("onevntemplate show -x test_fw") rescue nil

        expect(vntemplate['TEMPLATE/BRIDGE']).to eql "br0-fw"
        expect(vntemplate['TEMPLATE/VN_MAD']).to eql "fw"
        expect(vntemplate['TEMPLATE/PHYDEV']).to eql "test-phydev-fw"
        expect(vntemplate['TEMPLATE/FILTER_MAC_SPOOFING']).to eql "YES"
        expect(vntemplate['TEMPLATE/AR[IP="192.168.0.1"]/SIZE']).to eql "128"
        expect(vntemplate['TEMPLATE/AR[IP="192.168.0.1"]/TYPE']).to eql "IP4"
    end

    it "should create a vnet template with 802.1Q driver" do
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

        @vntemplate.create("test_802.1Q", hash, ars)

        @sunstone_test.wait_resource_create("vntemplate", "test_802.1Q")
        vntemplate = cli_action_xml("onevntemplate show -x test_802.1Q") rescue nil

        expect(vntemplate['TEMPLATE/BRIDGE']).to eql "br0-802.1Q"
        expect(vntemplate['TEMPLATE/VN_MAD']).to eql "802.1Q"
        expect(vntemplate['TEMPLATE/PHYDEV']).to eql "test-phydev-802.1Q"
        expect(vntemplate['TEMPLATE/FILTER_IP_SPOOFING']).to eql "YES"
        expect(vntemplate['TEMPLATE/MTU']).to eql "1400"
    end

    it "should create a vnet template with VXLAN driver" do
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

        @vntemplate.create("test_vxlan", hash, ars)

        @sunstone_test.wait_resource_create("vntemplate", "test_vxlan")
        vntemplate = cli_action_xml("onevntemplate show -x test_vxlan") rescue nil

        expect(vntemplate['TEMPLATE/BRIDGE']).to eql "br0-vxlan"
        expect(vntemplate['TEMPLATE/VN_MAD']).to eql "vxlan"
        expect(vntemplate['TEMPLATE/PHYDEV']).to eql "test-phydev-vxlan"
        expect(vntemplate['TEMPLATE/FILTER_MAC_SPOOFING']).to eql "YES"
        expect(vntemplate['TEMPLATE/VLAN_ID']).to eql "1"
        expect(vntemplate['TEMPLATE/MTU']).to eql "2400"
    end

    it "should create a vnet template with ovswitch driver" do
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

        @vntemplate.create("test_ovswitch", hash, ars)

        @sunstone_test.wait_resource_create("vntemplate", "test_ovswitch")
        vntemplate = cli_action_xml("onevntemplate show -x test_ovswitch") rescue nil

        expect(vntemplate['TEMPLATE/BRIDGE']).to eql "br0-ovswitch"
        expect(vntemplate['TEMPLATE/VN_MAD']).to eql "ovswitch"
        expect(vntemplate['TEMPLATE/PHYDEV']).to eql "test-phydev-ovswitch"
        expect(vntemplate['TEMPLATE/VLAN_ID']).to eql "2"
    end

    it "should create a vnet template with ovswitch-vxlan driver" do
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

        @vntemplate.create("test_ovswitch-vxlan", hash, ars)

        @sunstone_test.wait_resource_create("vntemplate", "test_ovswitch-vxlan")
        vntemplate = cli_action_xml("onevntemplate show -x test_ovswitch-vxlan") rescue nil

        expect(vntemplate['TEMPLATE/BRIDGE']).to eql "br0-ovswitch-vxlan"
        expect(vntemplate['TEMPLATE/VN_MAD']).to eql "ovswitch_vxlan"
        expect(vntemplate['TEMPLATE/PHYDEV']).to eql "test-phydev-ovswitch-vxlan"
        expect(vntemplate['TEMPLATE/MTU']).to eql "200"
    end

    it "should create a vnet template in advanced mode" do
        vn_template_name = "test-vntemplate-advanced"

        vntemplate_template = <<-EOF
            NAME = "#{vn_template_name}"
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

        @vntemplate.create_advanced(vntemplate_template)

        @sunstone_test.wait_resource_create("vntemplate", vn_template_name)
        vntemplate = cli_action_xml("onevntemplate show -x '#{vn_template_name}'") rescue nil

        expect(vntemplate['TEMPLATE/PHYDEV']).to eql "test-phydev"
        expect(vntemplate['TEMPLATE/NETWORK_ADDRESS']).to eql "192.168.83.0"
        expect(vntemplate['TEMPLATE/DNS']).to eql "212.56.129.228 212.56.132.20"
    end

    it "should instantiate a vnet template with custom attribute" do
        hash = {
            name: 'test-vnet-instantiate',
            arange: '0',
            context: {
                custom_attrs: [
                    { key: 'test_key', value: 'test_value' }
                ]
            }
        }

        @vntemplate.instantiate('test-vntemplate-advanced', hash)

        @sunstone_test.wait_resource_create("vnet", hash[:name])
        vnet = cli_action_xml("onevnet show -x '#{hash[:name]}'") rescue nil

        hash[:context][:custom_attrs].each { |attr|
            expect(vnet["TEMPLATE/#{attr[:key].upcase}"]).to eql attr[:value]
        }
    end

end
