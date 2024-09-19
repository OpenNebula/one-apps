$LOAD_PATH.unshift File.dirname(__FILE__)

require 'init'
require 'host'
require 'containerhost'

# tested_app  => application to be tested
# app_suffix  => string appended to the app name by the market monitor driver
# market_name => Full Name String of the marketplace

shared_examples_for 'container marketplaces' do |tested_app, app_suffix, market_name, timeout|
    it 'export app' do
        @info[:vm] = nil
        app_id = -1

        # Wait for marketplace to be monitored, read app ID
        wait_loop do
            marketapp_pool = cli_action_xml('onemarketapp list -x')

            marketapp_pool.each('/MARKETPLACEAPP_POOL/MARKETPLACEAPP') do |app|
                next unless app['MARKETPLACE'] == market_name

                app_name = app['NAME'].chomp(app_suffix)
                next unless app_name == tested_app

                app_id = app['ID'].to_i
                break
            end

            app_id >= 0
        end

        cmd = "onemarketapp export #{app_id} #{tested_app} -d 1"
        cmd = cli_action(cmd)

        ids = cmd.stdout.scan(/ID: (-?\d+)/).flatten

        expect(ids.length).to eq(2)
        expect(ids[0].to_i).to be >= -1

        img_id = ids[0]

        cmd = "onetemplate show #{tested_app}"
        cmd = SafeExec.run(cmd)
        expect(cmd.success?).to be(true)

        timeout ||= CLITester::DEFAULT_TIMEOUT

        wait_loop({ :success => 'READY', :timeout => timeout, :break => 'ERROR' }) do
            xml = cli_action_xml("oneimage show -x #{img_id}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        end

        @info[:image_id] = img_id
        @info[:app_template] = tested_app
    end

    it 'instantiate VM' do
        cmd = "onetemplate instantiate base --disk #{@info[:image_id]}"
        @info[:vm_id] = cli_create(cmd)
        @info[:vm]    = VM.new(@info[:vm_id])
    end

    it 'deploy VM' do
        skip('VM not instantiated') if @info[:vm].nil?
        @info[:vm].running?

        host = Host.new(@info[:vm].host_id)
        @info[:host] = ContainerHost.new_host(host)
    end

    it 'has chroot log' do
        unless ['Linux Containers', 'TurnKey Linux Containers'].include?(market_name)
            skip 'only for markets that use lxd_downloader.sh'
        end

        log = '/var/log/chroot.log'
        cmds = ["[ -f #{log} ]", "cat #{log}"]

        cmds.each do |cmd|
            cmd = @info[:host].container_exec(cmd, @info[:vm].instance_name)
            expect(cmd.success?).to be(true)

            pp cmd.stdout
        end
    end

    it 'one-context is installed' do
        cmd = '[ -d /etc/one-context.d ]'
        cmd = @info[:host].container_exec(cmd, @info[:vm].instance_name)

        if cmd.fail?
            @info[:skip] = true
            raise('/etc/one-context.d not found')
        else
            @info[:skip] = false
        end
    end

    it 'eth0 has ip address' do
        skip('one-context is not installed') if @info[:skip]

        pp 'waiting for one-context to setup network'

        @info[:skip] = true
        @info[:vm].wait_ping
        @info[:skip] = false
    end

    it 'ssh into VM' do
        skip('no IP address set on VM') if @info[:skip]

        @info[:skip] = true
        @info[:vm].reachable?
        @info[:skip] = false
    end

    it 'execute entrypoint script' do
        skip('cannot SSH to VM') if @info[:skip]

        skip 'only for DockerHub' unless market_name == 'DockerHub'

        cmd = @info[:vm].ssh('ls /one_entrypoint.sh')
        expect(cmd.stdout.strip).to eq('/one_entrypoint.sh')

        @info[:vm].ssh('nohup /one_entrypoint.sh &> /dev/null &')

        wait_loop(:success => true) do
            cmd = cli_action("curl #{@info[:vm].get_ip}", nil)
            cmd.success?
        end
    end

    it 'destroy VM' do
        @info[:vm].terminate
    end

    it 'deletes imported App template with image' do
        cli_action("onetemplate delete --recursive #{@info[:app_template]}")
    end
end
