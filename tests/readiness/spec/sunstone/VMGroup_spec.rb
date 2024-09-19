require 'init_functionality'
require 'sunstone_test'
require 'sunstone/VMGroup'

RSpec.describe "Sunstone vm group tab", :type => 'skip' do

    before(:all) do
        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        @sunstone_test = SunstoneTest.new(@auth)
        @sunstone_test.login
        @vmgrp = Sunstone::VMGroup.new(@sunstone_test)
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "should create a vm group" do
        hash_roles = {
            roles: [
                { name: "a", affinity: "NONE", hosts: ["30", "28"] },
                { name: "b", affinity: "NONE", hosts: ["27"] },
                { name: "c", affinity: "NONE", hosts: ["25"] },
                { name: "d", affinity: "AFFINED", hosts: ["26"] }
            ]
        }

        roles_affinity = [["b","d"]]
        roles_anti_affinity = [["a","c"]]

        @vmgrp.create("test", hash_roles, roles_affinity, roles_anti_affinity)
        @sunstone_test.wait_resource_create("vmgroup", "test")
    end

    it "should check a vm group via UI" do
        hash = {
            roles: [
                { name: "a", affinity: "NONE", hosts: [] },
                { name: "b", affinity: "NONE", hosts: [] },
                { name: "c", affinity: "NONE", hosts: [] },
                { name: "d", affinity: "AFFINED", hosts: [] }
            ]
        }

        roles_affinity = [["b","d"]]
        roles_anti_affinity = [["a","c"]]

        @vmgrp.check("test", hash, roles_affinity, roles_anti_affinity)
    end

    it "should update a vm group" do
        roles_affinity = [["a","d"]]
        roles_anti_affinity = [["b","c"]]

        @vmgrp.update("test", roles_affinity, roles_anti_affinity)

        @sunstone_test.wait_resource_update("vmgroup", "test", { :key=>"TEMPLATE/AFFINED", :value=>"a,d" })
        vmg = cli_action_xml("onevmgroup show -x test") rescue nil
    
        expect(vmg['TEMPLATE/AFFINED']).to eql "a,d"
        expect(vmg['TEMPLATE/ANTI_AFFINED']).to eql "b,c"
        expect(vmg['ROLES/ROLE[NAME="a"]/POLICY']).to eql "NONE"
        expect(vmg['ROLES/ROLE[NAME="b"]/POLICY']).to eql "NONE"
        expect(vmg['ROLES/ROLE[NAME="c"]/POLICY']).to eql "NONE"
        expect(vmg['ROLES/ROLE[NAME="d"]/POLICY']).to eql "AFFINED"
    end

    it "should delete a vm group" do
        @vmgrp.delete("test")

        @sunstone_test.wait_resource_delete("vmgroup", "test")
        xml = cli_action_xml("onevmgroup list -x") rescue nil
        if !xml.nil?
            expect(xml['VMGROUP[NAME="test"]']).to be(nil)
        end
    end

    it "should create a vm group in advanced mode" do
        vmg_template = <<-EOT
            NAME         = "test-vmgroup-advanced"
            ROLE         = [ NAME = web ]
            ROLE         = [ NAME = db  ]
            ROLE         = [ NAME = app  ]
            AFFINED      = "web"
            ANTI_AFFINED = "app"
        EOT

        @vmgrp.create_advanced(vmg_template)

        @sunstone_test.wait_resource_create("vmgroup", "test-vmgroup-advanced")
        vmgroup = cli_action_xml("onevmgroup show -x test-vmgroup-advanced") rescue nil
        expect(vmgroup['TEMPLATE/AFFINED']).to eql "web"
        expect(vmgroup['TEMPLATE/ANTI_AFFINED']).to eql "app"
    end

end
