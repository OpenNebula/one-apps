require 'init_functionality'
require 'flow_helper'
require 'sunstone_test'
require 'sunstone/App'
require 'sunstone/Datastore'
require 'sunstone/Marketplace'
require 'sunstone/Vm'
require 'sunstone/Template'

RSpec.describe "Sunstone apps tab", :type => 'skip' do
    include FlowHelper

    def deploy_vm(name: "", template: "")
        template_id = create_template(:template => template)
        vm_id = cli_create("onetemplate instantiate #{template_id} --name #{name}")
        cli_action("onevm deploy #{vm_id} #{@host_id}")

        vm = VM.new(vm_id)
        vm.running?

        return vm
	end

    def create_template(template: "")
        template_id = cli_create("onetemplate create", template)
    end

    def build_vm_template(name: "", networks: [], graphics: "VNC", extra_attributes: "")
        template = <<-EOF
            NAME = #{name}
            CPU = 1
            MEMORY = 128
            GRAPHICS = [ LISTEN="0.0.0.0", TYPE=#{graphics} ]
            #{extra_attributes}
        EOF

        networks.each_with_index { |nic, index|
            nic = { :rdp => "NO", :ssh => "NO", :nic_alias => false }.merge!(nic)
            nic_index = "NIC#{index}"

            template << "NIC = [ NAME=#{nic_index}, NETWORK=#{nic[:name]}, \
                RDP=#{nic[:rdp]}, SSH=#{nic[:ssh]}]"

            template << "NIC_ALIAS = [ NETWORK=#{nic[:name]}, PARENT=#{nic_index}, \
                RDP=YES, SSH=YES ]" if nic[:nic_alias]
        }

        template
    end

    def wait_image_ready(img)
        wait_loop(:success => 'READY', :break => 'ERROR') do
            xml = cli_action_xml("oneimage show -x '#{img}'")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        end
    end

    before(:all) do
        start_flow

        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1],
        }

        @ubuntu_app = 'Ubuntu 20.04'
        @alpine_app = 'Alpine Linux 3.17'

        @sunstone_test = SunstoneTest.new(@auth)
        
        @app = Sunstone::App.new(@sunstone_test)
        @ds = Sunstone::Datastore.new(@sunstone_test)
        @marketplace = Sunstone::Marketplace.new(@sunstone_test)

        # -----------------------------------------
        # BEFORE LOGIN - create resources by CLI
        # -----------------------------------------

        # Create dummy host
        @host_id = cli_create('onehost create localhost -i dummy -v dummy')
        @host = Host.new(@host_id)
        @host.monitored?

        # Create datablock image
        img_name = "test_img"
        @img_id = cli_create("oneimage create --name #{img_name} --size 100 --type datablock -d default")

        wait_image_ready(img_name)

        # Create vm with datablock image
        @vm = deploy_vm(
            :name => "test_vm",
            :template => build_vm_template(
                :name => "test_import_app",
                :extra_attributes => "DISK = [ IMAGE=\"#{img_name}\", IMAGE_UNAME=\"oneadmin\"]"
            )
        )
        @vm.safe_poweroff

        # Create the template
        template_name = 'test_template'
        @template_id = create_template(:template => build_vm_template(name: template_name))
        @sunstone_test.wait_resource_create("template", "test_template")

        # Create Service template (default name => TEST)
        flow_template = service_template('none', false, true)
        @flow_template_id = cli_create('oneflow-template create', flow_template)
        @sunstone_test.wait_resource_create('flow-template', 'TEST')

        # -----------------------------------------

        @sunstone_test.login

        @ds_name = 'ds_apps'
        hash = { tm: 'dummy', type: 'image' }
        @ds.create(@ds_name, hash)
        @sunstone_test.wait_resource_create('datastore', @ds_name)

        # Create a private marketplace
        hash = {
            description: 'HTTP Server marketplace',
            market_mad: 'http',
            base_url: 'http://frontend.opennebula.org/',
            public_dir: '/var/local/market-http'
        }
        @marketplace.create('http_mktplc', hash)
        @sunstone_test.wait_resource_create('market', 'http_mktplc')

        mktplc = cli_action_xml('onemarket show -x http_mktplc') rescue nil
        @mpId = mktplc['ID']
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        stop_flow
        @sunstone_test.sign_out
    end

    it "should download an app" do
        hash = {
            app_name: @ubuntu_app,
            ds_name: @ds_name
        }

        @app.download(hash)

        @sunstone_test.wait_resource_create('template', hash[:app_name])
        @sunstone_test.wait_resource_create('image', hash[:app_name])

        template = cli_action_json("onetemplate show '#{hash[:app_name]}' -j")
        expect(template).not_to be_nil

        image = cli_action_json("oneimage show '#{hash[:app_name]}' -j")
        expect(image).not_to be_nil
    end

    it "should download another app without templates/images" do
        hash = {
            app_name: @alpine_app,
            ds_name: @ds_name,
            no_template: true
        }

        @app.download(hash)

        @sunstone_test.wait_resource_create('image', hash[:app_name])

        image = cli_action_json("oneimage show '#{hash[:app_name]}' -j")
        expect(image).not_to be_nil

        template = cli_action_json("onetemplate show '#{hash[:app_name]}' -j", false) rescue nil
        expect(template).to be_nil
    end

    it "should update an app" do
        hash = [
            { key: 'test_key', value: 'test_value' }
        ]
        @app.update(@ubuntu_app, nil, hash)

        @sunstone_test.wait_resource_update(
            'marketapp',
            @ubuntu_app, 
            {
                :key=>"TEMPLATE/#{hash[0][:key].upcase}",
                :value=> hash[0][:value]
            }
        )
    end

    it "should delete an app" do
        @app.delete(@ubuntu_app)
    end

    it "should import a poweroff VM" do
        # Create the app
        hash = {
            :type => 'vm',
            :name => 'testVMapp',
            :importImages => false,
            :vmId => @vm.id,
            :mpId => @mpId
        }

        @app.create(hash)

        @sunstone_test.wait_resource_create('marketapp', hash[:name])

        template_saved = cli_action_xml("onetemplate show -x '#{hash[:name]}'") rescue nil
        expect(template_saved['NAME']).to eql hash[:name]

        app = cli_action_xml("onemarketapp show -x #{hash[:name]}") rescue nil
        expect(app['NAME']).to eql hash[:name]
    end

    it "should import a VM Template" do
        # Create the app
        hash = {
            :type => 'vmtemplate',
            :name => 'testVMTemplateApp',
            :importImages => false,
            :vmTemplateId => @template_id,
            :mpId => @mpId
        }

        @app.create(hash)

        @sunstone_test.wait_resource_create('marketapp', hash[:name])

        app = cli_action_xml("onemarketapp show -x #{hash[:name]}") rescue nil
        expect(app['NAME']).to eql hash[:name]
    end

    it "should import a Service Template" do
        # Create the app
        hash = {
            :type => 'service_template',
            :name => 'testServiceTemplateApp',
            :importImages => false,
            :serviceId => @flow_template_id,
            :mpId => @mpId
        }

        @app.create(hash)

        @sunstone_test.wait_resource_create('marketapp', hash[:name])

        app = cli_action_xml("onemarketapp show -x #{hash[:name]}") rescue nil
        expect(app['NAME']).to eql hash[:name]
    end

end
