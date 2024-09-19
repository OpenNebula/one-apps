require 'init_functionality'
require 'sunstone_test'
require 'sunstone/HostvCenter'
require 'sunstone/DatastorevCenter'

begin
    require 'pry'
rescue LoadError
end

RSpec.describe "vCenter Host test", :type => 'skip' do

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
        @vCenterDs = Sunstone::DatastorevCenter.new(@sunstone_test)
        defaults_yaml = File.join(File.dirname(__FILE__), 'defaults_vcenter.yaml')

        begin
            @defaults = YAML.load_file(defaults_yaml)
        rescue Exception => e
            STDERR.puts "Can't load default files: #{e.message}"
            exit -1
        end
    end

    before(:each) do
        sleep 3
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "Import vCenter Hosts" do
        @vCenterHost.import(@defaults[:cluster2], @defaults)
        @vCenterDs.import(@defaults[:cluster2], @defaults)
    end

    it "Check vCenter Host" do
        xml = cli_action_xml("onehost list -x") rescue nil
        expect(xml["HOST[NAME=\"#{@defaults[:cluster2]}\"]"]).not_to be(nil)
    end

    it "Import wild" do
        @vCenterHost.import_wilds(@defaults[:cluster2], @defaults)
    end

    it "Check wild" do
        xml = cli_action_xml("onevm list -x") rescue nil
        expect(xml["VM[DEPLOY_ID=\"#{@defaults[:wild_id]}\"]"]).not_to be(nil)
    end
end
