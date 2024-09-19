require 'init_functionality'
require 'sunstone_test'
require 'sunstone/HostvCenter'
require 'sunstone/VNetvCenter'
require 'sunstone/VNet'

begin
    require 'pry'
rescue LoadError
end

RSpec.describe "vCenter VNet test", :type => 'skip' do

    prepend_before(:all) do
        @defaults_yaml = File.join(File.dirname(__FILE__), 'defaults.yaml')
    end

    before(:all) do
        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1],
        }

        @sunstone_test = SunstoneTest.new(@auth)
        @sunstone_test.login
        @vCenterHost = Sunstone::HostvCenter.new(@sunstone_test)
        @vCenterVNet = Sunstone::VNetvCenter.new(@sunstone_test)
        defaults_yaml = File.join(File.dirname(__FILE__), 'defaults_vcenter.yaml')

        begin
            @defaults = YAML.load_file(defaults_yaml)
        rescue Exception => e
            STDERR.puts "Can't load default files: #{e.message}"
            exit -1
        end

        @vCenterHost.import(@defaults[:cluster], @defaults)

        @vnet = Sunstone::VNet.new(@sunstone_test)
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "Import vCenter VNet" do
        extra_data = [
            {key: "netsize", value: "100"},
            {key: "type_select", value: "ip4"},
            {key: "four_ip_net", value: "10.10.0.1"}
        ]
        @vCenterVNet.import(@defaults, extra_data)
    end

    it "Check vCenter VNet" do
        xml = cli_action_xml("onevnet list -x") rescue nil
        expect(xml["VNET[NAME=\"#{@defaults[:network]}\"]"]).not_to be(nil)
    end

    it "Check data vCenter VNet" do
        hash_info = [
            {key: "BRIDGE", value: "DPortGroup"},
            {key: "OPENNEBULA_MANAGED", value: "NO"},
            {key: "VN_MAD", value: "vcenter"},
            {key: "VCENTER_PORTGROUP_TYPE", value: "Distributed Port Group"}
         ]
        ars = [
            {IP: "10.10.0.1", SIZE: "100"}
        ]

        @vnet.check(@defaults[:network], hash_info, ars)
    end

end
