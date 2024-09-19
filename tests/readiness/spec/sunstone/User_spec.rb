require 'init_functionality'
require 'sunstone_test'
require 'sunstone/User'

RSpec.describe "Sunstone user tab", :type => 'skip' do

    before(:all) do
        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        @sunstone_test = SunstoneTest.new(@auth)

        @gid = cli_create("onegroup create test_group")
        @sunstone_test.wait_resource_create("group", "test_group")

        @iid = cli_create("oneimage create --name test_img --size 100 --type datablock -d default")
        @sunstone_test.wait_resource_create("image", "test_img")

        @vid = cli_create("onevnet create", "NAME = test_vnet\nVN_MAD=dummy\nBRIDGE=vbr0")
        @sunstone_test.wait_resource_create("vnet", "test_vnet")

        @did = cli_create("onedatastore create", "NAME = test_ds\nTM_MAD=dummy\nDS_MAD=dummy")
        @sunstone_test.wait_resource_create("datastore", "test_ds")

        @sunstone_test.login
        @user = Sunstone::User.new(@sunstone_test)
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "should create a normal user" do
        hash = {
            primary: "users",
            secondary: ["users"]
        }
        @user.create_user("test_user_1", hash)

        #Check user created
        @sunstone_test.wait_resource_create("user", "test_user_1")
        user_1 = cli_action_xml("oneuser show -x test_user_1") rescue nil

        expect(user_1["NAME"]).to eql "test_user_1"
        expect(user_1["GNAME"]).to eql "users"
    end

    it "should create another normal user" do
        hash = {
            primary: "test_group",
            secondary: ["users"]
        }
        @user.create_user("test_user_2", hash)

        #Check user created
        @sunstone_test.wait_resource_create("user", "test_user_2")
        user_2 = cli_action_xml("oneuser show -x test_user_2") rescue nil

        expect(user_2["NAME"]).to eql "test_user_2"
        expect(user_2["GNAME"]).to eql "test_group"
        expect(user_2["GROUPS[ID='#{@gid}']"]).not_to be nil
        expect(user_2["GROUPS[ID='1']"]).not_to be nil # users group
    end

    it "should create an admin user" do
        hash = {
            primary: "oneadmin",
            secondary: ["test_group"]
        }

        @user.create_user("test_admin", hash)
        @sunstone_test.wait_resource_create("user", "test_admin")
    end

    it "should check the admin user via Sunstone UI" do
        hash = {
            info: [
                { key: "Name", value: "test_admin" }
            ],
            groups: { primary: "oneadmin", secondary: ["test_group"] }
        }

        @user.check("test_admin", hash)
    end

    it "should update admin user" do
        hash = {
            info: [
                { key: "Table Order", value: "desc" }
            ],
            attr: [
                { key: "test_key", value: "test_value" }
            ],
            groups:   { primary: "test_group", secondary: ["users"] }, # append secondaries
            quotas:   {
                vm:   {
                        vms: 10,
                        running_vms: 4,
                        cpu: 5,
                        running_cpu: 8,
                        mem: 1024,
                        running_mem: 1000,
                        disks: 2048
                    },
                img:  { id: @iid, limits: { rvms_bar: 5 } },
                vnet: { id: @vid, limits: { leases_bar: 10 } },
                ds:   { id: @did, limits: { img_bar: 3, size_bar: 1024 } }
            }
        }

        @user.update("test_admin", hash)

        #Check admin user updated
        @sunstone_test.wait_resource_update("user", "test_admin", { :key=>"TEMPLATE/SUNSTONE/TABLE_ORDER", :value=>"desc" })
        user = cli_action_xml("oneuser show -x test_admin") rescue nil

        expect(user["NAME"]).to eql "test_admin"
        expect(user["GNAME"]).to eql "test_group"
        expect(user["GROUPS[ID='#{@gid}']"]).not_to be nil
        expect(user["GROUPS[ID='1']"]).not_to be nil # users group
        expect(user["GROUPS[ID='0']"]).not_to be nil # oneadmin group
        expect(user["TEMPLATE/SUNSTONE/TABLE_ORDER"]).to eql "desc"
        expect(user["TEMPLATE/TEST_KEY"]).to eql "test_value"

        # quotas
        expect(user["VM_QUOTA/VM/VMS"]).to eql "10"
        expect(user["VM_QUOTA/VM/RUNNING_VMS"]).to eql "4"
        expect(user["VM_QUOTA/VM/CPU"]).to eql "5"
        expect(user["VM_QUOTA/VM/RUNNING_CPU"]).to eql "8"
        expect(user["VM_QUOTA/VM/MEMORY"]).to eql "1024"
        expect(user["VM_QUOTA/VM/RUNNING_MEMORY"]).to eql "1000"
        expect(user["VM_QUOTA/VM/SYSTEM_DISK_SIZE"]).to eql "2048"
        expect(user["IMAGE_QUOTA/IMAGE[ID='#{@iid}']/RVMS"]).to eql "5"
        expect(user["NETWORK_QUOTA/NETWORK[ID='#{@vid}']/LEASES"]).to eql "10"
        expect(user["DATASTORE_QUOTA/DATASTORE[ID='#{@did}']/IMAGES"]).to eql "3"
        expect(user["DATASTORE_QUOTA/DATASTORE[ID='#{@did}']/SIZE"]).to eql "1024"
    end

    it "should delete admin user" do
        @user.delete("test_admin")

        #Check admin user deletion
        @sunstone_test.wait_resource_delete("user", "test_admin")
        xml = cli_action_xml("oneuser list -x") rescue nil
        if !xml.nil?
            expect(xml['USER[NAME="test_admin"]']).to be(nil)
        end
    end

    it 'should disable an user' do
        @user.disable('test_user_1')

        xml = cli_action_xml('oneuser show -x test_user_1') rescue nil
        expect(xml['ENABLED']).to eql '0'
    end

    it 'should enable an user' do
        @user.enable('test_user_1')

        xml = cli_action_xml('oneuser show -x test_user_1') rescue nil
        expect(xml['ENABLED']).to eql '1'
    end


end
