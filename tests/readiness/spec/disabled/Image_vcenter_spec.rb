require 'init_functionality'
require 'sunstone_test'
require 'sunstone/HostvCenter'
require 'sunstone/DatastorevCenter'
require 'sunstone/ImagevCenter'

begin
    require 'pry'
rescue LoadError
end

RSpec.describe "vCenter Image test", :type => 'skip' do

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
        @vCenterImage = Sunstone::ImagevCenter.new(@sunstone_test)
        defaults_yaml = File.join(File.dirname(__FILE__), 'defaults_vcenter.yaml')

        begin
            @defaults = YAML.load_file(defaults_yaml)
        rescue Exception => e
            STDERR.puts "Can't load default files: #{e.message}"
            exit -1
        end

        @vCenterHost.import(@defaults[:cluster], @defaults)
        @vCenterDs.import(@defaults[:cluster], @defaults)
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "Import vCenter Image" do
        @vCenterImage.import(@defaults)
    end

    it "Check vCenter Image" do
        xml = cli_action_xml("oneimage list -x") rescue nil
        expect(xml["IMAGE[NAME=\"#{@defaults[:image]}\"]"]).not_to be(nil)
    end

end
