require 'init_functionality'
require 'sunstone_test'
require 'sunstone/SecGroups'

RSpec.describe "Sunstone security group tab", :type => 'skip' do

    before(:all) do

        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        @sunstone_test = SunstoneTest.new(@auth)
        @secGr = Sunstone::SecGroups.new(@sunstone_test)

        @vid = cli_create("onevnet create", "NAME = test_vnet\nVN_MAD=dummy\nBRIDGE=vbr0")
        @sunstone_test.wait_resource_create("vnet", "test_vnet")

        @sunstone_test.login
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "should create a security group" do
        rules = [
            {
                type: "inbound", # inbound, outbound
                protocol: "ICMP", # TCP, UDP, ICMP, ICMPv6, IPSEC, ALL
                icmp_type: "8", # ping v4
                network_sel: "ANY" # ANY, NETWORK, VNET
            },
            {
                type: "outbound",
                protocol: "TCP",
                range_sel: "ALL",
                network_sel: "VNET"
            }
        ]

        extra_params = {
            vnet_id: @vid
        }

        @secGr.create("test_secgroup", rules, extra_params)

        @sunstone_test.wait_resource_create("secgroup", "test_secgroup")
        secgroup = cli_action_xml("onesecgroup show -x test_secgroup") rescue nil

        expect(secgroup["TEMPLATE/RULE[PROTOCOL='ICMP']/ICMP_TYPE"]).to eql "8"
        expect(secgroup["TEMPLATE/RULE[PROTOCOL='ICMP']/RULE_TYPE"]).to eql "inbound"
        expect(secgroup["TEMPLATE/RULE[PROTOCOL='TCP']/RULE_TYPE"]).to eql "outbound"
        expect(secgroup["TEMPLATE/RULE[PROTOCOL='TCP']/NETWORK_ID"]).to eql @vid.to_s
    end

    it "should update a security group" do
        rules = [
            {
                type: "outbound",
                protocol: "ICMPv6",
                icmpv6_type: "129", # pong v6
                network_sel: "VNET"
            },
            {
                type: "inbound",
                protocol: "UDP",
                range_sel: "ALL",
                network_sel: "ANY"
            }
        ]

        extra_params = {
            vnet_id: @vid
        }

        @secGr.update("test_secgroup", rules, extra_params)

        @sunstone_test.wait_resource_update("secgroup", "test_secgroup", { :key=>"TEMPLATE/RULE[PROTOCOL='ICMPv6']/NETWORK_ID", :value=>@vid.to_s })
        secgroup = cli_action_xml("onesecgroup show -x test_secgroup") rescue nil

        expect(secgroup["TEMPLATE/RULE[PROTOCOL='ICMPv6']/RULE_TYPE"]).to eql "outbound"
        expect(secgroup["TEMPLATE/RULE[PROTOCOL='ICMPv6']/ICMPV6_TYPE"]).to eql "129"
        expect(secgroup["TEMPLATE/RULE[PROTOCOL='ICMPv6']/NETWORK_ID"]).to eql @vid.to_s
        expect(secgroup["TEMPLATE/RULE[PROTOCOL='UDP']/RULE_TYPE"]).to eql "inbound"
    end

    it "should delete a security group" do
        @secGr.delete("test_secgroup")

        @sunstone_test.wait_resource_delete("secgroup", "test_secgroup")
        xml = cli_action_xml("onesecgroup list -x") rescue nil
        if !xml.nil?
            expect(xml['SECURITY_GROUP[NAME="test_secgroup"]']).to be(nil)
        end
    end
end
