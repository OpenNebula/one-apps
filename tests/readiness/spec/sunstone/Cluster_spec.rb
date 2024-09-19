require 'init_functionality'
require 'sunstone_test'
require 'sunstone/Cluster'

RSpec.describe "Sunstone cluster tab", :type => 'skip' do

    before(:all) do
        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        @sunstone_test = SunstoneTest.new(@auth)
        @cluster = Sunstone::Cluster.new(@sunstone_test)

        vnet = <<-EOF
            NAME   = "test_vnet"
            BRIDGE = br0
            VN_MAD = dummy
            AR = [ TYPE="ETHER", SIZE="128", MAC="00:02:01:02:03:04" ]
        EOF

        @vnet_id = cli_create("onevnet create", vnet)
        @sunstone_test.wait_resource_create("vnet", "test_vnet")

        @ds1_id = cli_create("onedatastore create", "NAME=ds1\nTM_MAD=dummy\nDS_MAD=dummy")
        @sunstone_test.wait_resource_create("datastore", "ds1")

        @ds2_id = cli_create("onedatastore create", "NAME=ds2\nTM_MAD=dummy\nDS_MAD=dummy")
        @sunstone_test.wait_resource_create("datastore", "ds2")
        
        @host_id = cli_create("onehost create test_host -i dummy -v dummy")
        @sunstone_test.wait_resource_create("host", "test_host")
        @sunstone_test.login
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "should create a cluster with resources" do
        hash = {
            hosts: [],
            vnets: ["test_vnet"],
            ds: ["ds1"]
        }

        @cluster.create("test_cluster", hash)
        @sunstone_test.wait_resource_create("cluster", "test_cluster")
    end

    it "should check the resources into cluster via UI" do
        hash = {
            hosts: [],
            vnets: ["test_vnet"],
            ds: ["ds1"]
        }

        @cluster.check("test_cluster", hash)
    end 

    it "should create a cluster with reserved CPU and memory" do
        hash = {
            hosts: ["test_host"],
            vnets: ["test_vnet"],
            ds: ["ds1"]
        }

        @cluster.create("test_cluster_reserved", hash)

        @sunstone_test.wait_resource_create("cluster", "test_cluster_reserved")
        cluster = cli_action_xml("onecluster show -x test_cluster_reserved") rescue nil
        
        expect(cluster["VNETS[ID='#{@vnet_id}']"]).not_to be(nil)
        expect(cluster["DATASTORES[ID='#{@ds1_id}']"]).not_to be(nil)

        hash = {
            reserved_cpu: "20%",
            reserved_mem: "30%",
            hosts: [],
            vnets: [],
            ds: []
        }
        @cluster.update("test_cluster_reserved", hash)

        host = cli_action_xml("onehost show -x test_host") rescue nil
        expect(host["HOST_SHARE/MAX_CPU"]).to eql (host["HOST_SHARE/TOTAL_CPU"].to_i * 0.80).to_i.to_s
        expect(host["HOST_SHARE/MAX_MEM"]).to eql (host["HOST_SHARE/TOTAL_MEM"].to_i * 0.70).to_i.to_s
    end

    it "should update the cluster resources" do
        hash = {
            hosts: [],
            vnets: [],
            ds: ["ds2"]
        }

        @cluster.update("test_cluster", hash)

        @sunstone_test.wait_resource_update("cluster", "test_cluster", { :key=>"DATASTORES/ID", :value=>"#{@ds1_id}#{@ds2_id}" })
        cluster = cli_action_xml("onecluster show -x test_cluster") rescue nil

        expect(cluster["VNETS[ID='#{@vnet_id}']"]).not_to be(nil)
        expect(cluster["DATASTORES[ID='#{@ds1_id}']"]).not_to be(nil)
        expect(cluster["DATASTORES[ID='#{@ds2_id}']"]).not_to be(nil)
    end

    it "should remove the cluster resources" do
        hash = {
            hosts: [],
            vnets: ["test_vnet"],
            ds: ["ds1", "ds2"]
        }

        @cluster.remove_resources("test_cluster", hash)

        @sunstone_test.wait_resource_update("cluster", "test_cluster", { :key=>"DATASTORES", :value=>"" })
        cluster = cli_action_xml("onecluster show -x test_cluster") rescue nil

        expect(cluster["VNETS"]).to eql ""
        expect(cluster["DATASTORES"]).to eql ""
        expect(cluster["HOSTS"]).to eql ""
    end

    it "should delete a cluster" do
        @cluster.delete("test_cluster")

        @sunstone_test.wait_resource_delete("cluster", "test_cluster")
        xml = cli_action_xml("onecluster list -x") rescue nil
        if !xml.nil?
            expect(xml['CLUSTER[NAME="test_cluster"]']).to be(nil)
        end
    end
end
