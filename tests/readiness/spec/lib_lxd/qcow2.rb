shared_examples_for 'qcow2_cache' do
    it 'qemu-nbd uses proper --cache argument' do
        cmd = "onetemplate show -x #{@defaults[:template]}"
        template = cli_action_xml(cmd)
        image = template['//VMTEMPLATE/TEMPLATE/DISK/IMAGE']
        cmd = "oneimage show -x #{image}"
        img_format = cli_action_xml(cmd)['//IMAGE/FORMAT']

        skip "image with format #{img_format} not qcow2" unless img_format == 'qcow2'

        create_vm = "onevm create --cpu 0.1 --memory 128 --disk #{image}"

        ContainerHost::CACHE_MODES.each do |mode|
            create_cmd = create_vm
            create_cmd = "#{create_vm}:cache=#{mode}" unless mode.nil?

            pp create_cmd

            @info[:vm] = VM.new(cli_create(create_cmd))
            @info[:vm].running?

            host = CLITester::Host.new(@info[:vm].host_id)
            host = ContainerHost.new_host(host)
            expect(host.cache_mode?(@info[:vm].id, mode)).to be(true)

            @info[:vm].terminate_hard
        end
    end
end
