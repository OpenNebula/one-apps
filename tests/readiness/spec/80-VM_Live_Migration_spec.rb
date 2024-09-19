require 'init'

def break_time
    @info[:vm].reachable?
    @info[:vm].ssh('TZ=UTC date -s \'1995-04-13\'')
    expect(@info[:vm].ssh('TZ=UTC date +%Y-%m-%d').stdout.strip).to eq('1995-04-13')
end

def check_time
    @info[:vm].reachable?

    c_date = Time.now.getgm.strftime("%Y-%m-%d")
    v_date = nil

    (1..20).to_a.each do |_i|
        v_date = @info[:vm].ssh('TZ=UTC date +%Y-%m-%d').stdout.strip
        break if v_date != '1995-04-13'

        sleep 1
    end

    unless v_date == c_date
        STDERR.puts "ERROR: Expected date #{c_date}, but VM has #{v_date}"
    end

    v_date == c_date
end

# Tests basic VM Operations

# Parameters:
# :template: VM that is tested is instantiated from this template
RSpec.describe "Live Migration" do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        skip 'Unsupported system' if
            @defaults[:microenv].start_with?('kvm-ssh') &&
            %w[centos7 rhel7].include?(@defaults[:platform]) &&
            !@defaults[:flavours].include?('ev')

        skip 'Issue #4695' if @defaults[:platform] == 'fedora32'

        # Used to pass info accross tests
        @info = {}

        # Do time (de)synchronization checks if configured
        @info[:sync_time] = cli_action(
            'grep -i sync_time=yes /var/lib/one/remotes/etc/vmm/kvm/kvmrc', nil
        ).success?

        @info[:sync_time_results] = []

        # update the template with guest agent
        cli_update("onetemplate update #{@defaults[:template]}",
                   "FEATURES=[GUEST_AGENT=\"yes\"]",
                   true)

        # Use the same VM for all the tests in this example
        @info[:vm_id] = cli_create("onetemplate instantiate #{@defaults[:template]}")
        @info[:vm]    = VM.new(@info[:vm_id])

        @info[:ds_id]     = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DATASTORE_ID']
        @info[:ds_driver] = DSDriver.get(@info[:ds_id])

        # Get image list
        @info[:image_list] = @info[:ds_driver].image_list
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

    it "hot attach volatile datablock" do
        disk_count_before = 0
        @info[:vm].xml.each("TEMPLATE/DISK"){ disk_count_before+=1 }
        @info[:prefix] = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DEV_PREFIX']

        # attach volatile
        disk_volatile_template = TemplateParser.template_like_str(
            {:disk => {:size => 100,
                       :type => "fs",
                       :dev_prefix => @info[:prefix],
                       :driver => "raw",
                       :cache => "none"}})
        disk_volatile = Tempfile.new('disk_volatile')
        disk_volatile.write(disk_volatile_template)
        disk_volatile.close

        cli_action("onevm disk-attach #{@info[:vm_id]} --file #{disk_volatile.path}")
        @info[:vm].running?
        disk_volatile.unlink

        # ensure disk count check
        disk_count = 0
        @info[:vm].xml.each("TEMPLATE/DISK"){ disk_count+=1 }
        expect(disk_count - disk_count_before).to eq(1)

        # check if disk appeared
        target = @info[:vm].xml['TEMPLATE/DISK[last()]/TARGET']
        wait_loop do
            @info[:vm].ssh("test -b /dev/#{target}").success?
        end
    end

    it "live migration" do
        @info[:target_hosts].each do |target_host|
            puts "\tlive-migrate to #{target_host}"

            break_time if @info[:sync_time]

            cli_action("onevm migrate --live #{@info[:vm_id]} #{target_host}")
            @info[:vm].running?
            @info[:vm].reachable?

            cmd = "ssh #{HOST_SSH_OPTS} #{target_host} virsh -c qemu:///system list"
            post_migrate_cmd = SafeExec::run(cmd)
            expect(post_migrate_cmd.success?).to be(true)
            expect(post_migrate_cmd.stdout).to match(/\Wone-#{@info[:vm_id]}\W/)

            @info[:sync_time_results] << check_time if @info[:sync_time]
        end
    end

    it 'synchronized time' do
        skip('Not configured for time sync.') unless @info[:sync_time]

        expect(@info[:sync_time_results]).to eq([true, true])
    end

    ############################################################################
    # Delete VM and datablocks
    ############################################################################

    it "terminate vm " do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    it "remove GUEST_AGENT from template" do
        cli_update("onetemplate update #{@defaults[:template]}",
                   "FEATURES=[]",
                   true)
    end

    it "datastore contents are unchanged" do
        # image epilog settles...
        sleep 10

        expect(DSDriver.get(@info[:ds_id]).image_list).to eq(@info[:image_list])
    end

    it "verify lvm cleanup" do
        tm_mad = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/TM_MAD']
        skip "Only applicable for LVM microenvs" unless ['fs_lvm', 'fs_lvm_ssh'].include?(tm_mad)

        @info[:target_hosts].each do |target_host|
            cmd = "ssh #{target_host} sudo /sbin/dmsetup ls"
            dmsetup_cmd = SafeExec::run(cmd)
            expect(dmsetup_cmd.success?).to be(true)
            expect(dmsetup_cmd.stdout.strip).not_to include('one')
        end
    end
end
