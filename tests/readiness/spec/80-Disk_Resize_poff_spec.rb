require 'init'
require 'lib/DiskResize'

include DiskResize

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
# Parameters:
# :template: VM that is tested is instantiated from this template
RSpec.describe 'Disk Resize PowerOff' do

    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        # Use the same VM for all the tests in this example
        @info[:vm_id] = cli_create('onetemplate instantiate '\
                                   "'#{@defaults[:template]}'")
        @info[:vm]    = VM.new(@info[:vm_id])

        # Disable LVM DD zeroing
        system("sed -i 's/ZERO_LVM_ON_CREATE=.*/ZERO_LVM_ON_CREATE=no/' "<<
               "/var/lib/one/remotes/etc/tm/fs_lvm/fs_lvm.conf")
        system("sed -i 's/ZERO_LVM_ON_DELTE=.*/ZERO_LVM_ON_DELTE=no/' "<<
               "/var/lib/one/remotes/etc/tm/fs_lvm/fs_lvm.conf")
    end

    after(:all) do
        # Enable LVM DD zeroing
        system("sed -i 's/ZERO_LVM_ON_CREATE=.*/ZERO_LVM_ON_CREATE=yes/' "<<
               "/var/lib/one/remotes/etc/tm/fs_lvm/fs_lvm.conf")
        system("sed -i 's/ZERO_LVM_ON_DELTE=.*/ZERO_LVM_ON_DELTE=yes/' "<<
               "/var/lib/one/remotes/etc/tm/fs_lvm/fs_lvm.conf")
    end

    it 'deploys' do
        @info[:vm].running?
    end

    it 'ssh and context' do
        @info[:vm].reachable?
    end

    it 'measure disk size' do
        @info[:disk_size] = get_disk_size(@info[:vm], 0)
    end

    it 'can poweroff' do
        @info[:vm].safe_poweroff
    end

    it 'is able to resize disk #1' do
        cli_action("onevm disk-resize #{@info[:vm_id]} 0 1G")
        @info[:vm].state?('POWEROFF')
    end

    it 'resumes' do
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it 'has the correct disk size #1' do
        expected = 1 * 1024 * 1024 * 1024

        new_disk_size = again(expected) do
            get_disk_size(@info[:vm], 0)
        end

        expect(new_disk_size).to eq(expected)

        xml_size = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/SIZE']
        expect(xml_size).to eq((1 * 1024).to_s)
    end

    it 'can poweroff' do
        @info[:vm].safe_poweroff
    end

    it 'is able to resize disk #2' do
        cli_action("onevm disk-resize #{@info[:vm_id]} 0 2G")
        @info[:vm].state?('POWEROFF')
    end

    it 'resumes' do
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it 'has the correct disk size #2' do
        expected = 2 * 1024 * 1024 * 1024

        new_disk_size = again(expected) do
            get_disk_size(@info[:vm], 0)
        end

        expect(new_disk_size).to eq(expected)

        xml_size = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/SIZE']
        expect(xml_size).to eq((2 * 1024).to_s)
    end

    it 'create datablock' do
        @info[:ds_id] = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/'\
                                       'DATASTORE_ID']
        prefix = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DEV_PREFIX']

        if (driver = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DRIVER'])
            @info[:datablock_opts] = "--format #{driver}"
        else
            @info[:datablock_opts] = ''
        end

        cmd = 'oneimage create --name '\
              "snapshot_cycle_with_attach_detach_#{@info[:vm_id]} " \
              '--size 100 --type datablock ' \
              "-d #{@info[:ds_id]} #{@info[:datablock_opts]} --prefix #{prefix}"

        img_id = cli_create(cmd)

        wait_loop(:success => 'READY', :break => 'ERROR') do
            xml = cli_action_xml("oneimage show -x #{img_id}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        end

        @info[:img_id] = img_id
        @info[:prefix] = prefix
    end

    it 'can poweroff' do
        @info[:vm].safe_poweroff
    end

    it 'attach volatile datablock' do
        # attach volatile
        disk_volatile_template = TemplateParser.template_like_str(
            :disk => {
                :size => 100,
                :type => 'fs',
                :dev_prefix => @info[:prefix],
                :driver => 'raw'
            }
        )
        disk_volatile = Tempfile.new('disk_volatile')
        disk_volatile.write(disk_volatile_template)
        disk_volatile.close

        cli_action("onevm disk-attach #{@info[:vm_id]} "\
                   "--file #{disk_volatile.path}")
        disk_volatile.unlink

        # wait till get back to POWEROFF
        @info[:vm].state?('POWEROFF')
    end

    it 'resize, resumes and check new size' do
        # ensure disk count check
        disk_count = 0
        @info[:vm].xml.each('TEMPLATE/DISK') { disk_count += 1 }
        new_disk_id = disk_count

        # resize the disk
        cli_action("onevm disk-resize #{@info[:vm_id]} #{new_disk_id} 200M")
        @info[:vm].state?('POWEROFF')

        # resume
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?

        # check new size
        expected = 200 * 1024 * 1024
        new_disk_size = again(expected) do
            get_disk_size(@info[:vm], new_disk_id)
        end

        expect(new_disk_size).to eq(expected)
        xml_size = @info[:vm]
                   .xml["TEMPLATE/DISK[DISK_ID=\"#{new_disk_id}\"]/SIZE"]
        expect(xml_size).to eq(200.to_s)
    end

    it 'terminate vm' do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")

        # wait longer as dd zeroing is slow on LVM
        @info[:vm].done?(:timeout => 500)
    end
end
