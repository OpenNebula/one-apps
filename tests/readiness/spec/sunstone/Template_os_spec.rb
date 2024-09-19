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
	end

	before(:each) do
		sleep 1
	end

	after(:all) do
		@sunstone_test.sign_out
	end

	it 'should create a template with IOTHREADS' do
        template = {
            :name => 'temp_storage_iothreads',
            :mem => '1',
            :cpu => '0.2'
        }

        if @template.navigate_create(template[:name])
            @template.add_general(template)
            os = {
                :features => {
                    :iothreads => '32'
                }
            }
            @template.add_os(os)

            storage ={
                :volatile => [
                    {
                        :size => '100',
                        :size_unit => 'MB',
                        :type => 'fs',
                        :format => 'qcow2',
                        :advanced => {
                            :iothread => '4'
                        }
                    }
                ],
                :deploy => 'ssh'
            }
            @template.add_storage(storage)
            @template.submit
        end

        @sunstone_test.wait_resource_create("template", template[:name])
		tmp_xml = cli_action_xml("onetemplate show -x '#{template[:name]}'") rescue nil

		expect(tmp_xml['TEMPLATE/DISK/IOTHREAD']).to eql "4"
		expect(tmp_xml['TEMPLATE/FEATURES/IOTHREADS']).to eql "32"
	end

	it "should instantiate a template with booting changes" do
		hash = { name: 'vm_storage', os: ['disk2', 'disk0'] }

		@vm.navigate_instantiate("temp_storage")
		@vm.instantiate(hash)
		
		@sunstone_test.wait_resource_create("vm", hash[:name])
		xml_vm = cli_action_xml("onevm show -x '#{hash[:name]}'") rescue nil

		expect(xml_vm['TEMPLATE/OS/BOOT']).to eql hash[:os].join(',')
	end

end
