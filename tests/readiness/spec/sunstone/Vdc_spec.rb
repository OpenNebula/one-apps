require 'init_functionality'
require 'sunstone_test'
require 'sunstone/Vdc'

RSpec.describe "Sunstone VDC tab", :type => 'skip' do

    before(:all) do

        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        @sunstone_test = SunstoneTest.new(@auth)
        @vdc = Sunstone::Vdc.new(@sunstone_test)

        @hid = cli_create("onehost create test_host --im dummy --vm dummy")
        @sunstone_test.wait_resource_create("host", "test_host")

        @gid = cli_create("onegroup create test_group")
        @sunstone_test.wait_resource_create("group", "test_group")

        @cid = cli_create("onecluster create test_cluster")
        @sunstone_test.wait_resource_create("cluster", "test_cluster")

        @vid = cli_create("onevnet create", "NAME = test_vnet\nVN_MAD=dummy\nBRIDGE=vbr0")
        @sunstone_test.wait_resource_create("vnet", "test_vnet")

        @did = cli_create("onedatastore create", "NAME = test_ds\nTM_MAD=dummy\nDS_MAD=dummy")
        @sunstone_test.wait_resource_create("datastore", "test_ds")

        @sunstone_test.login
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "should create a vdc" do
        groups = [ @gid ]

        resources = {
            clusters: [ @cid ],
            hosts: [ @hid ],
            vnets: [ @vid ],
            datastores: [ @did ],
        }

        @vdc.create("test_vdc", groups=groups, resources=resources)

        @sunstone_test.wait_resource_create("vdc", "test_vdc")
        vdc = cli_action_xml("onevdc show -x test_vdc") rescue nil

        expect(vdc["GROUPS[ID='#{@gid}']"]).not_to be nil
        expect(vdc["CLUSTERS/CLUSTER[CLUSTER_ID='#{@cid}']"]).not_to be nil
        expect(vdc["HOSTS/HOST[HOST_ID='#{@hid}']"]).not_to be nil
        expect(vdc["VNETS/VNET[VNET_ID='#{@vid}']"]).not_to be nil
        expect(vdc["DATASTORES/DATASTORE[DATASTORE_ID='#{@did}']"]).not_to be nil
    end

    it "should update a vdc" do
        groups = [ 1 ] # users

        resources = {
            clusters: [ 0 ], # default
            datastores: [ 2 ] # files
        }

        @vdc.update("test_vdc", groups=groups, resources=resources)

        @sunstone_test.wait_resource_update("vdc", "test_vdc", { :key=>"GROUPS/ID", :value=>"1#{@gid}" })
        vdc = cli_action_xml("onevdc show -x test_vdc") rescue nil

        expect(vdc["GROUPS[ID='#{@gid}']"]).not_to be nil
        expect(vdc["GROUPS[ID='1']"]).not_to be nil
        expect(vdc["CLUSTERS/CLUSTER[CLUSTER_ID='#{@cid}']"]).not_to be nil
        expect(vdc["CLUSTERS/CLUSTER[CLUSTER_ID='0']"]).not_to be nil
        expect(vdc["HOSTS/HOST[HOST_ID='#{@hid}']"]).not_to be nil
        expect(vdc["VNETS/VNET[VNET_ID='#{@vid}']"]).not_to be nil
        expect(vdc["DATASTORES/DATASTORE[DATASTORE_ID='#{@did}']"]).not_to be nil
        expect(vdc["DATASTORES/DATASTORE[DATASTORE_ID='2']"]).not_to be nil
    end

    it 'should delete a vdc resource by tag' do
        resources = {
          clusters: {
            element: 'test_cluster', 
            labels: 'selected_ids_row_vdc_clusters_vdc_update_wizard_0',
            tab: 'vdcClustersTab_vdc_update_wizard_0-label'
          },
          hosts: {
            element: 'test_host',
            labels: 'selected_ids_row_vdc_hosts_vdc_update_wizard_0',
            tab: 'vdcHostsTab_vdc_update_wizard_0-label'
          },
          vnets: {
            element: 'test_vnet',
            labels: 'selected_ids_row_vdc_vnets_vdc_update_wizard_0',
            tab: 'vdcVnetsTab_vdc_update_wizard_0-label'
          },
          datastores: {
            element: 'test_ds',
            labels: 'selected_ids_row_vdc_datastores_vdc_update_wizard_0',
            tab: 'vdcDatastoresTab_vdc_update_wizard_0-label'
          },
        }
        @vdc.delete_resources("test_vdc", resources)

        @sunstone_test.wait_resource_update("vdc", "test_vdc", { :key=>"HOSTS/HOST[HOST_ID='#{@hid}']", :value=>nil })
        vdc = cli_action_xml("onevdc show -x test_vdc") rescue nil
        expect(vdc["CLUSTERS/CLUSTER[CLUSTER_ID='#{@cid}']"]).to be nil
        expect(vdc["HOSTS/HOST[HOST_ID='#{@hid}']"]).to be nil
        expect(vdc["VNETS/VNET[VNET_ID='#{@vid}']"]).to be nil
        expect(vdc["DATASTORES/DATASTORE[DATASTORE_ID='#{@did}']"]).to be nil
    end

    it "should delete a vdc" do
        @vdc.delete("test_vdc")

        @sunstone_test.wait_resource_delete("vdc", "test_vdc")
        xml = cli_action_xml("onevdc list -x") rescue nil
        if !xml.nil?
            expect(xml['VDC[NAME="test_vdc"]']).to be(nil)
        end
    end

    it 'should create a vdc in advanced mode' do
        vdc_template = <<-EOF
            NAME = "test-vdc-advanced"
            GROUPS = 1
            CLUSTERS = 0
        EOF

        @vdc.create_advanced(vdc_template)

        @sunstone_test.wait_resource_create("vdc", "test-vdc-advanced")
        vnet = cli_action_xml('onevdc show -x test-vdc-advanced') rescue nil
        expect(vnet['NAME']).to eql 'test-vdc-advanced'
        expect(vnet['TEMPLATE/GROUPS']).to eql '1'
        expect(vnet['TEMPLATE/CLUSTERS']).to eql '0'
    end
end
