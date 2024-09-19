require 'init'

RSpec.describe 'Migrate vmdk image to qcow2 ds from Marketplace' do
    before(:all) do
        @defaults = RSpec.configuration.defaults
        @info = {}

        # vmdk to qcow2
        @info[:market_app]               = ''
        @info[:market_qcow2_image]       = 'Alpine to qcow2'
        @info[:template_qcow2]           = 'template-alpine'
    end

    it 'change driver in image datastore' do
        ds_mad_update = "DRIVER=qcow2\n"
        cli_update('onedatastore update 1', ds_mad_update, true)
        xml_datastore = cli_action_xml('onedatastore show 1 -x', true)
        expect(xml_datastore['TEMPLATE/DRIVER']).to eq('qcow2')
    end

    it 'finds latest Alpine appliance' do
        app_list = 'onemarketapp list -l NAME | grep "Alpine Linux" | sort | tail -1'
        cmd = SafeExec.run(app_list)
        cmd.stdout.strip!

        expect(cmd.stdout).not_to be_empty
        @info[:market_app] = cmd.stdout
    end

    it 'download image to vmdk datastore' do
        cmd = "onemarketapp export '#{@info[:market_app]}' "

        cmd << "'#{@info[:market_qcow2_image]}' -d 1"

        cli_action(cmd, true)

        wait_loop(:success => 'READY', :break => 'ERROR') do
            cmd = "oneimage show -x '#{@info[:market_qcow2_image]}'"
            xml = cli_action_xml(cmd)
            Image::IMAGE_STATES[xml['STATE'].to_i]
        end
    end

    it 'check proper image format' do
        path = cli_action_xml("oneimage show -x '#{@info[:market_qcow2_image]}'")['SOURCE']
        cmd    = "file #{path}"
        cmd.squeeze!('/')
        res = %x(#{cmd}).downcase.include?('qcow')
        expect(res).to be(true)
    end

    it 'create template for qcow2 image and instantiate' do
        template = <<-EOF
            NAME = \"#{@info[:template_qcow2]}\"
            CONTEXT = [
                NETWORK = \"YES\",
                SSH_PUBLIC_KEY = \"$USER[SSH_PUBLIC_KEY]\" ]
            CPU = \"0.1\"
            DISK = [
                IMAGE = \"#{@info[:market_qcow2_image]}\",
                IMAGE_UNAME = \"oneadmin\" ]
            GRAPHICS = [
                LISTEN = \"0.0.0.0\",
                TYPE = \"VNC\" ]
            HYPERVISOR = \"kvm\"
            MEMORY = \"256\"
            MEMORY_UNIT_COST = \"MB\"
            OS = [
                BOOT = \"\" ]
        EOF

        if @defaults[:microenv] == 'kvm-qcow2-ssh'
            template += "\nTM_MAD_SYSTEM=\"ssh\""
        end

        cli_create('onetemplate create', template)

        cmd = "onetemplate instantiate '#{@info[:template_qcow2]}'"
        vm_id = cli_create(cmd)
        @info[:vm] = VM.new(vm_id)
        @info[:vm].running?
        @info[:vm].terminate_hard
    end

    it 'delete image downloaded and template created' do

        cmd = "oneimage delete '#{@info[:market_qcow2_image]}'"
        cli_action(cmd, true)
        cmd = "onetemplate delete #{@info[:template_qcow2]}"
        cli_action(cmd, true)
    end
end
