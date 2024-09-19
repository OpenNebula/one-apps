require 'init_functionality'
require 'open-uri'

AUTHPATH='/tmp/az_host.tpl'

RSpec.describe 'instantiate/suspend/resume Microsoft Azure Integration tests' do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__), 'defaults.yaml')
    end

    before(:all) do
        File.open(AUTHPATH, 'w') do |file|
            uri = URI.parse(@defaults[:credentials_url])
            file.write(uri.read)
        end

        @info = {}
        @info[:host_id] = cli_create(
            "onehost create az -t az #{AUTHPATH} --im az --vm az"
        )
        @info[:host] = Host.new @info[:host_id]

        template = <<-EOF
            NAME="az_host"
            CPU = 0.5
            MEMORY = 128
            # Azure template machine, this will be use wen submitting this VM to Azure
            PUBLIC_CLOUD = [
                TYPE=azure,
                IMAGE_OFFER="UbuntuServer",
                IMAGE_PUBLISHER="canonical",
                IMAGE_SKU="16.04.0-LTS",
                IMAGE_VERSION="latest",
                INSTANCE_TYPE="Standard_B1ms",
                LOCATION="westeurope",
                VM_PASSWORD="5Vhx2yOx__7m0m",
                VM_USER="azuser",
                VM_USER="MyUserName"
            ]
        EOF

        @tid = cli_create('onetemplate create', template)
    end

    it 'Monitor host' do
        expect(@info[:host].monitored?).to eq('MONITORED')
    end

    it 'Deploys VM' do
        @info[:vm_id] = cli_create("onetemplate instantiate #{@tid}")
        @info[:vm] = VM.new(@info[:vm_id])
        @info[:vm].state?('RUNNING', /FAIL|^POWEROFF|UNKNOWN/, :timeout => 900)
    end

    it 'Suspends VM' do
        cli_action("onevm suspend #{@info[:vm_id]}")
        @info[:vm].state?('SUSPENDED', /FAIL|^POWEROFF|RUNNING|UNKNOWN/)
    end

    it 'Resume VM' do
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].state?('RUNNING', /FAIL|^POWEROFF|UNKNOWN/)
    end

    it 'IP address present' do
        @ip = @info[:vm].wait_monitoring_info('AZ_IPADDRESS')
    end

    it 'Terminate VM' do
        @info[:vm].running?
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].state?('DONE', /FAIL|RUNNING|UNKNOWN/, :timeout => 900)
    end
end
