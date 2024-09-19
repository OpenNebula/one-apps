require 'init'

RSpec.describe 'Schedule VM with qcow2 disk to different datastore' do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        # VM info
        @info[:vm_id] = cli_create("onetemplate instantiate --hold '#{@defaults[:template]}'")
        @info[:vm]    = VM.new(@info[:vm_id])
    end


    after(:all) do
        @info[:vm].terminate_hard

        cli_action("onedatastore delete #{@info[:sys_ds2_id]}") \
            if @info[:sys_ds2_id]
    end

    it "adds new qcow2 datastore" do

        template=<<-EOF
          NAME   = sys2-qcow2
          TM_MAD = qcow2
          TYPE   = system_ds
          SHARED = YES
        EOF

        @info[:sys_ds2_id] = cli_create("onedatastore create", template)

        host_ids = cli_action('onehost list -l id --no-header').stdout.split

        expect(host_ids).not_to be_empty

        FileUtils.mkdir("/srv/#{@info[:sys_ds2_id]}")

        host_ids.each do |h|
            host = Host.new(h)

            cmd = host.ssh("ln -s /srv/#{@info[:sys_ds2_id]} " <<
                           "/var/lib/one/datastores/#{@info[:sys_ds2_id]}",
                           true, {}, 'oneadmin')
        end
    end

    it "deploys on first datastore" do
        cli_update("onevm update #{@info[:vm_id]}",
                   'SCHED_DS_REQUIREMENTS="ID=0"', true)

        cli_action("onevm release #{@info[:vm_id]}")
        @info[:vm].running?
    end

    it "undeploys" do
        cli_action("onevm undeploy --hard #{@info[:vm_id]}")
        @info[:vm].state?('UNDEPLOYED')
    end

    it "deploys on the other datastore" do
        cli_update("onevm update #{@info[:vm_id]}",
                   "SCHED_DS_REQUIREMENTS=\"ID=#{@info[:sys_ds2_id]}\"", true)

        @info[:vm].resume
        @info[:vm].reachable?
    end
end
