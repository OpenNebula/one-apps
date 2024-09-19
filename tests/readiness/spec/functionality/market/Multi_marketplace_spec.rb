require 'init_functionality'
require 'flow_helper'

require 'webrick'

# Marketplace apps types
TYPES = %w[UNKNOWN IMAGE VMTEMPLATE SERVICE_TEMPLATE]

RSpec.describe 'MarketPlace multi VMs operations test' do
    include FlowHelper

    prepend_before(:all) do
        @defaults_yaml = File.realpath(
            File.join(File.dirname(__FILE__), 'defaults.yaml')
        )
    end

    before(:all) do
        start_flow

        market = File.expand_path '/var/tmp/'

        @info       = {}
        @info[:web] = Thread.new do
            @info[:server] = WEBrick::HTTPServer.new(
                :Port         => 8888,
                :DocumentRoot => market
            )

            @info[:server].start
        end

        # Create martketplace
        @market_template = <<-EOF
            NAME       = testmarket
            MARKET_MAD = http
            BASE_URL   = "http://localhost:8888"
            PUBLIC_DIR = "/var/tmp"
        EOF

        @mp_id = cli_create('onemarket create', @market_template)

        wait_loop do
            xml = cli_action_xml('onemarket show 0 -x')
            xml.retrieve_elements('//MARKETPLACEAPPS').size.to_i > 0
        end

        # Update datastores
        cli_update('onedatastore update system', 'TM_MAD=dummy', false)
        cli_update('onedatastore update default', 'TM_MAD=dummy', false)

        wait_loop do
            xml = cli_action_xml('onedatastore show -x 1')
            xml['FREE_MB'].to_i > 0
        end

        # Create Image
        @image_id = cli_create('oneimage create -d default --name test --size 1')

        # Create VM template
        template = vm_template

        template_file = Tempfile.new('vm_template')
        template_file << template
        template_file.close

        @v_template_id = cli_create("onetemplate create #{template_file.path}")

        # Create Service template
        template = service_template('none')

        template_file = Tempfile.new('service_template')
        template_file << template
        template_file.close

        @s_template_id = cli_create(
            "oneflow-template create #{template_file.path}"
        )

        # App IDs to export in each test
        @app_ids = []
    end

    ############################################################################
    # Simple VM template TYPE=VMTEMPLATE
    ############################################################################

    it 'should import a simple VM template into marketplace' do
        cmd = cli_action(
            "onemarketapp vm-template import \
            #{@v_template_id} \
            --yes \
            --market #{@mp_id}"
        )

        id  = cmd.stdout.match(/ID: (.*?)$/)[1]
        app = nil

        wait_loop do
            app = cli_action_xml("onemarketapp show #{id} -x")
            app['/MARKETPLACEAPP/STATE'] == '1'
        end

        expect(app['/MARKETPLACEAPP/APPTEMPLATE64']).not_to be_nil
        expect(app['/MARKETPLACEAPP/STATE']).to eq('1')
        expect(TYPES[app['/MARKETPLACEAPP/TYPE'].to_i]).to eq('VMTEMPLATE')
        expect(app['/MARKETPLACEAPP/TEMPLATE/VMTEMPLATE64']).to be_nil
    end

    it 'should export a simple VM template from marketplace' do
        wait_app_ready(60, "'Custom via netboot.xyz'")

        app = cli_action(
            "onemarketapp export 'Custom via netboot.xyz' TESTING -d 1"
        ).stdout

        app.gsub!("\n", '')
        app.gsub!(' ', '')

        expect(app.include?('IMAGE')).to eq(true)
        expect(app.include?('SERVICE_TEMPLATE')).to eq(false)
        expect(app.include?('VMTEMPLATEID')).to eq(true)
    end

    ############################################################################
    # Complex VM template TYPE=TEMPLATE
    #
    # Note: this tests also applies when importing a VM, because the same logic
    # is used. The only difference is the save_as_template which is tested
    # in other parts of the tests.
    ############################################################################
    it 'should import a complex VM template into marketplace' do
        # Update the template to add the image
        new_template = cli_create("onetemplate clone #{@v_template_id} T1")

        cli_update("onetemplate update #{new_template}",
                   "DISK=[IMAGE_ID='#{@image_id}' ]",
                   true)

        cmd = cli_action(
            "onemarketapp vm-template import \
            #{new_template} \
            --yes \
            --market #{@mp_id}"
        )

        ids = cmd.stdout.split("\n")

        # First app is the image, second is the VM template
        ids.map! {|id| id.match(/ID: (.*?)$/)[1] }

        @app_ids << ids[0]
        @app_ids << ids[1]

        image    = nil
        template = nil

        wait_loop do
            image = cli_action_xml("onemarketapp show #{@app_ids[0]} -x")
            image['/MARKETPLACEAPP/STATE'] == '1'
        end
        wait_loop do
            template = cli_action_xml("onemarketapp show #{@app_ids[1]} -x")
            template['/MARKETPLACEAPP/STATE'] == '1'
        end

        expect(image['/MARKETPLACEAPP/APPTEMPLATE64']).not_to eq('')
        expect(image['/MARKETPLACEAPP/STATE']).to eq('1')
        expect(TYPES[image['/MARKETPLACEAPP/TYPE'].to_i]).to eq('IMAGE')
        expect(image['/MARKETPLACEAPP/TEMPLATE/VMTEMPLATE64']).to be_nil

        expect(template['/MARKETPLACEAPP/APPTEMPLATE64']).not_to be_nil
        expect(template['/MARKETPLACEAPP/STATE']).to eq('1')
        expect(TYPES[template['/MARKETPLACEAPP/TYPE'].to_i]).to eq('VMTEMPLATE')
    end

    it 'should export an image from marketplace' do
        app = cli_action("onemarketapp export #{@app_ids.shift} TESTING_2 -d 1").stdout

        app.gsub!("\n", '')
        app.gsub!(' ', '')

        expect(app.include?('IMAGE')).to eq(true)
        expect(app.include?('SERVICE_TEMPLATE')).to eq(false)
        expect(app.include?('VMTEMPLATEID')).to eq(false)
    end

    it 'should export a complex VM template from marketplace' do
        app = cli_action("onemarketapp export #{@app_ids[0]} TESTING_1 -d 1").stdout

        app.gsub!("\n", '')
        app.gsub!(' ', '')

        expect(app.include?('IMAGE')).to eq(true)
        expect(app.include?('SERVICE_TEMPLATE')).to eq(false)
        expect(app.include?('VMTEMPLATEID')).to eq(true)
    end

    it 'should fail exporting a complex VM template that already exists' do
        cli_action("onemarketapp export #{@app_ids.shift} TESTING_1 -d 1", false)
    end

    it 'should import a VM with a NIC' do
        # Update the template to add the image
        new_template = cli_create("onetemplate clone #{@v_template_id} T_NIC")

        cli_update("onetemplate update #{new_template}",
                   'NIC=[NETWORK_ID=\'1\' ]',
                   true)

        cmd = cli_action(
            "onemarketapp vm-template import \
            #{new_template} \
            --yes \
            --market #{@mp_id}"
        )

        id  = cmd.stdout.match(/ID: (.*?)$/)[1]
        app = nil

        wait_loop do
            app = cli_action_xml("onemarketapp show #{id} -x")
            app['/MARKETPLACEAPP/STATE'] == '1'
        end

        vm_template = Base64.decode64(app['/MARKETPLACEAPP/TEMPLATE/APPTEMPLATE64'])
        vm_template.gsub!("[\n", '[')
        vm_template.split("\n").each do |el|
            next unless el.include?('NIC')

            expect(el.include?("NETWORK_MODE=\"auto\"")).to eq(true)
            expect(el.include?("MARKET=\"YES\"")).to eq(false)
        end
    end

    ############################################################################
    # Service template TYPE=SERVICE_TEMPLATE
    ############################################################################

    it 'should import a service template into marketplace' do
        # Rename the VM template, because name must be unique
        cli_action("onetemplate rename #{@v_template_id} T2")

        cmd = cli_action(
            "onemarketapp service-template import \
            #{@s_template_id} \
            --yes \
            --market #{@mp_id}"
        )

        ids = cmd.stdout[1..-2].split("\n")
        expect(ids.size).to eq(2)

        @app_ids << ids[1].match(/ID: (.*?)$/)[1]
        app       = cli_action_xml("onemarketapp show #{@app_ids[0]} -x")

        expect(app['/MARKETPLACEAPP/APPTEMPLATE64']).not_to be_nil
        expect(app['/MARKETPLACEAPP/STATE']).to eq('1')
        expect(TYPES[app['/MARKETPLACEAPP/TYPE'].to_i]).to eq('SERVICE_TEMPLATE')

        roles = app.retrieve_xmlelements('//ROLE')
        expect(roles.size).to eq(2)

        roles.each do |role|
            expect(role['APP']).not_to be_nil
            expect(role['NAME']).not_to be_nil
        end
    end

    it 'should export a service template from marketplace' do
        app = cli_action("onemarketapp export #{@app_ids.shift} TESTING_3 -d 1").stdout

        app.gsub!("\n", '')
        app.gsub!(' ', '')

        expect(app.include?('IMAGE')).to eq(true)
        expect(app.include?('SERVICE_TEMPLATEID:')).to eq(true)
        expect(app.include?('VMTEMPLATE')).to eq(true)
    end

    after(:all) do
        stop_flow

        begin
            @info[:server].stop if @info[:server]

            if @info[:web]
                @info[:web].kill
                @info[:web].join
            end
        rescue StandardError
        end
    end
end
