require 'init'
require 'SafeExec'
require 'securerandom'
require 'base64'

# Tests LUKS image usage

RSpec.describe 'LUKS img operations' do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        # creating LUKS volume requires qemu-img >=2.6 on frontend
        qemu_ver = cli_action("qemu-img --version | grep 'qemu-img version' | awk '{print $3}'").stdout
        qemu_ver.tr!('^0-9\.', '')

        old_qemu = Gem::Version.new(qemu_ver) < Gem::Version.new('2.6.0') ||
            (!@defaults[:flavours].nil? && @defaults[:flavours].include?('ubuntu1604'))

        skip "qemu-img too old" if old_qemu

        @info[:host_ids] = cli_action('onehost list -l id --no-header').stdout.split

        @info[:vm_id] = cli_create("onetemplate instantiate --hold '#{@defaults[:template]}'")
        @info[:vm]    = VM.new(@info[:vm_id])

        @info[:ds_id]  = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DATASTORE_ID']
        @info[:prefix] = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DEV_PREFIX']

        if (driver = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DRIVER'])
            @info[:datablock_opts] = "--format #{driver}"
        else
            @info[:datablock_opts] = ''
        end

        # TODO: have proper datastore content wait/change in MP tests
        # image epilog settles...
        sleep 10

        ds = DSDriver.get(@info[:ds_id])

        # Get image list
        @info[:image_list] = ds.image_list

        # Prepare LUKS img details
        @info[:ds_mad]     = ds.ds_mad
        @info[:vol]        = Tempfile.new('one-readiness').path
        @info[:vol_size]   = '100M'
        @info[:passphrase] = 'secretphrase'
        @info[:uuid]       = SecureRandom.uuid

        # NOTE: in container deployment, command in cli_action is called
        # remotely and existence of empty local file later replaces this
        # one created on remote
        File.unlink(@info[:vol]) if File.exist?(@info[:vol])

        # Create LUKS volume
        cli_action('qemu-img create ' \
                   "--object secret,id=sec0,data=#{@info[:passphrase]} "\
                   '-o key-secret=sec0 -f luks ' \
                   "#{@info[:vol]} #{@info[:vol_size]}")
    end

    after(:all) do
        File.unlink(@info[:vol]) if @info[:vol] && File.exist?(@info[:vol])
    end

    it 'deploys' do
        cli_action("onevm release #{@info[:vm_id]}")
        @info[:vm].running?
    end

    it 'ssh and context' do
        @info[:vm].reachable?
    end

    it 'poweroff' do
        @info[:vm].safe_poweroff
    end

    it 'import LUKS image' do
        cmd = 'oneimage create ' <<
               "--name luks-image-#{rand(36**8).to_s(36)} " <<
               "--path #{@info[:vol]} " <<
               "--prefix #{@info[:prefix]} " <<
               "-d #{@info[:ds_id]}"

        @info[:img_id] = cli_create(cmd)

        wait_loop(:success => 'READY', :break => 'ERROR') do
            xml = cli_action_xml("oneimage show -x #{@info[:img_id]}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        end

        # add secret reference(uuid) to the image
        cli_update("oneimage update #{@info[:img_id]}",
                   "LUKS_SECRET=\"#{@info[:uuid]}\"", true)

        cli_action("oneimage persistent #{@info[:img_id]}")
    end

    it 'defines the secret on hypervisors' do
        secret_xml = Tempfile.new('one-readiness')
        secret_xml.write(<<-EOF)
        <secret ephemeral='no' private='yes'>
          <uuid>#{@info[:uuid]}</uuid>
          <description>luks key</description>
        </secret>
        EOF
        secret_xml.flush

        # libvirt keeps secretes base64 encoded
        passphr64 = Base64.encode64(@info[:passphrase])

        @info[:host_ids].each do |host_id|
            host = Host.new(host_id)

            # upload volume-secret.xml to the hypervisor
            rc = host.scp(secret_xml.path, '/tmp/volume-secret.xml', false,
                          { :timeout => 10 }, @defaults[:oneadmin])

            expect(rc.success?).to eq(true)

            # define and set the virsh secret
            cmd = <<-EOF
            virsh -c qemu:///system secret-define /tmp/volume-secret.xml
            virsh -c qemu:///system secret-set-value #{@info[:uuid]} #{passphr64}
            EOF

            rc = host.ssh(cmd, true, { :timeout => 10 }, @defaults[:oneadmin])
            expect(rc.success?).to eq(true)
        end
    end

    it 'attach LUKS disk' do
        disk_num_before = @info[:vm].disks.size

        cli_action("onevm disk-attach #{@info[:vm_id]} " <<
                   " --image #{@info[:img_id]} " <<
                   " --prefix #{@info[:prefix]}")
        @info[:vm].state?('POWEROFF')

        @info[:vm].info
        disk_num_after = @info[:vm].disks.size

        expect(disk_num_after).to eq(disk_num_before + 1)
    end

    it 'resumes' do
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it 'writes to disk' do
        target = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id]}']/TARGET"]
        @info[:target] = target

        # clear the disk first
        cmd = @info[:vm].ssh("dd if=/dev/zero of=/dev/#{@info[:target]} bs=1M count=100")
        expect(cmd.success?).to eq(true)

        # write something
        cmd = @info[:vm].ssh("echo yolo_yolo > /dev/#{@info[:target]}; sync")
        expect(cmd.success?).to eq(true)

        # ensure it's readable
        cmd = @info[:vm].ssh("head -n1 /dev/#{@info[:target]}")
        expect(cmd.stdout.strip).to eq('yolo_yolo')
    end

    it "verify disk type, checks it's encrypted" do
        host = Host.new(@info[:vm].host_id)

        disk_pt = ''
        if @info[:ds_mad] == 'ceph'
            source = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id]}']/SOURCE"]
            disk_pt = "/tmp/one-#{@info[:img_id]}.raw"

            # for ceph export the disk to read
            host.ssh("rbd --id oneadmin export #{source} #{disk_pt}",
                     true, { :timeout => 100 }, @defaults[:oneadmin]).expect_success
        else
            disk_id = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id]}']/DISK_ID"]
            ds_id   = @info[:vm].xml['HISTORY_RECORDS/HISTORY[last()]/DS_ID']
            disk_pt = "/var/lib/one/datastores/#{ds_id}/#{@info[:vm_id]}/disk.#{disk_id}"
        end

        # check disk type
        cmd = "file -L #{disk_pt} | grep -e 'LUKS encrypted file' -e 'block special'"

        out = host.ssh(cmd, false, { :timeout => 11 },
                       @defaults[:oneadmin]).stdout.strip
        expect(out).not_to be_empty

        # poor's man grep
        cmd = "strings #{disk_pt} | grep yolo_yolo"
        out = host.ssh(cmd, false, { :timeout => 11 },
                       @defaults[:oneadmin]).stdout.strip

        expect(out).to be_empty
    end

    it 'poweroff' do
        @info[:vm].safe_poweroff
    end

    it 'resume' do
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it 'verify disk is readable' do
        # ensure it's readable
        cmd = @info[:vm].ssh("head -n1 /dev/#{@info[:target]}")
        expect(cmd.stdout.strip).to eq('yolo_yolo')
    end

    it 'terminate vm and datablocks' do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?

        cli_action("oneimage delete #{@info[:img_id]}")
        wait_loop(:success => true) do
            cmd = cli_action("oneimage show #{@info[:img_id]}", nil, true)
            cmd.fail?
        end
    end

    it 'datastore contents are unchanged' do
        wait_loop(:success => @info[:image_list], :timeout => 30) do
            DSDriver.get(@info[:ds_id]).image_list
        end
    end
end
