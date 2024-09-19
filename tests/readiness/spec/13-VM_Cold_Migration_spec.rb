require 'init'

def cold_migration(host, ds_id)
    puts "onevm migrate #{@info[:vm_id]} #{host} #{ds_id}"

    cli_action("onevm migrate #{@info[:vm_id]} #{host} #{ds_id}")
    @info[:vm].running?

    cmd = "ssh #{HOST_SSH_OPTS} #{host} virsh -c qemu:///system list"
    post_migrate_cmd = SafeExec::run(cmd)

    # verify host
    expect(post_migrate_cmd.success?).to be(true)
    expect(post_migrate_cmd.stdout).to match(/\Wone-#{@info[:vm_id]}\W/)
end

def create_remote_symlink(host, ds_id)
    puts "create remote symlink /srv/#{ds_id} to /var/lib/one/datastores/#{ds_id} in #{host}"

    cmd = "ssh #{HOST_SSH_OPTS} #{host} ln -s /srv/#{ds_id} /var/lib/one/datastores/#{ds_id}"
    post_migrate_cmd = SafeExec::run(cmd)

    # verify host
    expect(post_migrate_cmd.success?).to be(true)
end

# Tests basic VM Operations

# Parameters:
# :template: VM that is tested is instantiated from this template
RSpec.describe "Cold Migration" do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        # Use the same VM for all the tests in this example
        @info[:vm_id] = cli_create("onetemplate instantiate '#{@defaults[:template]}'")
        @info[:vm]    = VM.new(@info[:vm_id])

        @info[:ds_id]     = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DATASTORE_ID']
        @info[:ds_driver] = DSDriver.get(@info[:ds_id])

        # Get image list
        @info[:image_list] = @info[:ds_driver].image_list

        @info[:tm_mad] = cli_action_xml("onedatastore show -x 0")['TM_MAD']
    end

    it "deploys" do
        @info[:vm].running?
    end

    it "ssh and context" do
        @info[:vm].reachable?
    end

    it "get hosts info" do
        # Get Cluster and Host list
        cluster_id = @info[:vm]["HISTORY_RECORDS/HISTORY[last()]/CID"]
        current_host = @info[:vm]["HISTORY_RECORDS/HISTORY[last()]/HOSTNAME"]

        @info[:target_hosts] = []
        onehost_list = cli_action_xml("onehost list -x")
        onehost_list.each("/HOST_POOL/HOST[CLUSTER_ID='#{cluster_id}']") do |h|
            next if h['NAME'] == current_host

            state = h['STATE'].to_i
            next if state != 1 && state != 2

            @info[:target_hosts] << h['NAME']
        end
        @info[:target_hosts] << current_host
    end

    it "create SYS_CLONE DS" do
        skip "Not supported on #{@info[:tm_mad]} TM_MAD" if (!['ssh', 'shared'].include?(@info[:tm_mad]))
        @info[:ds1] = @info[:vm]["HISTORY_RECORDS/HISTORY[last()]/DS_ID"]

        if system('onedatastore show sys_clone >/dev/null 2>&1')
            @info[:ds2] = cli_action_xml(
                'onedatastore show -x sys_clone'
            )['ID']
        else
            ds = DSDriver.new(@info[:ds1])
            template = ds.info.template_str
            template << "\n" << 'NAME="sys_clone"' << "\n"
            @info[:ds2] = cli_create('onedatastore create', template)
        end

        sleep 10
        cli_action("sync")

        if (['shared'].include?(@info[:tm_mad]))
            tgtdir = "/var/lib/one/datastores/#{@info[:ds2]}"

            puts "Move #{tgtdir} to /srv"
            cli_action("[ -d #{tgtdir} ] && mv #{tgtdir} /srv || true")
            cli_action("[ -d /srv/#{@info[:ds2]} ] || mkdir /srv/#{@info[:ds2]}")

            puts "Symlink /srv/#{@info[:ds2]} to /var/lib/one/datastores/#{@info[:ds2]}"
            cli_action("ln -s /srv/#{@info[:ds2]} /var/lib/one/datastores/#{@info[:ds2]}")
            @info[:target_hosts].each do |target_host|
                create_remote_symlink(target_host, @info[:ds2])
            end
        end

    end

    it "migration different hosts" do
        @info[:target_hosts].each do |target_host|
            cold_migration(target_host,"")
        end
    end

    it "migration same host, different DS" do
        skip "Not supported on #{@info[:tm_mad]} TM_MAD" if (!['ssh', 'shared'].include?(@info[:tm_mad]))
        @info[:target_hosts].each do |target_host|
            puts "migrate to target_host - DS #{@info[:ds2]}"
            cold_migration(target_host,@info[:ds2])
            puts "migrate to target_host - DS #{@info[:ds1]}"
            cold_migration(target_host,@info[:ds1])
        end
    end

    it "delete SYS_CLONE DS" do
        skip "Not supported on #{@info[:tm_mad]} TM_MAD" if (!['ssh', 'shared'].include?(@info[:tm_mad]))
        puts "delete sys_clone ds - #{@info[:ds2]}"
        cli_action("onedatastore delete #{@info[:ds2]}")
    end

    ############################################################################
    # Delete VM and datablocks
    ############################################################################

    it "terminate vm " do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    it "datastore contents are unchanged" do
        # image epilog settles...
        sleep 10

        expect(DSDriver.get(@info[:ds_id]).image_list).to eq(@info[:image_list])
    end
end
