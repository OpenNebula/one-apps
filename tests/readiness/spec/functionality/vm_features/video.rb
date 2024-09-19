#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
require 'fileutils'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "VirtualMachine VIDEO section test" do
  prepend_before(:all) do
    @defaults_yaml = File.join(File.dirname(__FILE__), 'defaults.yaml')

    # Copy kvm config file with test configuration
    driver_file_src = File.join(File.dirname(__FILE__), "vmm_exec_kvm_tests.conf")
    @driver_file_dst = File.join(ONE_ETC_LOCATION, "vmm_exec/vmm_exec_kvm_tests.conf")
    FileUtils.cp(driver_file_src, @driver_file_dst)
  end

  before(:all) do
    @hid = cli_create("onehost create host01 --im dummy --vm dummy_kvm")

    cli_update("onedatastore update system", "TM_MAD=dummy\nDS_MAD=dummy", false)
    cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)

    @info = {}
    @tmpl = <<-EOF
        NAME = testvm1
        CPU  = 1
        MEMORY = 128
        VIDEO = [
          IOMMU = "YES",
          ATS = "YES",
          RESOLUTION = "1280x720",
          TYPE = "virtio",
          VRAM = "131072"
        ]
    EOF
  end

  after(:all) do
    FileUtils.rm(Dir.glob('/tmp/opennebula_dummy_actions/*'), force: true)

    vm = VM.new(@info[:vmid])

    cli_action("onevm recover --delete #{@info[:vmid]}") if vm.state != 'DONE'
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "should allocate a VirtualMachine that defines a VIDEO section" <<
  " with all options enabled and check all values are present" do
    @info[:vmid] = cli_create("onevm create", @tmpl)
    cli_action("onevm deploy #{@info[:vmid]} #{@hid}")
    
    vm = VM.new(@info[:vmid])
    vm.running?
    
    xml = vm.info
    
    expect(xml["TEMPLATE/VIDEO/IOMMU"]).to eql("YES")
    expect(xml["TEMPLATE/VIDEO/ATS"]).to eql("YES")
    expect(xml["TEMPLATE/VIDEO/RESOLUTION"]).to eql("1280x720")
    expect(xml["TEMPLATE/VIDEO/TYPE"]).to eql("virtio")
    expect(xml["TEMPLATE/VIDEO/VRAM"]).to eql("131072")
  end

  it "should allocate a VirtualMachine that defined a VIDEO section" <<
  " with all options enabled, and check the deployment file" do
    @info[:vmid] = cli_create("onevm create", @tmpl)
    cli_action("onevm deploy #{@info[:vmid]} #{@hid}")
    
    vm = VM.new(@info[:vmid])
    vm.running?
    
    dep_file = File.open(File.join(ONE_VAR_LOCATION, "vms/#{@info[:vmid]}/deployment.0")).read()

    expect(dep_file).to match(/<video>/)
    expect(dep_file).to match(/<driver iommu='on' ats='on'\/>/)
    expect(dep_file).to match(/<model type='virtio' vram='131072'>/)
    expect(dep_file).to match(/<resolution x='1280' y='720'\/>/)
  end

  it "should try to update the VirtualMachine with invalid value" <<
  " for TYPE" do
    @tmpl = <<-EOF
        NAME = testvm1
        CPU  = 1
        MEMORY = 128
        VIDEO = [ TYPE="baddriver" ]
    EOF
    rc = cli_update("onevm updateconf #{@info[:vmid]}", @tmpl, false, false)

    expect(rc.stderr).to match(/Invalid video TYPE/)
  end

  it "should try to update the VirtualMachine with invalid value" <<
  " for RESOLUTION" do
    @tmpl = <<-EOF
        NAME = testvm1
        CPU  = 1
        MEMORY = 128
        VIDEO = [
          TYPE="virtio",
          RESOLUTION="1920*1080"
        ]
    EOF
    rc = cli_update("onevm updateconf #{@info[:vmid]}", @tmpl, false, false)

    expect(rc.stderr).to match(/Invalid RESOLUTION string format/)
  end

  it "should try to update the VirtualMachine with invalid value" <<
  " for VRAM" do
    @tmpl = <<-EOF
        NAME = testvm1
        CPU  = 1
        MEMORY = 128
        VIDEO = [
          TYPE="virtio",
          RESOLUTION="1920x1080",
          VRAM="128"
        ]
    EOF
    rc = cli_update("onevm updateconf #{@info[:vmid]}", @tmpl, false, false)

    expect(rc.stderr).to match(/Invalid VRAM value in VIDEO attribute/)
  end

  it "should try to allocate a VirtualMachine that defines a VIDEO" <<
  " section without a TYPE, should fail" do
    @tmpl = <<-EOF
        NAME = testvm2
        CPU  = 1
        MEMORY = 128
        VIDEO = [
          RESOLUTION="1920x1080"
        ]
    EOF
    rc = cli_create("onevm create", @tmpl, expected_result = false)

    expect(rc.stderr).to match(/Video TYPE is required/)
  end

  it "should try to allocate a VirtualMachine that defines a VIDEO" <<
  " section with invalid type, should fail" do
    @tmpl = <<-EOF
        NAME = testvm2
        CPU  = 1
        MEMORY = 128
        VIDEO = [
          TYPE = "baddriver"
        ]
    EOF
    rc = cli_create("onevm create", @tmpl, expected_result = false)

    expect(rc.stderr).to match(/Invalid video TYPE/)
  end

  it "should try to allocate a VirtualMachine that defined a wrong" <<
  " resolution format" do
    @tmpl = <<-EOF
        NAME = testvm2
        CPU  = 1
        MEMORY = 128
        VIDEO = [
          TYPE="virtio",
          RESOLUTION="1920*1080"
        ]
    EOF
    rc = cli_create("onevm create", @tmpl, expected_result = false)

    expect(rc.stderr).to match(/Invalid RESOLUTION string format/)
  end

  it "should try to allocate a VirtualMachine that defined a wrong" <<
  " VRAM value, too low" do
    @tmpl = <<-EOF
        NAME = testvm2
        CPU  = 1
        MEMORY = 128
        VIDEO = [
          TYPE="vga",
          VRAM="128"
        ]
    EOF
    rc = cli_create("onevm create", @tmpl, expected_result = false)

    expect(rc.stderr).to match(/Invalid VRAM value in VIDEO attribute/)
  end

  it "should try to allocate a VirtualMachine that defined a wrong" <<
  " VRAM value, invalid" do
    @tmpl = <<-EOF
        NAME = testvm2
        CPU  = 1
        MEMORY = 128
        VIDEO = [
          TYPE="vga",
          VRAM="abc"
        ]
    EOF
    rc = cli_create("onevm create", @tmpl, expected_result = false)

    expect(rc.stderr).to match(/Invalid VRAM value in VIDEO attribute/)
  end
end