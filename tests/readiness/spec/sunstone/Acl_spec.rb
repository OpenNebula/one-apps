require 'init_functionality'
require 'sunstone_test'
require 'sunstone/Acl'

RSpec.describe "Sunstone ACL tab", :type => 'skip' do

    before(:all) do
        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        @sunstone_test = SunstoneTest.new(@auth)
        @acl = Sunstone::Acl.new(@sunstone_test)

        @uid = cli_create("oneuser create test_user test_user")
        @sunstone_test.wait_resource_create("user", "test_user")

        @gid = cli_create("onegroup create test_group")
        @sunstone_test.wait_resource_create("group", "test_group")

        @USER_ACL = / *\d+ *##{@uid} *---I-T------------ *@#{@gid} *--a-/
        @GROUP_ACL = / *\d+ *@#{@gid} *-HN----D---------- *%0 *---c *#0/
        
        @sunstone_test.login
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "should create an acl user" do
        hash = {
            zone: "*", # all
            resources: ["template", "image"],
            subset: "group", # "all", "id", "group" or "cluster"
            operations: ["manage"] # "delete", "manage", "use" or "create"
        }

        # 0: "user" or "group"
        # 1: id
        apply = ["user", @uid]

        # 0: "id", "belonging_to" or "in_cluster"
        # 1: id
        subset = ["belonging_to", @gid]

        @acl.refresh_users()
        @acl.create("id", hash, apply, subset)

        expect(cli_action("oneacl list").stdout).to match(@USER_ACL)
    end

    it "should create an acl group" do
        hash = {
            zone: "0", # zone id
            resources: ["datastore", "host", "net"],
            subset: "cluster", # "all", "id", "group" or "cluster"
            operations: ["create"] # "delete", "manage", "use" or "create"
        }

        # 0: "user" or "group"
        # 1: id
        apply = ["group", @gid]

        # 0: "id", "belonging_to" or "in_cluster"
        # 1: id
        subset = ["in_cluster", "0"]

        @acl.create("group", hash, apply, subset)

        expect(cli_action("oneacl list").stdout).to match(@GROUP_ACL)
    end

    it "should delete acl user and group" do
        @acl.delete_by_id("10") # user acl
        @acl.delete_by_id("11") # group acl

        expect(cli_action("oneacl list").stdout).not_to match(@USER_ACL)
        expect(cli_action("oneacl list").stdout).not_to match(@GROUP_ACL)
    end
end
