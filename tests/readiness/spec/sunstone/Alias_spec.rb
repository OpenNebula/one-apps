require 'init_functionality'
require 'sunstone_test'
require 'sunstone/Template'
require 'sunstone/VNet'
require 'sunstone/Vm'

RSpec.describe "Sunstone vm templates tab", :type => 'skip' do

    before(:all) do
        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        @sunstone_test = SunstoneTest.new(@auth)
        @template = Sunstone::Template.new(@sunstone_test)
        @vm = Sunstone::Vm.new(@sunstone_test)
        @vnet = Sunstone::VNet.new(@sunstone_test)

        @sunstone_test.login
        @template_name = "temp_alias"
        @vnet_name = "alias_vnet"

        hash = { BRIDGE: "br0" }
        ars = [
            { type: "ip4", ip: "192.168.0.1", size: "100" }
        ]

        @vnet.create(@vnet_name, hash, ars)
        @sunstone_test.wait_resource_create("vnet", @vnet_name)
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "should create template" do
        hash = { name: @template_name, mem: "3", cpu: "0.2" }

        if @template.navigate_create(@template_name)
            @template.add_general(hash)
            @template.submit
        end

        @sunstone_test.wait_resource_create("template", @template_name)
    end

    it "should update a template with 2 NICS and 1 NIC alias" do
        @template.navigate_update(@template_name)
        hash = {
            vnet: [
                @vnet_name,
                @vnet_name,
                { :name => @vnet_name, :alias => "NIC0" }
            ]
        }
        @template.add_network(hash)
        @template.submit

        @sunstone_test.wait_resource_update("template", @template_name, { :key=>'TEMPLATE/NIC_ALIAS/NETWORK', :value=>@vnet_name })
        tmp = cli_action_xml("onetemplate show -x #{@template_name}") rescue nil

        expect(tmp['TEMPLATE/NIC_ALIAS/NETWORK']).to eq(@vnet_name)
        expect(tmp['TEMPLATE/NIC_ALIAS/PARENT']).to eq('NIC0')
    end

    it "should instantiate a template with 2 NICS and 1 NIC alias" do
        @vm.navigate_instantiate(@template_name)
        @vm.instantiate({:name => "alias_vm"})

        @sunstone_test.wait_resource_create("vm", "alias_vm")
        tmp = cli_action_xml("onevm show -x alias_vm") rescue nil

        expect(tmp['TEMPLATE/NIC[NIC_ID=0]/NETWORK']).to eq(@vnet_name)
        expect(tmp['TEMPLATE/NIC[NIC_ID=0]/NAME']).to eq('NIC0')
        expect(tmp['TEMPLATE/NIC[NIC_ID=0]/ALIAS_IDS']).to eq('2')

        expect(tmp['TEMPLATE/NIC[NIC_ID=1]/NETWORK']).to eq(@vnet_name)
        expect(tmp['TEMPLATE/NIC[NIC_ID=1]/NAME']).to eq('NIC1')
        expect(tmp['TEMPLATE/NIC[NIC_ID=1]/ALIAS_IDS']).to eq(nil)

        expect(tmp['TEMPLATE/NIC_ALIAS[NIC_ID=2]/NETWORK']).to eq(@vnet_name)
        expect(tmp['TEMPLATE/NIC_ALIAS[NIC_ID=2]/NAME']).to eq('NIC0_ALIAS2')
        expect(tmp['TEMPLATE/NIC_ALIAS[NIC_ID=2]/PARENT']).to eq('NIC0')
    end

    it "should add 1 NIC alias more before instantiate a template" do
        @vm.navigate_instantiate(@template_name)

        @vm.add_network({ vnet: [
            { :name => @vnet_name, :alias => "NIC1" }
        ]}, 3)

        @vm.instantiate({ :name => "alias_vm_2" })

        @sunstone_test.wait_resource_create("vm", "alias_vm_2")
        tmp = cli_action_xml("onevm show -x alias_vm_2") rescue nil

        expect(tmp['TEMPLATE/NIC[NIC_ID=0]/NETWORK']).to eq(@vnet_name)
        expect(tmp['TEMPLATE/NIC[NIC_ID=0]/NAME']).to eq('NIC0')
        expect(tmp['TEMPLATE/NIC[NIC_ID=0]/ALIAS_IDS']).to eq('2')

        expect(tmp['TEMPLATE/NIC[NIC_ID=1]/NETWORK']).to eq(@vnet_name)
        expect(tmp['TEMPLATE/NIC[NIC_ID=1]/NAME']).to eq('NIC1')
        expect(tmp['TEMPLATE/NIC[NIC_ID=1]/ALIAS_IDS']).to eq('3')

        expect(tmp['TEMPLATE/NIC_ALIAS[NIC_ID=2]/NETWORK']).to eq(@vnet_name)
        expect(tmp['TEMPLATE/NIC_ALIAS[NIC_ID=2]/NAME']).to eq('NIC0_ALIAS2')
        expect(tmp['TEMPLATE/NIC_ALIAS[NIC_ID=2]/PARENT']).to eq('NIC0')

        expect(tmp['TEMPLATE/NIC_ALIAS[NIC_ID=3]/NETWORK']).to eq(@vnet_name)
        expect(tmp['TEMPLATE/NIC_ALIAS[NIC_ID=3]/NAME']).to eq('NIC1_ALIAS3')
        expect(tmp['TEMPLATE/NIC_ALIAS[NIC_ID=3]/PARENT']).to eq('NIC1')
    end

    it "should create a template in advanced mode with 2 NICS and 1 NIC Alias" do
        template = <<-EOT
            NAME   = alias-template-advanced
            CPU    = 2
            VCPU   = 1
            MEMORY = 128
            NIC=[
                NETWORK="#{@vnet_name}" ]
            NIC=[
                NETWORK="#{@vnet_name}" ]
            NIC_ALIAS=[
                NETWORK="#{@vnet_name}",
                PARENT="NIC0" ]
        EOT

        @template.create_advanced(template)

        @sunstone_test.wait_resource_create("template", "alias-template-advanced")
        tmp = cli_action_xml("onetemplate show -x alias-template-advanced") rescue nil

        expect(tmp['TEMPLATE/NIC_ALIAS/NETWORK']).to eq(@vnet_name)
        expect(tmp['TEMPLATE/NIC_ALIAS/PARENT']).to eq('NIC0')
    end
end
