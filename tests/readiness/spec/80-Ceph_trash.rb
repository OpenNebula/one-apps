require 'init'
require 'tempfile'

# Test Ceph trash basic functions

RSpec.describe 'Test Ceph trash basic functions' do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        @info[:ceph_host] = cli_action_xml(
            'onedatastore show -x 0'
        )['TEMPLATE/CEPH_HOST']

    end

    it 'clone system DS' do
        if system('onedatastore show ceph_sys_ds2 >/dev/null 2>&1')
            @info[:sys_ds2_id] = cli_action_xml(
                'onedatastore show -x ceph_sys_ds2'
            )['ID']
        else
            ds = DSDriver.new(0)
            template = ds.info.template_str
            template << "\n" << 'CEPH_TRASH="true"' << "\n"
            template << "\n" << 'NAME="ceph_sys_ds2"' << "\n"
            @info[:sys_ds2_id] = cli_create('onedatastore create', template)
        end
    end

    it 'clone image DS' do
        if system('onedatastore show ceph_img_ds2 >/dev/null 2>&1')
            @info[:img_ds2_id] = cli_action_xml(
                'onedatastore show -x ceph_img_ds2'
            )['ID']
        else
            ds = DSDriver.new(1)
            template = ds.info.template_str
            template << "\n" << 'CEPH_TRASH="true"' << "\n"
            template << "\n" << 'NAME="ceph_img_ds2"' << "\n"
            @info[:img_ds2_id] = cli_create('onedatastore create', template)

            wait_loop(:success => true) do
                xml = cli_action_xml("onedatastore show -x #{@info[:img_ds2_id]}")
                xml['FREE_MB'].to_i > 0
            end
        end
    end

    it 'clone image to new DS' do
        if system('oneimage show alpine2 > /dev/null 2>&1')
            @info[:image_id] = cli_action_xml(
                'oneimage show -x alpine2'
            )['ID']
        else
            @info[:image_id] = cli_create("oneimage clone alpine alpine2 -d #{@info[:img_ds2_id]}")
        end
    end

    it 'create VM template alpine2' do
        if system('onetemplate show alpine2 > /dev/null 2>&1')
            @info[:vm_template_id] = cli_action_xml(
                'onetemplate show -x alpine2'
            )['ID']
        else

            template = <<-EOF
                    NAME   = alpine2
                    ARCH = "x86_64"
                    CONTEXT = [
                      NETWORK = "YES",
                      SSH_PUBLIC_KEY = "$USER[SSH_PUBLIC_KEY]" ]
                    CPU = "0.1"
                    DISK = [
                      IMAGE = "alpine2",
                      IMAGE_UNAME = "oneadmin" ]
                    GRAPHICS = [
                      LISTEN = "0.0.0.0",
                      TYPE = "VNC" ]
                    INPUTS_ORDER = ""
                    MEMORY = "96"
                    MEMORY_UNIT_COST = "MB"
                    NIC = [
                      NETWORK = "public" ]
                    NIC_DEFAULT = [
                      MODEL = "virtio" ]
                    OS = [
                    BOOT = "" ]
            EOF

            @info[:vm_template_id] = cli_create('onetemplate create', template)
        end
    end

    it 'clean trash if needed' do
        cmd = SafeExec.run("ssh #{@info[:ceph_host]} \"sudo rbd -p one trash ls\"")
        expect(cmd.success?).to be(true)
        @info[:trash_ids] = cmd.stdout.scan(/^(\S+) one-.*$/).flatten

        @info[:trash_ids].each do |trash_id|
            cmd = SafeExec.run("ssh #{@info[:ceph_host]} \"sudo rbd -p one trash rm --force #{trash_id}\"")
            expect(cmd.success?).to be(true)
        end
    end

    it 'deploys' do
        @info[:reqs] = "--raw 'SCHED_DS_REQUIREMENTS=\"ID=#{@info[:sys_ds2_id]}\"'"

        @info[:vm_id] = cli_create(
            "onetemplate instantiate '#{@info[:vm_template_id]}' #{@info[:reqs]}"
        )

        @info[:vm] = VM.new(@info[:vm_id])

        @info[:vm].running?
        @info[:host] = @info[:vm]['HISTORY_RECORDS/HISTORY[last()]/HOSTNAME']
    end

    it 'terminate vm' do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    it 'check something in trash' do
        cmd = SafeExec.run("ssh #{@info[:ceph_host]} \"sudo rbd -p one trash ls\"")
        expect(cmd.stdout).not_to be_empty
        @info[:trash_ids] = cmd.stdout.scan(/^(\S+) one-.*$/).flatten
    end

    it 'switch image to persistent' do
        cli_action("oneimage persistent #{@info[:image_id]}")
    end

    it 'deploys (persistent)' do
        @info[:vm_id] = cli_create(
            "onetemplate instantiate '#{@info[:vm_template_id]}' #{@info[:reqs]}"
        )

        @info[:vm] = VM.new(@info[:vm_id])

        @info[:vm].running?
    end

    it 'terminate vm' do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    it 'check something in trash' do
        cmd = SafeExec.run("ssh #{@info[:ceph_host]} \"sudo rbd -p one trash ls\"")
        expect(cmd.stdout).not_to be_empty
        @info[:trash_ids] = cmd.stdout.scan(/^(\S+) one-.*$/).flatten
    end

    it 'clean trash' do
        @info[:trash_ids].each do |trash_id|
            cmd = SafeExec.run("ssh #{@info[:ceph_host]} \"sudo rbd -p one trash rm --force #{trash_id}\"")
            expect(cmd.success?).to be(true)
        end
    end

    it 'check trash is empty' do
        cmd = SafeExec.run("ssh #{@info[:ceph_host]} \"sudo rbd -p one trash ls\"")
        expect(cmd.success?).to be(true)
        expect(cmd.stdout).to be_empty
    end

    ########
    # HERE
    # Image Datastore Ceph trash tests
    ########

    it 'create persistent datablock' do
        @info[:temp_image] = Tempfile.new('datablock')
        `qemu-img create -f raw #{@info[:temp_image].path} 100M`

        cmd = 'oneimage create --name datablock1 ' \
              "--type datablock --path #{@info[:temp_image].path} " \
              "-d #{@info[:img_ds2_id]} --persistent"

        img_id = cli_create(cmd)

        wait_loop(:success => 'READY', :break => 'ERROR') do
            xml = cli_action_xml("oneimage show -x #{img_id}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        end

        @info[:img_id] = img_id
    end

    it 'deploys, hot-attach it' do
        @info[:vm_id] = cli_create('onetemplate instantiate ' <<
                                   "'#{@info[:vm_template_id]}' #{@info[:reqs]}")
        @info[:vm] = VM.new(@info[:vm_id])
        @info[:vm].running?

        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:img_id]}")
        @info[:vm].running?
    end

    it 'write to the disk' do
        @info[:vm].reachable?
        @info[:target] = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id]}']/TARGET"]
        @info[:vm].ssh("echo S1 > /dev/#{@info[:target]}; sync")

        sleep 5
    end

    it 'detach the disk' do
        disk_id = @info[:vm].xml['TEMPLATE/DISK[last()]/DISK_ID']
        cli_action("onevm disk-detach #{@info[:vm_id]} #{disk_id}")
        @info[:vm].state?('RUNNING')
    end

    it 'ensure the image content is S1' do
        cmd = SafeExec.run("ssh #{@info[:ceph_host]} \"sudo rbd -p one export one-#{@info[:img_id]} - 2>/dev/null | head -1\"")

        expect(cmd.stdout).to match('S1')
    end

    it 'switch image to non-persistent, hot-attach it' do
        cli_action("oneimage nonpersistent #{@info[:img_id]}")

        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:img_id]}")
        @info[:vm].running?
    end

    it 'detach the disk' do
        disk_id = @info[:vm].xml['TEMPLATE/DISK[last()]/DISK_ID']
        cli_action("onevm disk-detach #{@info[:vm_id]} #{disk_id}")
        @info[:vm].state?('RUNNING')
    end

    it 'ensure auxilary @snap does not exist' do
        cmd = SafeExec.run("ssh #{@info[:ceph_host]} \"sudo rbd -p one snap ls one-#{@info[:img_id]}\"")
        expect(cmd.stdout).to be_empty
        expect(cmd.stdout).not_to match(/snap/)
    end

    it 'check something in trash' do
        cmd = SafeExec.run("ssh #{@info[:ceph_host]} \"sudo rbd -p one trash ls\"")
        expect(cmd.stdout).not_to be_empty
        @info[:trash_ids] = cmd.stdout.scan(/^(\S+) one-.*$/).flatten
    end

    it 'switch image back to persistent, hot-attach it' do
        cli_action("oneimage persistent #{@info[:img_id]}")

        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:img_id]}")
        @info[:vm].running?
    end

    it 'write to the disk again' do
        @info[:target] = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id]}']/TARGET"]
        @info[:vm].ssh("echo S2 > /dev/#{@info[:target]}; sync")

        sleep 5
    end

    it 'detach the disk' do
        disk_id = @info[:vm].xml['TEMPLATE/DISK[last()]/DISK_ID']
        cli_action("onevm disk-detach #{@info[:vm_id]} #{disk_id}")
        @info[:vm].state?('RUNNING')
    end

    it 'ensure the image content is S2' do
        cmd = SafeExec.run("ssh #{@info[:ceph_host]} \"sudo rbd -p one export one-#{@info[:img_id]} - 2>/dev/null | head -1\"")

        expect(cmd.stdout).to match('S2')
    end

    it 'switch image to non-persistent, hot-attach it' do
        cli_action("oneimage nonpersistent #{@info[:img_id]}")

        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:img_id]}")
        @info[:vm].running?
    end

    it 'ensure the disk content on VM is also S2' do
        @info[:vm].reachable?
        @info[:target] = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id]}']/TARGET"]
        cmd = @info[:vm].ssh("head -1 /dev/#{@info[:target]}")

        expect(cmd.stdout).to match('S2')
    end

    it 'check something in trash' do
        cmd = SafeExec.run("ssh #{@info[:ceph_host]} \"sudo rbd -p one trash ls\"")
        expect(cmd.stdout).not_to be_empty
        @info[:trash_ids] = cmd.stdout.scan(/^(\S+) one-.*$/).flatten
    end

    it 'clean trash' do
        @info[:trash_ids].each do |trash_id|
            cmd = SafeExec.run("ssh #{@info[:ceph_host]} \"sudo rbd -p one trash rm --force #{trash_id}\"")
            expect(cmd.success?).to be(true)
        end
    end

    it 'check trash is empty' do
        cmd = SafeExec.run("ssh #{@info[:ceph_host]} \"sudo rbd -p one trash ls\"")
        expect(cmd.success?).to be(true)
        expect(cmd.stdout).to be_empty
    end

    after(:all) do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?

        # clean trash
        cmd = SafeExec.run("ssh #{@info[:ceph_host]} \"sudo rbd -p one trash ls\"")
        @info[:trash_ids] = cmd.stdout.scan(/^(\S+) one-.*$/).flatten

        @info[:trash_ids].each do |trash_id|
            cmd = SafeExec.run("ssh #{@info[:ceph_host]} \"sudo rbd -p one trash rm --force #{trash_id}\"")
            expect(cmd.success?).to be(true)
        end

        if @info[:image_id]
            cmd = cli_action("oneimage delete #{@info[:image_id]}")
            expect(cmd.success?).to be(true)
        end

        if @info[:img_id]
            cmd = cli_action("oneimage delete #{@info[:img_id]}")
            expect(cmd.success?).to be(true)
        end

        # wait until the image is gone
        wait_loop(:success => true) do
            xml = cli_action_xml("onedatastore show -x #{@info[:img_ds2_id]}")
            xml['IMAGES'] == ''
        end

        if @info[:vm_template_id]
            cmd = cli_action("onetemplate delete #{@info[:vm_template_id]}")
            expect(cmd.success?).to be(true)
        end

        if @info[:sys_ds2_id]
            cmd = cli_action("onedatastore delete #{@info[:sys_ds2_id]}")
            expect(cmd.success?).to be(true)
        end

        if @info[:img_ds2_id]
            cmd = cli_action("onedatastore delete #{@info[:img_ds2_id]}")
            expect(cmd.success?).to be(true)
        end
    end
end
