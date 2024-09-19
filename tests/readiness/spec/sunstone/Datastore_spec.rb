require 'init_functionality'
require 'sunstone_test'
require 'sunstone/Datastore'

RSpec.describe "Sunstone datastore tab", :type => 'skip' do

    before(:all) do
        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        @sunstone_test = SunstoneTest.new(@auth)
        @sunstone_test.login
        @ds = Sunstone::Datastore.new(@sunstone_test)
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "should create a datastore" do
        hash = {
            tm: "ssh",
            type: "system"
        }

        @ds.create("test", hash)

        @sunstone_test.wait_resource_create("datastore", "test")
        ds = cli_action_xml("onedatastore show -x test") rescue nil

        expect(ds['TEMPLATE/ALLOW_ORPHANS']).to eql "YES"
        expect(ds['TEMPLATE/TM_MAD']).to eql "ssh"
        expect(ds['TEMPLATE/TYPE']).to eql "SYSTEM_DS"
    end

    it "should check a datastore via UI" do
        hash_info = [
            { key: "TM_MAD", value: "ssh" },
            { key: "Type", value: "SYSTEM" }
        ]

        @ds.check("test", hash_info)
    end

    it "should update a datastore" do
        hash = {
            info: [],
            attrs: [
                { key: "TM_MAD", value: "qcow2" }
            ]
        }

        @ds.update("test", "new_test", hash)

        @sunstone_test.wait_resource_update("datastore", "new_test", { :key=>"TEMPLATE/TM_MAD", :value=>"qcow2" })
        ds = cli_action_xml("onedatastore show -x new_test") rescue nil

        expect(ds['TEMPLATE/TM_MAD']).to eql "qcow2"
    end

    it "should delete a datastore" do
        @ds.delete("new_test")

        @sunstone_test.wait_resource_delete("datastore", "new_test")
        xml = cli_action_xml("onedatastore list -x") rescue nil
        if !xml.nil?
            expect(xml['DATASTORE[NAME="new_test"]']).to be(nil)
        end
    end

    it "should create a datastore in advanced mode" do
        ds_template = <<-EOT
            NAME = test-ds-advanced
            TM_MAD = dummy
            DS_MAD = dummy
        EOT

        @ds.create_advanced(ds_template)

        @sunstone_test.wait_resource_create("datastore", "test-ds-advanced")
        ds = cli_action_xml("onedatastore show -x test-ds-advanced") rescue nil

        expect(ds['TEMPLATE/TM_MAD']).to eql "dummy"
        expect(ds['TEMPLATE/DS_MAD']).to eql "dummy"
    end
end
