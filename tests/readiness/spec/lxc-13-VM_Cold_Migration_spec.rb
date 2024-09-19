require 'init'

RSpec.describe 'Poweroff Migration' do
    before(:all) do
        @defaults = RSpec.configuration.defaults
        @info = {}
    end

    it 'deploys' do
        deploy(@defaults[:template])
    end

    it 'get hosts info' do
        @info[:target_hosts] = []
        onehost_list = cli_action_xml('onehost list -x')
        cluster = "/HOST_POOL/HOST[CLUSTER_ID='#{@info[:vm].cluster_id}']"

        onehost_list.each(cluster) do |host|
            next if host['NAME'] == @info[:vm].host

            state = host['STATE'].to_i
            next if state != 1 && state != 2

            @info[:target_hosts] << host['NAME']
        end

        @info[:target_hosts] << @info[:vm].host
    end

    it 'migrates' do
        @info[:target_hosts].each do |host|
            @info[:vm].poweroff
            @info[:vm].migrate(host)
            @info[:vm].resume

            check_container = SafeExec.run("ssh #{host} sudo lxc-ls")

            expect(check_container.success?).to be(true)
            expect(check_container.stdout).to match(/one-#{@info[:vm].id}/)
        end
    end

    it 'terminate vm ' do
        @info[:vm].terminate
    end

    # TODO: Move to lib. cli_create fails on CLITester:VM
    def deploy(template)
        cmd = "onetemplate instantiate #{template}"

        @info[:vm] = VM.new(cli_create(cmd))
        @info[:vm].running?
    end
end
