require 'init_functionality'
require 'sunstone_test'
require 'sunstone/Template'
require 'sunstone/Image'
require 'sunstone/Datastore'
require 'sunstone/Vm'

RSpec.describe "Sunstone vm template tab", :type => 'skip' do

	before(:all) do
		user = @client.one_auth.split(":")
		@auth = {
			:username => user[0],
			:password => user[1]
		}

		@sunstone_test = SunstoneTest.new(@auth)
		@sunstone_test.login
		@template = Sunstone::Template.new(@sunstone_test)
		@image = Sunstone::Image.new(@sunstone_test)
		@ds = Sunstone::Datastore.new(@sunstone_test)
		@vm = Sunstone::Vm.new(@sunstone_test)

		image = { name: "test_datablock", type: "DATABLOCK", size: "2" }
		@image.create(image)
		@sunstone_test.wait_resource_create("image", image[:name])

		hash = {tm: "shared",type: "image"}
		@ds.create("ds-shared", hash)
		@sunstone_test.wait_resource_create("datastore", "ds-shared")

		hash = {tm: "ssh",type: "image"}
		@ds.create("ds-ssh", hash)
		@sunstone_test.wait_resource_create("datastore", "ds-ssh")
	end

	before(:each) do
		sleep 1
	end

	after(:all) do
		@sunstone_test.sign_out
	end

	it "should create an LXC template with storage" do
		template = { name: "temp_lxc", mem: "3", cpu: "0.2", hypervisor: "lxc" }

		if @template.navigate_create(template[:name])
			@template.add_general(template)

			storage = {
				image: [ "test_datablock" ],
				volatile: [
					{ size: "2", type: "fs", format: "qcow2" },
					{ size: "4", type: "fs", format: "qcow2" }
				],
				deploy: "ssh"
			}
			@template.add_storage(storage)

			disk = { disk: ['disk0', 'disk1'] }
			@template.add_os(disk)

			@template.submit
		end
  
		#Check LXD template created
		@sunstone_test.wait_resource_create("template", "temp_lxc")
		tmp_xml = cli_action_xml("onetemplate show -x temp_lxc") rescue nil
  
		expect(tmp_xml['TEMPLATE/OS/BOOT']).to eql disk[:disk].join(',')
		expect(tmp_xml['TEMPLATE/OS/ARCH']).to eql nil
		expect(tmp_xml['TEMPLATE/OS/BOOTLOADER']).to eql nil
		expect(tmp_xml['TEMPLATE/OS/KERNEL_CMD']).to eql nil
		expect(tmp_xml['TEMPLATE/OS/ROOT']).to eql nil
		expect(tmp_xml['TEMPLATE/OS/SD_DISK_BUS']).to eql nil
	end

	it "should create a template with storage" do
		template = { name: "temp_storage", mem: "3", cpu: "0.2" }

		if @template.navigate_create(template[:name])
			@template.add_general(template)

			storage = {
				image: [ "test_datablock" ],
				volatile: [
					{ size: "2", size_unit: "GB", type: "fs", format: "qcow2" },
					{ size: "1", size_unit: "GB", type: "fs", format: "qcow2" }
				],
				deploy: "ssh"
			}
			@template.add_storage(storage)

			disk = { disk: ['disk0', 'disk1'] }
			@template.add_os(disk)

			@template.submit
		end

		@sunstone_test.wait_resource_create("template", template[:name])
		tmp_xml = cli_action_xml("onetemplate show -x '#{template[:name]}'") rescue nil

		expect(tmp_xml["TEMPLATE/DISK[IMAGE='#{storage[:image][0]}']"]).not_to be(nil)
		expect(tmp_xml["TEMPLATE/DISK[TYPE='#{storage[:volatile][0][:type]}'][1]/SIZE"]).to eql "2048" # storage[:volatile][0][:size] ** GB
		expect(tmp_xml["TEMPLATE/DISK[TYPE='#{storage[:volatile][0][:type]}'][1]/FORMAT"]).to eql storage[:volatile][0][:format]
		expect(tmp_xml["TEMPLATE/DISK[TYPE='#{storage[:volatile][1][:type]}'][2]/SIZE"]).to eql "1024" # storage[:volatile][1][:size] ** GB
		expect(tmp_xml["TEMPLATE/DISK[TYPE='#{storage[:volatile][1][:type]}'][2]/FORMAT"]).to eql storage[:volatile][1][:format]
		expect(tmp_xml["TEMPLATE/TM_MAD_SYSTEM"]).to eql storage[:deploy]
	end

	it "should create a template with storage in MB" do
		template = { name: "temp_storage_unit_test_mb", mem: "3", cpu: "0.2" }
		if @template.navigate_create(template[:name])
			@template.add_general(template)
			storage = {
				volatile: [{ size: "512", size_unit: "MB", type: "fs", format: "qcow2" }],
				deploy: "ssh"
			}
			@template.add_storage(storage)
			@template.submit
		end

		@sunstone_test.wait_resource_create("template", template[:name])
		tmp_xml = cli_action_xml("onetemplate show -x '#{template[:name]}'") rescue nil

		expect(tmp_xml['TEMPLATE/DISK/SIZE']).to eql "512" # storage[:volatile][0][:size] ** MB
	end

	it "should create a template with storage in GB" do
		template = { name: "storage_unit_test_gb", mem: "3", cpu: "0.2" }
		if @template.navigate_create(template[:name])
			@template.add_general(template)
			storage = {
				volatile: [{ size: "1", size_unit: "GB", type: "fs", format: "qcow2" }],
				deploy: "ssh"
			}
			@template.add_storage(storage)
			@template.submit
		end

		@sunstone_test.wait_resource_create("template", template[:name])
		tmp_xml = cli_action_xml("onetemplate show -x '#{template[:name]}'") rescue nil

		expect(tmp_xml['TEMPLATE/DISK/SIZE']).to eql "1024" # storage[:volatile][0][:size] ** GB
	end

	it "should create a template with storage in TB" do
		template = { name: "storage_unit_test_tb", mem: "3", cpu: "0.2" }
		if @template.navigate_create(template[:name])
			@template.add_general(template)
			storage = {
				volatile: [{ size: "1", size_unit: "TB", type: "fs", format: "qcow2" }],
				deploy: "ssh"
			}
			@template.add_storage(storage)
			@template.submit
		end

		@sunstone_test.wait_resource_create("template", template[:name])
		tmp_xml = cli_action_xml("onetemplate show -x '#{template[:name]}'") rescue nil

		expect(tmp_xml['TEMPLATE/DISK/SIZE']).to eql "1048576" # storage[:volatile][0][:size] ** TB
	end
end
