
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Scheduling requirements tests" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    def build_vnet_template(name, size, extra_attributes)
        template = <<-EOF
            NAME = #{name}
            BRIDGE = br0
            VN_MAD = dummy
            AR=[TYPE = "IP4", IP = "10.0.0.10", SIZE = "#{size}" ]
            #{extra_attributes}
        EOF
    end

    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        ids = []
        5.times { |i|
            ids << cli_create("onehost create host#{i} --im dummy --vm dummy")
            ids << cli_create("onehost create host#{i}.one.org --im dummy --vm dummy")
        }

        ids.each { |i|
            host = Host.new(i)
            host.monitored?
        }

        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update("onedatastore update system", mads, false)
        cli_update("onedatastore update default", mads, false)

        @net_id_1 = cli_create("onevnet create", build_vnet_template("test_vnet", 3, "INBOUND_AVG_BW=1500"))
        @net_id_2 = cli_create("onevnet create", build_vnet_template("test_vnet_2", 1, "INBOUND_AVG_BW=1200"))
        @net_id_3 = cli_create("onevnet create", build_vnet_template("test_vnet_3", 4, "INBOUND_AVG_BW=1600"))

        @cid1 = cli_create("onecluster create cluster1")
        @cid2 = cli_create("onecluster create cluster2")

        cli_action("onecluster addvnet cluster1 #{@net_id_1}")
        cli_action("onecluster addvnet cluster2 #{@net_id_2}")

        @ds1 = cli_create("onedatastore create -c cluster1", "NAME = ds1\nTM_MAD=dummy\nDS_MAD=dummy")
        @ds2 = cli_create("onedatastore create", "NAME = ds2\nTM_MAD=dummy\nDS_MAD=dummy")

        template = <<-EOF
            NAME   = testimage
            TYPE   = OS
            PATH   = #{Tempfile.new('functionality').path}
            ATT1   = VAL1
            ATT2   = VAL2
        EOF

        @iid = cli_create("oneimage create -d ds1", template)

        template = <<-EOF
            NAME   = testimage2
            TYPE   = OS
            PATH   = #{Tempfile.new('functionality').path}
            ATT1   = VAL1
            ATT2   = VAL2
        EOF

        cli_action("onecluster adddatastore cluster2 #{@ds2}")

        @iid2 = cli_create("oneimage create -d ds2", template)
    end

    after(:all) do
        5.times { |i|
            cli_action("onehost delete host#{i}")
            cli_action("onehost delete host#{i}.one.org")
        }
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    it "should check automatic nic requirements" do
        vm_id = cli_create("onevm create --name test --cpu 0.1 --memory 128 --nic test_vnet --hold")
        vm_id_2 = cli_create("onevm create --name test --cpu 0.1 --memory 128 --nic test_vnet_2 --hold")

        xml = cli_action_xml("onevm show #{vm_id} -x")
        xml_2 = cli_action_xml("onevm show #{vm_id_2} -x")

        expect(xml["TEMPLATE/AUTOMATIC_NIC_REQUIREMENTS"]).to eq("(\"CLUSTERS/ID\" @> 0 | \"CLUSTERS/ID\" @> #{@cid1})")
        expect(xml_2["TEMPLATE/AUTOMATIC_NIC_REQUIREMENTS"]).to eq("(\"CLUSTERS/ID\" @> 0 | \"CLUSTERS/ID\" @> #{@cid2})")

        cli_action("onevm terminate #{vm_id}")
        cli_action("onevm terminate #{vm_id_2}")
    end

    it "should check automatic ds requirements" do
        vm_id = cli_create("onevm create --name test --cpu 0.1 --memory 128 --disk testimage --hold")
        vm_id_2 = cli_create("onevm create --name test --cpu 0.1 --memory 128 --disk testimage2 --hold")

        xml = cli_action_xml("onevm show #{vm_id} -x")
        xml_2 = cli_action_xml("onevm show #{vm_id_2} -x")

        expect(xml["TEMPLATE/AUTOMATIC_DS_REQUIREMENTS"]).to eq("(\"CLUSTERS/ID\" @> #{@ds1})")
        expect(xml_2["TEMPLATE/AUTOMATIC_DS_REQUIREMENTS"]).to eq("(\"CLUSTERS/ID\" @> 0 | \"CLUSTERS/ID\" @> #{@ds2})")

        cli_action("onevm terminate #{vm_id}")
        cli_action("onevm terminate #{vm_id_2}")
    end

    it "should check automatic cpu feature requirements" do
        template = <<-EOF
            NAME = testvm
            CPU  = 0.1
            MEMORY = 128
            CPU_MODEL = [
                FEATURES = "vmx,hypervisor"
            ]
        EOF

        vm_id = cli_create("onevm create --hold", template)

        xml = cli_action_xml("onevm show #{vm_id} -x")

        expect(xml["TEMPLATE/AUTOMATIC_REQUIREMENTS"]).to match(/KVM_CPU_FEATURES = \"\*vmx\*\"/) 
        expect(xml["TEMPLATE/AUTOMATIC_REQUIREMENTS"]).to match(/KVM_CPU_FEATURES = \"\*hypervisor\*\"/) 

        cli_action("onevm terminate#{vm_id}")
    end
end

