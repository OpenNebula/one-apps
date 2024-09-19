require 'init'

# Test the disk iotune parameters

RSpec.describe "Disk parameters " do
    def get_disk_value(xml, disk, vm_id, attribute)
        xml["domain/devices/disk/source[contains(@file,'disk.#{disk}')\
             or contains(@dev,'disk.#{disk}')\
             or contains(@name,'-#{vm_id}-#{disk}')]/../#{attribute}"]
    end

    before(:all) do
        @info = {}

        host = `hostname`
        if host.match('centos7|rhel7') && !host.match('-ev-')
            @skip = true
            skip 'Hotplug not supported, need QEMU version 1.7'
        else
            @skip = false
        end

        @defaults = RSpec.configuration.defaults

        @info[:host] = @defaults[:hosts][0];

        cli_action("onetemplate clone '#{@defaults[:template]}' tmpl_iotune")

        xml = cli_action_xml("onetemplate show -x tmpl_iotune")
        @info[:image] = xml['TEMPLATE/DISK/IMAGE']
        @info[:image_tm_mad] = xml['TEMPLATE/TM_MAD_SYSTEM']

        @info[:tm_mad] = cli_action_xml("onedatastore show -x 0")['TM_MAD']
    end

    after(:all) do
        unless @skip
            # Clean iotune settings
            tmpl = <<-EOF
                DISK=[]
                FEATURES=[]
            EOF

            cli_update("onecluster update 0", tmpl, true)
            cli_update("onehost update #{@info[:host]}", tmpl, true)
            cli_action("onetemplate delete tmpl_iotune", nil, true)
            cli_action("oneimage delete pers-datablock_1", nil, true)
            cli_action("onetemplate delete tmpl_27disk", nil, true)
            cli_action("oneimage delete tiny-datablock_1", nil, true)
        end
    end

    it "read disk iotune set as cluster attribute" do
        # Update cluster with iops values
        tmpl = <<-EOF
            DISK=[
                TOTAL_BYTES_SEC="2097152",
                TOTAL_IOPS_SEC="65536",
                SIZE_IOPS_SEC="131072"
            ]
        EOF

        cli_update("onecluster update 0", tmpl, true)

        # Instantiate VM
        vm_id = cli_create("onetemplate instantiate --hold tmpl_iotune")
        cli_action("onevm deploy #{vm_id} #{@info[:host]}")

        vm = VM.new(vm_id)
        vm.running?

        # Compare virsh dominfo with iotune values
        cmd = cli_action("ssh #{@info[:host]} virsh -c qemu:///system dumpxml one-#{vm_id}")

        elem = XMLElement.new
        elem.initialize_xml(cmd.stdout, "")

        expect(elem["domain/devices/disk/iotune/total_bytes_sec"]).to eq("2097152")
        expect(elem["domain/devices/disk/iotune/total_iops_sec"]).to eq("65536")
        expect(elem["domain/devices/disk/iotune/size_iops_sec"]).to eq("131072")

        cli_action("onevm terminate --hard #{vm_id}")
        vm.done?
    end

    it "read disk iotune set as host attribute" do
        # Update host with iops values
        tmpl = <<-EOF
            DISK=[
                TOTAL_BYTES_SEC="1048576",
                TOTAL_IOPS_SEC="32768",
                SIZE_IOPS_SEC="65536"
            ]
        EOF

        cli_update("onehost update #{@info[:host]}", tmpl, true)

        # Instantiate VM
        vm_id = cli_create("onetemplate instantiate --hold tmpl_iotune")
        cli_action("onevm deploy #{vm_id} #{@info[:host]}")

        vm = VM.new(vm_id)
        vm.running?

        # Compare virsh dominfo with iotune values
        cmd = cli_action("ssh #{@info[:host]} virsh -c qemu:///system dumpxml one-#{vm_id}")

        elem = XMLElement.new
        elem.initialize_xml(cmd.stdout, "")

        expect(elem["domain/devices/disk/iotune/total_bytes_sec"]).to eq("1048576")
        expect(elem["domain/devices/disk/iotune/total_iops_sec"]).to eq("32768")
        expect(elem["domain/devices/disk/iotune/size_iops_sec"]).to eq("65536")

        cli_action("onevm terminate --hard #{vm_id}")
        vm.done?
    end

    it "read disk iotune set as VM attribute" do
        # Update template with iops values
        xml = cli_action_xml("onetemplate show -x tmpl_iotune")
        image = xml['TEMPLATE/DISK/IMAGE']

        tmpl = <<-EOF
            DISK=[
                IMAGE="#{image}",
                TOTAL_BYTES_SEC="524288",
                TOTAL_IOPS_SEC="16384",
                SIZE_IOPS_SEC="32768"
            ]
        EOF

        cli_update("onetemplate update tmpl_iotune", tmpl, true)

        # Instantiate VM
        vm_id = cli_create("onetemplate instantiate --hold tmpl_iotune")
        cli_action("onevm deploy #{vm_id} #{@info[:host]}")

        vm = VM.new(vm_id)
        vm.running?

        # Compare virsh dominfo with iotune values
        cmd = cli_action("ssh #{@info[:host]} virsh -c qemu:///system dumpxml one-#{vm_id}")

        elem = XMLElement.new
        elem.initialize_xml(cmd.stdout, "")

        expect(elem["domain/devices/disk/iotune/total_bytes_sec"]).to eq("524288")
        expect(elem["domain/devices/disk/iotune/total_iops_sec"]).to eq("16384")
        expect(elem["domain/devices/disk/iotune/size_iops_sec"]).to eq("32768")

        cli_action("onevm terminate --hard #{vm_id}")
        vm.done?
    end

    it "attach disk with iotune values" do
        # Instantiate VM and attach disk
        vm_id = cli_create("onetemplate instantiate --hold tmpl_iotune")
        cli_action("onevm deploy #{vm_id} #{@info[:host]}")

        vm = VM.new(vm_id)
        vm.running?

        disk_tmpl = <<-EOT
            DISK = [
                TYPE = fs,
                SIZE = 32,
                TOTAL_BYTES_SEC="33333",
                TOTAL_IOPS_SEC="22222",
                SIZE_IOPS_SEC="11111"
            ]
        EOT

        cli_update("onevm disk-attach #{vm_id} --file", disk_tmpl, false)
        vm.running?

        # Compare virsh dominfo with iotune values
        cmd = cli_action("ssh #{@info[:host]} virsh -c qemu:///system dumpxml one-#{vm_id}")

        elem = XMLElement.new
        elem.initialize_xml(cmd.stdout, "")

        expect(get_disk_value(elem, '2', vm_id, 'iotune/total_bytes_sec')).to eq("33333")
        expect(get_disk_value(elem, '2', vm_id, 'iotune/total_iops_sec')).to eq("22222")
        expect(get_disk_value(elem, '2', vm_id, 'iotune/size_iops_sec')).to eq("11111")

        cli_action("onevm terminate --hard #{vm_id}")
        vm.done?
    end

    it "use iothreads for disk-attach, force iothreadid" do
        # Update host with iothreads value
        tmpl = <<-EOF
            FEATURES = [
                IOTHREADS="2"
            ]
        EOF

        cli_update("onehost update #{@info[:host]}", tmpl, true)

        # Update VM Template and instantiate VM
        cli_action("onetemplate clone '#{@defaults[:template]}' tmpl_iothr")

        tmpl = <<-EOF
            VCPU = 4

            FEATURES = [
                VIRTIO_BLK_QUEUES = "auto"
            ]
        EOF

        cli_update('onetemplate update tmpl_iothr', tmpl, true)

        vm_id = cli_create('onetemplate instantiate --hold tmpl_iothr')

        cli_action("onevm deploy #{vm_id} #{@info[:host]}")

        vm = VM.new(vm_id)
        vm.running?

        disk_tmpl = <<-EOT
            DISK = [
                IMAGE="#{@info[:image]}",
                IOTHREAD="2",
                VIRTIO_BLK_QUEUES = "2"
            ]
        EOT

        cli_update("onevm disk-attach #{vm_id} --file", disk_tmpl, false)
        vm.running?

        # Compare virsh dominfo with iothread values
        cmd = cli_action("ssh #{@info[:host]} virsh -c qemu:///system dumpxml one-#{vm_id}")

        elem = XMLElement.new
        elem.initialize_xml(cmd.stdout, '')

        expect(elem['domain/iothreads']).to eq('2')
        expect(get_disk_value(elem, '0', vm_id, 'driver/@iothread')).to eq('1')
        expect(get_disk_value(elem, '0', vm_id, 'driver/@queues')).to eq('4')

        expect(get_disk_value(elem, '2', vm_id, 'driver/@iothread')).to eq('2')
        expect(get_disk_value(elem, '2', vm_id, 'driver/@queues')).to eq('2')

        cli_action("onevm terminate --hard #{vm_id}")
        vm.done?
    end

    it "use iothreads for disks" do
        # Host has IOTHREADS=2 from previous test

        # Add disk to template
        tmpl_disk = <<-EOF
            DISK=[
                IMAGE="#{@info[:image]}"  # iotrhead 1
            ]
            DISK=[
                IMAGE="#{@info[:image]}"  # iothread 2
            ]
            DISK = [        # no virtio -> no iothread, not supported by qemu
                TYPE = fs,
                SIZE = 32
            ]
        EOF

        cli_update("onetemplate update tmpl_iotune", tmpl_disk, true)

        # Instantiate VM, with 2 virtio disks, check each disk
        # uses different iothread
        vm_id = cli_create("onetemplate instantiate --hold tmpl_iotune")
        cli_action("onevm deploy #{vm_id} #{@info[:host]}")

        vm = VM.new(vm_id)
        vm.running?

        # Compare virsh dominfo with iothread values
        cmd = cli_action("ssh #{@info[:host]} virsh -c qemu:///system dumpxml one-#{vm_id}")

        elem = XMLElement.new
        elem.initialize_xml(cmd.stdout, "")

        expect(elem["domain/iothreads"]).to eq("2")

        io_thr_disk0 = get_disk_value(elem, '0', vm_id, 'driver/@iothread')
        io_thr_disk1 = get_disk_value(elem, '1', vm_id, 'driver/@iothread')
        io_thr_disk2 = get_disk_value(elem, '2', vm_id, 'driver/@iothread')

        expect(io_thr_disk0).not_to be_nil
        expect(io_thr_disk1).not_to be_nil
        expect(io_thr_disk2).to be_nil
        expect(io_thr_disk0).not_to eq(io_thr_disk1)

        cli_action("onevm terminate --hard #{vm_id}")
        vm.done?
    end

    it "use iothreads for disks, force iothreadid" do
        # Host has IOTHREADS=2 from previous test

        # Add disk to template
        tmpl_disk = <<-EOF
            DISK=[
                IMAGE="#{@info[:image]}",
                IOTHREAD="1"
            ]
            DISK=[
                IMAGE="#{@info[:image]}",
                IOTHREAD="1"
            ]
        EOF

        cli_update("onetemplate update tmpl_iotune", tmpl_disk, true)

        # Instantiate VM
        vm_id = cli_create("onetemplate instantiate --hold tmpl_iotune")
        vm    = VM.new(vm_id)

        cli_action("onevm deploy #{vm_id} #{@info[:host]}")
        vm.running?

        # Compare virsh dominfo with iothread values
        cmd = cli_action("ssh #{@info[:host]} virsh -c qemu:///system dumpxml one-#{vm_id}")

        elem = XMLElement.new
        elem.initialize_xml(cmd.stdout, "")

        expect(elem["domain/iothreads"]).to eq("2")
        expect(get_disk_value(elem, '0', vm_id, 'driver/@iothread')).to eq("1")
        expect(get_disk_value(elem, '1', vm_id, 'driver/@iothread')).to eq("1")

        cli_action("onevm terminate --hard #{vm_id}")
        vm.done?
    end

    it "create VM with persistent immutable datablock" do
        # Create persistent immutable datablock
        @info[:pers_img] = cli_create("oneimage create " <<
                "--name pers-datablock_1 --size 1 --format raw " <<
                "--type datablock -d 1 --persistent")

        # Set immutable flag
        cli_update("oneimage update #{@info[:pers_img]}",
                   "PERSISTENT_TYPE=\"immutable\"",
                   true)

        # Add disk to template
        tmpl_disk = <<-EOF
            DISK=[
                IMAGE="#{@info[:image]}"
            ]
            DISK=[
                IMAGE_ID="#{@info[:pers_img]}"
            ]
        EOF

        cli_update("onetemplate update tmpl_iotune", tmpl_disk, true)

        # Instantiate VM and try to write data to immutable disk
        vm_id = cli_create("onetemplate instantiate tmpl_iotune")
        vm    = VM.new(vm_id)

        vm.running?
        vm.get_ip
        vm.reachable?

        cmd = vm.ssh("echo immutable >/dev/sda")

        cmd.expect_fail

        cli_action("onevm terminate --hard #{vm_id}")
        vm.done?
    end

    it "create 2 VMs with persistent shareable datablock" do
        xml_image = cli_action_xml("oneimage show #{@info[:pers_img]} -x", true)
        image_format = xml_image['FORMAT']

        skip 'Not supported image format' if (image_format != "raw")
        skip "Not supported on #{@info[:tm_mad]} TM_MAD" if (['fs_lvm', 'fs_lvm_ssh', 'ssh', 'local'].include?(@info[:tm_mad]))
        skip "Not supported on #{@info[:image_tm_mad]} TM_MAD_SYSTEM" if (['ssh', 'local'].include?(@info[:image_tm_mad]))

        # Change immutable flag from previous test to shareable
        cli_update("oneimage update #{@info[:pers_img]}",
                   "PERSISTENT_TYPE=\"shareable\"",
                   true)

        # Add disk to template
        tmpl_disk = <<-EOF
            DISK=[
                IMAGE="#{@info[:image]}"
            ]
            DISK=[
                IMAGE_ID="#{@info[:pers_img]}"
            ]
        EOF

        cli_update("onetemplate update tmpl_iotune", tmpl_disk, true)

        # Instantiate 2 VMs
        vm1_id = cli_create("onetemplate instantiate tmpl_iotune")
        vm1    = VM.new(vm1_id)

        vm2_id = cli_create("onetemplate instantiate tmpl_iotune")
        vm2    = VM.new(vm2_id)

        # Write data to first VM shareable disk
        vm1.running?
        vm1.get_ip
        vm1.reachable?

        cmd1 = vm1.ssh("echo shared_data >/dev/sda")

        cmd1.expect_success

        # Read data from second VM shareable disk
        vm2.running?
        vm2.get_ip
        vm2.reachable?

        cmd2 = vm2.ssh("cat /dev/sda")

        cmd2.expect_success

        expect(cmd2.stdout.strip).to eq("shared_data")

        # Cleanup
        cli_action("onevm terminate --hard #{vm1_id}")
        cli_action("onevm terminate --hard #{vm2_id}")
        vm1.done?
        vm2.done?
    end

    it "create 2 VMs and attach shareable persistent datablock" do
        xml_image = cli_action_xml("oneimage show #{@info[:pers_img]} -x", true)
        image_format = xml_image['FORMAT']

        skip 'Not supported image format' if (image_format != "raw")
        skip "Not supported on #{@info[:tm_mad]} TM_MAD" if (['fs_lvm', 'fs_lvm_ssh', 'ssh', 'local'].include?(@info[:tm_mad]))
        skip "Not supported on #{@info[:image_tm_mad]} TM_MAD_SYSTEM" if (['ssh', 'local'].include?(@info[:image_tm_mad]))

        # Add disk to template
        tmpl_disk = <<-EOF
            DISK=[
                IMAGE="#{@info[:image]}"
            ]
        EOF

        cli_update("onetemplate update tmpl_iotune", tmpl_disk, true)

        # Instantiate two VMs
        vm1_id = cli_create("onetemplate instantiate tmpl_iotune")
        vm1    = VM.new(vm1_id)

        vm2_id = cli_create("onetemplate instantiate tmpl_iotune")
        vm2    = VM.new(vm2_id)

        # Attach shareable disk to first and write data
        vm1.running?

        cli_action("onevm disk-attach #{vm1_id} -i #{@info[:pers_img]}")

        vm1.running?
        vm1.get_ip
        vm1.reachable?

        cmd1 = vm1.ssh("echo shared_data >/dev/sda")

        cmd1.expect_success

        # Attach shareable disk to second and read data
        vm2.running?

        cli_action("onevm disk-attach #{vm2_id} -i #{@info[:pers_img]}")

        vm2.running?
        vm2.get_ip
        vm2.reachable?

        # Randomly (when parent host is under load) vm2 sometimes fails to detect disk attachment
        cmd2 = vm2.ssh('echo "- - -" > /sys/class/scsi_host/host0/scan; ' <<
                       'echo "- - -" > /sys/class/scsi_host/host1/scan; ' <<
                       'echo "- - -" > /sys/class/scsi_host/host2/scan')

        cmd2 = vm2.ssh("cat /dev/sda")

        cmd2.expect_success

        expect(cmd2.stdout.strip).to eq("shared_data")

        # Cleanup
        cli_action("onevm terminate --hard #{vm1_id}")
        cli_action("onevm terminate --hard #{vm2_id}")
        vm1.done?
        vm2.done?
    end

    it "create a VM with over 26 disks using virtio" do
        # Create 1MB datablock
        @info[:tiny_image] = cli_create("oneimage create " <<
                "--name tiny-datablock_1 --size 1 --format raw " <<
                "--type datablock -d 1 --prefix vd")
        wait_loop do
            xml = cli_action_xml("oneimage show -x #{@info[:tiny_image]}")
            Image::IMAGE_STATES[xml['STATE'].to_i] == 'READY'
        end

        # Add disk to template
        template = <<-EOF
            NAME=tmpl_27disk
            CPU=1
            MEMORY=128
        EOF
        27.times do |i|
            template += <<-EOF
                DISK=[
                    IMAGE_ID="#{@info[:tiny_image]}"
                ]
            EOF
        end

        @info[:templ27] = cli_create("onetemplate create", template, true)

        # Instantiate VM
        vm_id = cli_create("onetemplate instantiate #{@info[:templ27]}")
        vm    = VM.new(vm_id)

        vm.running?

        cli_action("onevm terminate --hard #{vm_id}")
        vm.done?
    end

    it "creates a VM with 27 disks using virtio-scsi" do
        # Update image prefix
        image_tmpl = <<-EOF
            DEV_PREFIX=sd
        EOF

        cli_update("oneimage update #{@info[:tiny_image]}", image_tmpl, true)

        # Instantiate VM
        vm_id = cli_create("onetemplate instantiate #{@info[:templ27]}")
        vm    = VM.new(vm_id)

        vm.running?

        cli_action("onevm terminate --hard #{vm_id}")
        vm.done?
    end

    it "creates a VM with 27 disks using SATA" do
        # Update image prefix
        image_tmpl = <<-EOF
            DEV_PREFIX=hd
        EOF

        cli_update("oneimage update #{@info[:tiny_image]}", image_tmpl, true)

        template = 'OS = [ MACHINE = "q35" ]'

        cli_update("onetemplate update #{@info[:templ27]}", template, true)

        # Instantiate VM
        vm_id = cli_create("onetemplate instantiate #{@info[:templ27]}")
        vm    = VM.new(vm_id)

        vm.running?

        cli_action("onevm terminate --hard #{vm_id}")
        vm.done?
    end
end
