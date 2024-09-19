require 'init_functionality'
require 'sunstone_test'
require 'sunstone/Template'
require 'sunstone/VNet'

RSpec.describe "Sunstone vm template tab", :type => 'skip' do

	before(:all) do
		user = @client.one_auth.split(":")
		@auth = {
			:username => user[0],
			:password => user[1]
		}

		@host_id = cli_create("onehost create localhost --im dummy --vm dummy")

		@sunstone_test = SunstoneTest.new(@auth)
		@sunstone_test.login
		@template = Sunstone::Template.new(@sunstone_test)
		@vnet = Sunstone::VNet.new(@sunstone_test)

		vnet = { name: "vnet1", BRIDGE: "br0" }
		ars = [
			{ type: "ip4", ip: "192.168.0.1", size: "100" },
			{ type: "ip4", ip: "192.168.0.2", size: "10" }
		]
		@vnet.create(vnet[:name], vnet, ars)
		@sunstone_test.wait_resource_create("vnet", vnet[:name])
	end

	before(:each) do
		sleep 1
	end

	after(:all) do
		@sunstone_test.sign_out
	end

	it "should create a template with vnets" do
		template = { name: "temp_vnets", mem: "3", cpu: "0.2" }
		if @template.navigate_create(template[:name])
			@template.add_general(template)

			network = { vnet: [ { name: "vnet1", advanced: { virtio_queues: "8" } } ] }
			@template.add_network(network)
			@template.submit
		end

		@sunstone_test.wait_resource_create("template", template[:name])
		tmp_xml = cli_action_xml("onetemplate show -x '#{template[:name]}'") rescue nil

		expect(tmp_xml["TEMPLATE/NIC[NETWORK='#{network[:vnet][0][:name]}']"]).not_to be(nil)
	end

	it "should instantiate a template with vnets" do
		if @template.navigate_instantiate("temp_vnets")
			@template.submit
		end

		@sunstone_test.wait_resource_create("vm", "temp_vnets-0")
		vm_xml = cli_action_xml("onevm show -x temp_vnets-0") rescue nil

		expect(vm_xml['TEMPLATE/NIC[NETWORK="vnet1"]']).not_to be(nil)
		expect(vm_xml['TEMPLATE/NIC/VIRTIO_QUEUES']).to eql "8"
	end
end
