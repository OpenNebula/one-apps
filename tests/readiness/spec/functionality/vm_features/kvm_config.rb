#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
require 'fileutils'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "VirtualMachine default attributes section test" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml = File.join(File.dirname(__FILE__), 'defaults.yaml')

        # Copy kvm config file with test configuration
        driver_file_src = File.join(File.dirname(__FILE__), "vmm_exec_kvm_tests.conf")
        @driver_file_dst = File.join(ONE_ETC_LOCATION, "vmm_exec/vmm_exec_kvm_tests.conf")
        FileUtils.cp(driver_file_src, @driver_file_dst)
    end

    before(:all) do
        @host_id = cli_create("onehost create localhost --vm dummy_kvm --im dummy")

        mads = "TM_MAD=dummy\nDS_MAD=dummy"
        cli_update("onedatastore update default", mads, false)
        cli_update("onedatastore update system", mads, false)

        # create vm template
        template = <<-EOF
            NAME        = test_template
            CPU         = 2
            MEMORY      = 128
            GRAPHICS    = [ type = "spice" ]
            DISK        = [ target = "hda", type = "FS", size = "1" ]
            NIC         = [ nic_id = "0", ip = "localhost" ]
        EOF
        @template_id = cli_create("onetemplate create", template)
      end

    after(:each) do |test_case|
        cli_action("onevm recover --delete #{@id}") unless test_case.metadata[:avoid_cleaning]
    end

    after(:all) do
        cli_action("onetemplate delete #{@template_id}")
        cli_action("onehost delete #{@host_id}")
        File.delete(@driver_file_dst)
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    it "should use defaults from config file" do
        @id = cli_create("onetemplate instantiate #{@template_id}")
        cli_action("onevm deploy #{@id} #{@host_id}")

        vm = VM.new(@id)
        vm.running?

        dep_file = File.open(File.join(ONE_VAR_LOCATION, "vms/#{@id}/deployment.0")).read()

        expect(dep_file).to match(/arch_f/)
        expect(dep_file).to match(/arch_f/)
        expect(dep_file).to match(/machine_f/)
        expect(dep_file).to match(/kernel_f/)
        expect(dep_file).to match(/initrd_f/)
        #expect(dep_file).to match(/bootloader_f/)
        expect(dep_file).to match(/root_f/)
        expect(dep_file).to match(/kernel_cmd_f/)
        expect(dep_file).to match(/host/)
        expect(dep_file).to match(/pae/)
        expect(dep_file).to match(/acpi/)
        expect(dep_file).to match(/apic/)
        expect(dep_file).to match(/hyperv_f/)
        expect(dep_file).to match(/guest_agent/)
        expect(dep_file).to match(/type='raw'/) # Driver for FS type is 'raw'
        expect(dep_file).to match(/disk_cache_f/)
        expect(dep_file).to match(/nic_filter_f/)
        expect(dep_file).to match(/nic_model_f/)
        expect(dep_file).to match(/raw_f/)
        expect(dep_file).to match(/vcpu.*1/)
        expect(dep_file).to match(/emulator.*\/custom\/path\/1/)
        expect(dep_file).to match(/spice_f/)
        expect(dep_file).to match(/graphics.*passwd/)
    end

    it "should use cluster defaults" do
        # Set cpu_model to cluster
        template = <<-EOF
            OS          = [ ARCH = "arch_c",
                            MACHINE = "machine_c",
                            KERNEL = "kernel_c",
                            INITRD = "initrd_c",
                            BOOTLOADER = "bootloader_c",
                            ROOT = "root_c",
                            KERNEL_CMD = "kernel_cmd_c" ]
            CPU_MODEL   = [ MODEL = "cpu_model_c" ]
            FEATURES    = [ PAE = "no", ACPI = "no", APIC = "no", HYPERV = "yes",
                            GUEST_AGENT = "no", VIRTIO_SCSI_QUEUES = "1" ]
            DISK        = [ driver = "disk_driver_c" , cache = "disk_cache_c"]
            NIC         = [ filter = "nic_filter_c", model = "nic_model_c" ]
            GRAPHICS    = [ random_passwd = 'NO' ]
            RAW         = "<tests name='raw_c'/>"
            VCPU        = 2
            EMULATOR    = "/custom/path/2"
            HYPERV_OPTIONS  = "<relaxed state='hyperv_c'/>"
            SPICE_OPTIONS   = "<video><model type='spice_c'/></video>"
        EOF
        cli_update("onecluster update 0", template, true);  # Use default cluster

        @id = cli_create("onetemplate instantiate #{@template_id}")
        cli_action("onevm deploy #{@id} #{@host_id}")

        vm = VM.new(@id)
        vm.running?

        dep_file = File.open(File.join(ONE_VAR_LOCATION, "vms/#{@id}/deployment.0")).read()

        expect(dep_file).to match(/arch_c/)
        expect(dep_file).to match(/machine_c/)
        expect(dep_file).to match(/kernel_c/)
        expect(dep_file).to match(/initrd_c/)
        #expect(dep_file).to match(/bootloader_c/)
        expect(dep_file).to match(/root_c/)
        expect(dep_file).to match(/kernel_cmd_c/)
        expect(dep_file).to match(/cpu_model_c/)
        expect(dep_file).not_to match(/pae/)
        expect(dep_file).not_to match(/acpi/)
        expect(dep_file).not_to match(/apic/)
        expect(dep_file).to match(/hyperv_c/)
        expect(dep_file).not_to match(/guest_agent/)
        expect(dep_file).to match(/type='raw'/) # Driver for FS type is 'raw'
        expect(dep_file).to match(/disk_cache_c/)
        expect(dep_file).to match(/nic_filter_c/)
        expect(dep_file).to match(/nic_model_c/)
        expect(dep_file).to match(/raw_c/)
        expect(dep_file).to match(/vcpu.*2/)
        expect(dep_file).to match(/emulator.*\/custom\/path\/2/)
        expect(dep_file).to match(/spice_c/)
        expect(dep_file).not_to match(/graphics.*passwd/)
    end

    it "should use host defaults" do
        # We still use cluster from previous test, host value should take precedence
        template = <<-EOF
            OS          = [ ARCH = "arch_h",
                            MACHINE = "machine_h",
                            KERNEL = "kernel_h",
                            INITRD = "initrd_h",
                            BOOTLOADER = "bootloader_h",
                            ROOT = "root_h",
                            KERNEL_CMD = "kernel_cmd_h" ]
            CPU_MODEL   = [ MODEL = "cpu_model_h" ]
            FEATURES    = [ PAE = "yes", ACPI = "yes", APIC = "yes", HYPERV = "yes",
                            GUEST_AGENT = "yes", VIRTIO_SCSI_QUEUES = "2" ]
            DISK        = [ driver = "disk_driver_h" , cache = "disk_cache_h"]
            NIC         = [ filter = "nic_filter_h", model = "nic_model_h" ]
            GRAPHICS    = [ passwd = "secret_password" ]
            RAW         = "<tests name='raw_h'/>"
            VCPU        = 3
            EMULATOR    = "/custom/path/3"
            HYPERV_OPTIONS  = "<relaxed state='hyperv_h'/>"
            SPICE_OPTIONS   = "<video><model type='spice_h'/></video>"
        EOF
        cli_update("onehost update #{@host_id}", template, true);

        @id = cli_create("onetemplate instantiate #{@template_id}")
        cli_action("onevm deploy #{@id} #{@host_id}")

        vm = VM.new(@id)
        vm.running?

        dep_file = File.open(File.join(ONE_VAR_LOCATION, "vms/#{@id}/deployment.0")).read()
        expect(dep_file).to match(/arch_h/)
        expect(dep_file).to match(/machine_h/)
        expect(dep_file).to match(/kernel_h/)
        expect(dep_file).to match(/initrd_h/)
        #expect(dep_file).to match(/bootloader_h/)
        expect(dep_file).to match(/root_h/)
        expect(dep_file).to match(/kernel_cmd_h/)
        expect(dep_file).to match(/cpu_model_h/)
        expect(dep_file).to match(/pae/)
        expect(dep_file).to match(/acpi/)
        expect(dep_file).to match(/apic/)
        expect(dep_file).to match(/hyperv_h/)
        expect(dep_file).to match(/guest_agent/)
        expect(dep_file).to match(/type='raw'/) # Driver for FS is 'raw'
        expect(dep_file).to match(/disk_cache_h/)
        expect(dep_file).to match(/nic_filter_h/)
        expect(dep_file).to match(/nic_model_h/)
        expect(dep_file).to match(/raw_h/)
        expect(dep_file).to match(/vcpu.*3/)
        expect(dep_file).to match(/emulator.*\/custom\/path\/3/)
        expect(dep_file).to match(/spice_h/)
        expect(dep_file).to match(/graphics.*passwd.*secret_password/)
    end

    it "should use VMTemplate attributes" do
        # Cluster and Host attributes are still set, VM template should take precedence
        template = <<-EOF
            OS          = [ ARCH = "arch_vm",
                            MACHINE = "machine_vm",
                            KERNEL = "kernel_vm",
                            INITRD = "initrd_vm",
                            BOOTLOADER = "bootloader_vm",
                            ROOT = "root_vm",
                            KERNEL_CMD = "kernel_cmd_vm" ]
            CPU_MODEL   = [ MODEL = "cpu_model_vms" ]
            FEATURES    = [ PAE = "no", ACPI = "no", APIC = "no", HYPERV = "yes",
                            GUEST_AGENT = "no", VIRTIO_SCSI_QUEUES = "3" ]
            DISK        = [ target = "hda", type = "FS", size = "32", driver = "disk_driver_vm", cache = "disk_cache_vm"]
            NIC         = [ nic_id = "0", ip = "localhost", filter = "nic_filter_vm", model = "nic_model_vm" ]
            GRAPHICS    = [ type = "spice", passwd = "new_password" ]
            RAW         = [ type = "KVM", data = "<devices><serial type='pty'><source path='/dev/pts/5'/><target port='0'/></serial><console type='pty' tty='/dev/pts/5'><source path='/dev/pts/5'/><target port='0'/></console></devices>" ]
            VCPU        = 4
            EMULATOR    = "/custom/path/4"
            HYPERV_OPTIONS  = "<relaxed state='hyperv_vm'/>"
            SPICE_OPTIONS   = "<video><model type='spice_vm'/></video>"
        EOF
        cli_update("onetemplate update #{@template_id}", template, true);

        @id = cli_create("onetemplate instantiate #{@template_id}")
        cli_action("onevm deploy #{@id} #{@host_id}")

        vm = VM.new(@id)
        vm.running?

        dep_file = File.open(File.join(ONE_VAR_LOCATION, "vms/#{@id}/deployment.0")).read()
        expect(dep_file).to match(/arch_vm/)
        expect(dep_file).to match(/machine_vm/)
        expect(dep_file).to match(/kernel_vm/)
        expect(dep_file).to match(/initrd_vm/)
        #expect(dep_file).to match(/bootloader_vm/)
        expect(dep_file).to match(/root_vm/)
        expect(dep_file).to match(/kernel_cmd_vm/)
        expect(dep_file).to match(/cpu_model_vms/)
        expect(dep_file).not_to match(/pae/)
        expect(dep_file).not_to match(/acpi/)
        expect(dep_file).not_to match(/apic/)
        expect(dep_file).to match(/hyperv_vm/)
        expect(dep_file).not_to match(/guest_agent/)
        expect(dep_file).to match(/type='raw'/) # Driver for FS is 'raw'
        expect(dep_file).to match(/disk_cache_vm/)
        expect(dep_file).to match(/nic_filter_vm/)
        expect(dep_file).to match(/nic_model_vm/)
        expect(dep_file).to match(/raw_h/)
        expect(dep_file).to match(/<devices>.*<\/devices>/)
        expect(dep_file).to match(/vcpu.*4/)
        expect(dep_file).to match(/emulator.*\/custom\/path\/4/)
        expect(dep_file).to match(/spice_vm/)
        expect(dep_file).to match(/graphics.*passwd.*new_password/)
    end

    it "should fails when updating a VMTemplate with invalid RAW", :avoid_cleaning do
        # Cluster and Host attributes are still set, VM template should take precedence
        template = <<-EOF
            OS          = [ ARCH = "arch_vm",
                            MACHINE = "machine_vm",
                            KERNEL = "kernel_vm",
                            INITRD = "initrd_vm",
                            BOOTLOADER = "bootloader_vm",
                            ROOT = "root_vm",
                            KERNEL_CMD = "kernel_cmd_vm" ]
            CPU_MODEL   = [ MODEL = "cpu_model_vms" ]
            FEATURES    = [ PAE = "no", ACPI = "no", APIC = "no", HYPERV = "yes",
                            GUEST_AGENT = "no", VIRTIO_SCSI_QUEUES = "3" ]
            DISK        = [ target = "hda", type = "FS", size = "32", cache = "disk_cache_vm"]
            NIC         = [ nic_id = "0", ip = "localhost", filter = "nic_filter_vm", model = "nic_model_vm" ]
            RAW         = [ type = "KVM", data = "<tests name='raw_h'/>" ]
            VCPU        = 4
            EMULATOR    = "/custom/path/4"
            HYPERV_OPTIONS  = "<relaxed state='hyperv_vm'/>"
            SPICE_OPTIONS   = "<video><model type='spice_vm'/></video>"
        EOF

        cli_update("onetemplate update #{@template_id}", template, true, false);
    end

    it "should update invalid RAW with VALIDATE=no", :avoid_cleaning do
        # Cluster and Host attributes are still set, VM template should take precedence
        template = <<-EOF
            OS          = [ ARCH = "arch_vm",
                            MACHINE = "machine_vm",
                            KERNEL = "kernel_vm",
                            INITRD = "initrd_vm",
                            BOOTLOADER = "bootloader_vm",
                            ROOT = "root_vm",
                            KERNEL_CMD = "kernel_cmd_vm" ]
            CPU_MODEL   = [ MODEL = "cpu_model_vms" ]
            FEATURES    = [ PAE = "no", ACPI = "no", APIC = "no", HYPERV = "yes",
                            GUEST_AGENT = "no", VIRTIO_SCSI_QUEUES = "3" ]
            DISK        = [ target = "hda", type = "FS", size = "32", cache = "disk_cache_vm"]
            NIC         = [ nic_id = "0", ip = "localhost", filter = "nic_filter_vm", model = "nic_model_vm" ]
            RAW         = [ type = "KVM", validate = "no", data = "<tests name='raw_h'/>" ]
            VCPU        = 4
            EMULATOR    = "/custom/path/4"
            HYPERV_OPTIONS  = "<relaxed state='hyperv_vm'/>"
            SPICE_OPTIONS   = "<video><model type='spice_vm'/></video>"
        EOF

        cli_update("onetemplate update #{@template_id}", template, true);
    end
end
