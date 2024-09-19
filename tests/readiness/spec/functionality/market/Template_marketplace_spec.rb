require 'init_functionality'

require 'base64'
require 'webrick'

RSpec.describe 'MarketPlace VM Template operations' do
    prepend_before(:all) do
        @defaults_yaml = File.realpath(
            File.join(File.dirname(__FILE__), 'defaults.yaml')
        )
    end

    before(:all) do
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
        cli_update('onedatastore update files', 'TM_MAD=dummy', false)

        wait_loop do
            xml = cli_action_xml('onedatastore show -x 1')
            xml['FREE_MB'].to_i > 0
        end

        # Create Kernel and Context images
        tempfile = Tempfile.new('market')
        tempfile << 'testing file'
        tempfile.close

        @kernel = cli_create(
            'oneimage create -d files --name test_kernel ' \
            "--path #{tempfile.path} --type KERNEL"
        )

        @context = cli_create(
            'oneimage create -d files --name test_context ' \
            "--path #{tempfile.path} --type CONTEXT"
        )

        template = <<-EOT
            CONTEXT=[
              FILES_DS="$FILE[IMAGE_ID=\\\"#{@context}\\\"]",
              NETWORK="YES",
              SSH_PUBLIC_KEY="$USER[SSH_PUBLIC_KEY]" ]
            CPU="0.1"
            GRAPHICS=[
              LISTEN="0.0.0.0",
              TYPE="VNC" ]
            MEMORY="128"
            NAME="testing_template"
            NIC=[
              NETWORK="private",
              NETWORK_UNAME="oneadmin",
              SECURITY_GROUPS="0" ]
            NIC_ALIAS=[
              NETWORK="private",
              NETWORK_UNAME="oneadmin",
              PARENT="NIC0",
              SECURITY_GROUPS="0" ]
            OS=[
              BOOT="",
              KERNEL_DS=\"$FILE[IMAGE_ID=\\\"#{@kernel}\\\"]\" ]
        EOT

        template_file = Tempfile.new('vm_template')
        template_file << template
        template_file.close

        @t_id    = cli_create("onetemplate create #{template_file.path}")
        @app_ids = []
    end

    it 'should import a VM template into marketplace' do
        cmd = cli_action(
            "onemarketapp vm-template import #{@t_id} --yes --market #{@mp_id}"
        )

        ids = cmd.stdout.split("\n")

        # First app is the image, second is the VM template
        ids.map! {|id| id.match(/ID: (.*?)$/)[1] }
        ids.each {|id| @app_ids << id }

        wait_loop do
            app = cli_action_xml("onemarketapp show #{@app_ids[0]} -x")
            app['/MARKETPLACEAPP/STATE'] == '1'
        end

        expect(@app_ids.size).to eq(1)
    end

    it 'should check KERNEL app in marketplace' do
        app  = cli_action_xml("onemarketapp show #{@app_ids[0]} -x")
        tmpl = Base64.decode64(app['TEMPLATE/APPTEMPLATE64']).strip

        expect(tmpl.include?("KERNEL_DS=\"$FILE[IMAGE_ID=\\\"#{@kernel}\\\"")).to eq(true)
    end

    it 'should check CONTEXT app in marketplace' do
        app = cli_action_xml("onemarketapp show #{@app_ids[0]} -x")
        tmpl = Base64.decode64(app['TEMPLATE/APPTEMPLATE64']).strip

        expect(tmpl.include?("FILES_DS=\"$FILE[IMAGE_ID=\\\"#{@context}\\\"")).to eq(true)
    end

    after(:all) do
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
