require 'init_functionality'
require 'sunstone_test'
require 'sunstone/Host'

RSpec.describe "Sunstone host tab", :type => 'skip' do

    before(:all) do
        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        @sunstone_test = SunstoneTest.new(@auth)
        @host = Sunstone::Host.new(@sunstone_test)

        @cid1 = cli_create("onecluster create test_cluster")
        @sunstone_test.wait_resource_create("cluster", "test_cluster")

        @sunstone_test.login
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "should create a KVM host" do
        hash = { name: "test_kvm", type: "custom", vmmad: "kvm", immad: "kvm" }

        @host.create(hash)
        @sunstone_test.wait_resource_create("host", "test_kvm")
    end

    it "should check a KVM host via UI" do
        arr = [
            { key: "IM MAD", value: "kvm" },
            { key: "VM MAD", value: "kvm" }
        ]

        @host.check("test_kvm", arr)
    end

    it "should create a dummy host" do
        hash = { name: "test_dummy", type: "custom", vmmad: "dummy", immad: "dummy"}

        @host.create(hash)
        @sunstone_test.wait_resource_create("host", "test_dummy")
    end

    it "should check a dummy host via UI" do
        arr = [
            { key: "IM MAD", value: "dummy" },
            { key: "VM MAD", value: "dummy" }
        ]

        @host.check("test_dummy", arr)
    end

    it "should update a dummy host" do
        hash = { cluster: "test_cluster", max_cpu: "30", max_mem: "13GB" }
        @host.update("test_dummy", "test_dummy_2", hash)

        @sunstone_test.wait_resource_update("host", "test_dummy_2", { :key=>"IM_MAD", :value=>"dummy" })
        host = cli_action_xml("onehost show -x test_dummy_2") rescue nil
        expect(@host.validate_max_CPU(host["HOST_SHARE/MAX_CPU"])).to be true
        expect(host["HOST_SHARE/MAX_MEM"].to_i/(1024**2)).to eql hash[:max_mem].to_i
        expect(host["IM_MAD"]).to eql "dummy"
        expect(host["VM_MAD"]).to eql "dummy"
        expect(host["CLUSTER_ID"]).to eql @cid1.to_s
        expect(host["TEMPLATE/HYPERVISOR"]).to eql "dummy"
    end

    it "should delete a hosts" do
        @host.delete("test_dummy_2")

        @sunstone_test.wait_resource_delete("host", "test_dummy_2")
        xml = cli_action_xml("onehost list -x") rescue nil
        if !xml.nil?
            expect(xml['HOST[NAME="test_dummy_2"]']).to be(nil)
        end
    end
end
