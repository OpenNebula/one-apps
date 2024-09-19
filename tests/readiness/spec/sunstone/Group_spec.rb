require 'init_functionality'
require 'sunstone_test'
require 'sunstone/Group'

RSpec.describe "Sunstone group tab", :type => 'skip' do

    before(:all) do
        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        @sunstone_test = SunstoneTest.new(@auth)
        @sunstone_test.login
        @group = Sunstone::Group.new(@sunstone_test)
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "should create a group" do
        # Possible 'layout' configuration:
        # view_cloud view_groupadmin admin_view_cloud admin_view_groupadmin view_user view_admin admin_view_user admin_view_admin
        hash = {
            views: {
                dafault_user:   "user",
                dafault_admin:  "cloud",
                layout:         [
                                  "view_cloud",
                                  "admin_view_cloud",
                                  "admin_view_groupadmin",
                                  "view_user"
                                ]
            }
        }

        @group.create("test_group", hash)

        @sunstone_test.wait_resource_create("group", "test_group")
        group = cli_action_xml("onegroup show -x test_group") rescue nil

        expect(group["TEMPLATE/SUNSTONE/DEFAULT_VIEW"]).to eql "user"
        expect(group["TEMPLATE/SUNSTONE/GROUP_ADMIN_DEFAULT_VIEW"]).to eql "cloud"
        expect(group["TEMPLATE/SUNSTONE/VIEWS"].split(",")).to include "cloud", "user"
        expect(group["TEMPLATE/SUNSTONE/GROUP_ADMIN_VIEWS"].split(",")).to include "cloud", "groupadmin"
    end

    it "should update a group" do
        hash = {
            views: {
                dafault_user:   "cloud",
                dafault_admin:  "groupadmin",
                layout:         [
                                  "view_cloud",
                                  "view_groupadmin"
                                ]
            }
        }

        @group.update("test_group", hash)

        @sunstone_test.wait_resource_update("group", "test_group", { :key=>"TEMPLATE/SUNSTONE/DEFAULT_VIEW", :value=>"cloud" })
        group = cli_action_xml("onegroup show -x test_group") rescue nil

        expect(group["TEMPLATE/SUNSTONE/DEFAULT_VIEW"]).to eql "cloud"
        expect(group["TEMPLATE/SUNSTONE/GROUP_ADMIN_DEFAULT_VIEW"]).to eql "groupadmin"
        expect(group["TEMPLATE/SUNSTONE/VIEWS"].split(",")).to include "cloud", "user", "groupadmin"
        expect(group["TEMPLATE/SUNSTONE/GROUP_ADMIN_VIEWS"].split(",")).to include "cloud", "groupadmin"
    end

    it "should delete a group" do
        @group.delete("test_group")

        @sunstone_test.wait_resource_delete("group", "test_group")
        xml = cli_action_xml("onegroup list -x") rescue nil
        if !xml.nil?
            expect(xml['GROUP[NAME="test_group"]']).to be(nil)
        end
    end
end
