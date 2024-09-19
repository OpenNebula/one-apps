require 'init'
require 'lib_lxd/DiskResize'
require 'pry'

include DiskResize

module CLITester

    DEFAULT_TIMEOUT = 360

end

# Test the disk resize operation

# Description:
# - VM is deployed
# - SSH is configured (contextualization)
# - Disk size is measured
# - VM is deleted
# - New VM is deployed with a new size
# - Disk size is measured again
# - VM is deleted
# - Check datastore contents
shared_examples_for 'disk_resize_one_instantiate' do |name, path|
    before(:all) do
        # Used to pass info accross tests
        @info = {}

        cli_create("oneimage create -d 1 --type OS --name '#{name}' --path '#{path}'")
        # create templates
        cli_create('onetemplate create', <<-EOT)
            NAME = "#{name}"
            CONTEXT = [
              NETWORK = "yes",
              SSH_PUBLIC_KEY = "$USER[SSH_PUBLIC_KEY]"
            ]
            CPU  = "0.1"
            MEMORY = "128"
            ARCH = "x86_64"
            DISK = [
                IMAGE = "#{name}"
            ]
            NIC = [
                NETWORK = "public"
            ]
            GRAPHICS = [
                TYPE = "vnc",
                LISTEN = "0.0.0.0"
            ]
        EOT

        wait_loop(:success => 'READY', :break => 'ERROR') do
            xml = cli_action_xml("oneimage show -x '#{name}'")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        end

        # Use the same VM for all the tests in this example
        @info[:vm_id] = cli_create("onetemplate instantiate --hold '#{name}'")
        @info[:vm]    = VM.new(@info[:vm_id])

        @info[:ds_id]    = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DATASTORE_ID']
        @info[:prefix]   = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DEV_PREFIX']
        @info[:image_id] = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/IMAGE_ID']

        # Get image list
        @info[:image_list] = DSDriver.get(@info[:ds_id]).image_list
    end

    after(:all) do
        cli_action("oneimage delete '#{name}'")
        cli_action("onetemplate delete '#{name}'")
    end

    it 'deploys' do
        cli_action("onevm release #{@info[:vm_id]}")
        @info[:vm].running?
    end

    it 'ssh and context' do
        @info[:vm].reachable?
    end

    it 'measure disk size' do
        @info[:disk_size] = Integer(@info[:vm]['//DISK[DISK_ID=0]/SIZE'])
    end

    it 'measure fs size' do
        skip unless ext4_resize?
        @info[:fs_size] = get_fs_size(@info[:vm])
    end

    it 'terminate vm' do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    it 'deploy new vm with disk resize' do
        @info[:disk_resize] = @info[:disk_size] + 1024
        template_opts = "--disk #{@info[:image_id]}:size=#{@info[:disk_resize]}"
        @info[:vm_id] = cli_create("onetemplate instantiate '#{name}' #{template_opts}")
        @info[:vm]    = VM.new(@info[:vm_id])
    end

    it 'ssh and context' do
        @info[:vm].reachable?
    end

    it 'measure disk size' do
        expected = @info[:disk_resize]

        @info[:vm].info
        new_disk_size = Integer(@info[:vm]['//DISK[DISK_ID=0]/SIZE'])

        expect(new_disk_size).to eq(expected)
    end

    it 'measure fs size' do
        skip unless ext4_resize?

        new_fs_size = nil

        again(true) do
            new_fs_size = get_fs_size(@info[:vm])
            new_fs_size > @info[:fs_size]
        end

        expect(new_fs_size).to be > (@info[:fs_size])
        expect(new_fs_size).to be <= (@info[:disk_resize] * 1024)
    end

    it 'terminate vm' do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    it 'datastore contents are unchanged' do
        # image epilog settles...
        wait_loop(:success => true, :timeout => 20) do
            DSDriver.get(@info[:ds_id]).image_list == @info[:image_list]
        end
    end
end

RSpec.describe 'Disk Resize on instantiate' do
    [['raw-xfs', 'http://services/images/lxc/lxc-raw-xfs'],
     ['qcow2-ext4', 'http://services/images/lxc/lxc-qcow2-ext4']].each do |item|
        context "#{item[0]}" do
            it_should_behave_like 'disk_resize_one_instantiate', item[0], item[1]
        end
    end
end
