#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'

DEFAULT_LIMIT = "-1"

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Check generic quotas" do

  prepend_before(:all) do
    @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
  end

  before(:all) do
    cli_update('onedatastore update default', "TM_MAD=dummy\nDS_MAD=dummy", false)
    cli_update('onedatastore update system', "TM_MAD=dummy\nDS_MAD=dummy", false)

    cli_create_user('uA', 'abc')
    cli_create_user('uB', 'abc')

    cli_create('onegroup create gA')
    cli_create('onegroup create gB')
    cli_action('oneuser chgrp uA gA')
    cli_action('oneuser chgrp uB gB')

    cli_create('onehost create host0 --im dummy --vm dummy')

    @img_id = cli_create('oneimage create --name test_img --size 100 '\
                         '--type datablock --no_check_capacity -d default')

    tmpl = <<-EOT
      NAME = "test_vm"
      MEMORY = 1024
      CPU = 1
      VCPU = 1
      LICENSE = 1
    EOT

    @tmpl_id = cli_create('onetemplate create', tmpl)

    cli_action("onetemplate chown #{@tmpl_id} uA gA")
  end

  before(:each) do
    as_user('uA') do
      @vm_id = cli_create("onetemplate instantiate #{@tmpl_id}")
    end
  end

  after(:each) do
    FileUtils.rm_r(Dir['/tmp/opennebula_dummy_actions/*'])

    cli_action("onevm recover --delete #{@vm_id}") unless @vm_id.nil?
  end

  def check_quota(cpu, running_cpu, vcpu, running_vcpu, license, running_license)
    uxml = cli_action_xml('oneuser show -x uA')

    expect(uxml['VM_QUOTA/VM/CPU']).to eql('10')
    expect(uxml['VM_QUOTA/VM/CPU_USED']).to eql(cpu.to_s)
    expect(uxml['VM_QUOTA/VM/RUNNING_CPU']).to eql('8')
    expect(uxml['VM_QUOTA/VM/RUNNING_CPU_USED']).to eql(running_cpu.to_s)
    expect(uxml['VM_QUOTA/VM/VCPU']).to eql('5')
    expect(uxml['VM_QUOTA/VM/VCPU_USED']).to eql(vcpu.to_s)
    expect(uxml['VM_QUOTA/VM/RUNNING_VCPU']).to eql('4')
    expect(uxml['VM_QUOTA/VM/RUNNING_VCPU_USED']).to eql(running_vcpu.to_s)
    expect(uxml['VM_QUOTA/VM/LICENSE']).to eql('3')
    expect(uxml['VM_QUOTA/VM/LICENSE_USED']).to eql(license.to_s)
    expect(uxml['VM_QUOTA/VM/RUNNING_LICENSE']).to eql('2')
    expect(uxml['VM_QUOTA/VM/RUNNING_LICENSE_USED']).to eql(running_license.to_s)

    gxml = cli_action_xml('onegroup show -x gA')

    expect(gxml['VM_QUOTA/VM/CPU']).to eql('10')
    expect(gxml['VM_QUOTA/VM/CPU_USED']).to eql(cpu.to_s)
    expect(gxml['VM_QUOTA/VM/RUNNING_CPU']).to eql('8')
    expect(gxml['VM_QUOTA/VM/RUNNING_CPU_USED']).to eql(running_cpu.to_s)
    expect(gxml['VM_QUOTA/VM/VCPU']).to eql('5')
    expect(gxml['VM_QUOTA/VM/VCPU_USED']).to eql(vcpu.to_s)
    expect(gxml['VM_QUOTA/VM/RUNNING_VCPU']).to eql('4')
    expect(gxml['VM_QUOTA/VM/RUNNING_VCPU_USED']).to eql(running_vcpu.to_s)
    expect(gxml['VM_QUOTA/VM/LICENSE']).to eql('3')
    expect(gxml['VM_QUOTA/VM/LICENSE_USED']).to eql(license.to_s)
    expect(gxml['VM_QUOTA/VM/RUNNING_LICENSE']).to eql('2')
    expect(gxml['VM_QUOTA/VM/RUNNING_LICENSE_USED']).to eql(running_license.to_s)
  end

  #---------------------------------------------------------------------------
  # Test all actions which can modify the generic quotas
  #---------------------------------------------------------------------------

  it "should set a limit for VM generic quota" do
    quota = <<-EOT
      VM = [
        CPU = 10,
        RUNNING_CPU = 8,
        VCPU = 5,
        RUNNING_VCPU = 4,
        LICENSE = 3,
        RUNNING_LICENSE = 2
      ]
    EOT

    cli_update('oneuser quota uA', quota, false)
    cli_update('onegroup quota gA', quota, false)

    check_quota(1, 1, 1, 1, 1, 1)
  end

  it "should be visible for user in the CLI" do
    as_user('uA') do
      result = cli_action('oneuser show uA')

      expect(result.stdout).to match(/VCPU/)
      expect(result.stdout).to match(/LICENSE/)
    end
  end

  it "fail to create a VM with generic quota attribute" do
    as_user('uA') do
      tmpl = <<-EOT
        NAME = "test_vm2"
        MEMORY = 1024
        CPU = 1
        VCPU = 1
        LICENSE = -10
      EOT

      cli_create("onevm create", tmpl, false)
    end
  end

  it "should not allow a user to create a VM if generic quota is exceeded for template attribute" do
    as_user('uA') do
      tmpl = <<-EOT
        NAME = "test_vm3"
        MEMORY = 1024
        CPU = 1
        VCPU = 5
      EOT

      cli_create('onevm create', tmpl, false)

      check_quota(1, 1, 1, 1, 1, 1)
    end
  end

  it "should not allow a user to create a VM if generic quota is exceeded for user template attribute" do
    as_user('uA') do
      tmpl = <<-EOT
        NAME = "test_vm4"
        MEMORY = 1024
        CPU = 1
        VCPU = 1
        LICENSE = 2
      EOT

      cli_create('onevm create', tmpl, false)

      check_quota(1, 1, 1, 1, 1, 1)
    end
  end

  it "chown should update quotas" do
    cli_action("onevm chown #{@vm_id} uB")

    uxml = cli_action_xml('oneuser show -x uA')

    expect(uxml['VM_QUOTA/VM/CPU']).to eql('10')
    expect(uxml['VM_QUOTA/VM/CPU_USED']).to eql('0')
    expect(uxml['VM_QUOTA/VM/RUNNING_CPU']).to eql('8')
    expect(uxml['VM_QUOTA/VM/RUNNING_CPU_USED']).to eql('0')
    expect(uxml['VM_QUOTA/VM/VCPU']).to eql('5')
    expect(uxml['VM_QUOTA/VM/VCPU_USED']).to eql('0')
    expect(uxml['VM_QUOTA/VM/RUNNING_VCPU']).to eql('4')
    expect(uxml['VM_QUOTA/VM/RUNNING_VCPU_USED']).to eql('0')
    expect(uxml['VM_QUOTA/VM/LICENSE']).to eql('3')
    expect(uxml['VM_QUOTA/VM/LICENSE_USED']).to eql('0')
    expect(uxml['VM_QUOTA/VM/RUNNING_LICENSE']).to eql('2')
    expect(uxml['VM_QUOTA/VM/RUNNING_LICENSE_USED']).to eql('0')

    uxml = cli_action_xml('oneuser show -x uB')

    expect(uxml['VM_QUOTA/VM/CPU']).to eql(DEFAULT_LIMIT)
    expect(uxml['VM_QUOTA/VM/CPU_USED']).to eql('1')
    expect(uxml['VM_QUOTA/VM/RUNNING_CPU']).to eql(DEFAULT_LIMIT)
    expect(uxml['VM_QUOTA/VM/RUNNING_CPU_USED']).to eql('1')
    expect(uxml['VM_QUOTA/VM/VCPU']).to eql(DEFAULT_LIMIT)
    expect(uxml['VM_QUOTA/VM/VCPU_USED']).to eql('1')
    expect(uxml['VM_QUOTA/VM/RUNNING_VCPU']).to eql(DEFAULT_LIMIT)
    expect(uxml['VM_QUOTA/VM/RUNNING_VCPU_USED']).to eql('1')
    expect(uxml['VM_QUOTA/VM/LICENSE']).to eql(DEFAULT_LIMIT)
    expect(uxml['VM_QUOTA/VM/LICENSE_USED']).to eql('1')
    expect(uxml['VM_QUOTA/VM/RUNNING_LICENSE']).to eql(DEFAULT_LIMIT)
    expect(uxml['VM_QUOTA/VM/RUNNING_LICENSE_USED']).to eql('1')
  end

  it "chown in VM transient runnning state should update quotas" do
    File.write('/tmp/opennebula_dummy_actions/disk_snapshot_create', 'success 5');

    cli_action("onevm deploy #{@vm_id} 0")

    vm = VM.new(@vm_id)
    vm.running?

    cli_action("onevm disk-attach #{@vm_id} -i #{@img_id}")
    vm.running?

    cli_action("onevm disk_snapshot-create #{@vm_id} 0 test_snapshot")
    cli_action("onevm chown #{@vm_id} uB")

    uxml = cli_action_xml('oneuser show -x uA')

    expect(uxml['VM_QUOTA/VM/CPU']).to eql('10')
    expect(uxml['VM_QUOTA/VM/CPU_USED']).to eql('0')
    expect(uxml['VM_QUOTA/VM/RUNNING_CPU']).to eql('8')
    expect(uxml['VM_QUOTA/VM/RUNNING_CPU_USED']).to eql('0')
    expect(uxml['VM_QUOTA/VM/VCPU']).to eql('5')
    expect(uxml['VM_QUOTA/VM/VCPU_USED']).to eql('0')
    expect(uxml['VM_QUOTA/VM/RUNNING_VCPU']).to eql('4')
    expect(uxml['VM_QUOTA/VM/RUNNING_VCPU_USED']).to eql('0')
    expect(uxml['VM_QUOTA/VM/LICENSE']).to eql('3')
    expect(uxml['VM_QUOTA/VM/LICENSE_USED']).to eql('0')
    expect(uxml['VM_QUOTA/VM/RUNNING_LICENSE']).to eql('2')
    expect(uxml['VM_QUOTA/VM/RUNNING_LICENSE_USED']).to eql('0')

    uxml = cli_action_xml('oneuser show -x uB')

    expect(uxml['VM_QUOTA/VM/CPU']).to eql(DEFAULT_LIMIT)
    expect(uxml['VM_QUOTA/VM/CPU_USED']).to eql('1')
    expect(uxml['VM_QUOTA/VM/RUNNING_CPU']).to eql(DEFAULT_LIMIT)
    expect(uxml['VM_QUOTA/VM/RUNNING_CPU_USED']).to eql('1')
    expect(uxml['VM_QUOTA/VM/VCPU']).to eql(DEFAULT_LIMIT)
    expect(uxml['VM_QUOTA/VM/VCPU_USED']).to eql('1')
    expect(uxml['VM_QUOTA/VM/RUNNING_VCPU']).to eql(DEFAULT_LIMIT)
    expect(uxml['VM_QUOTA/VM/RUNNING_VCPU_USED']).to eql('1')
    expect(uxml['VM_QUOTA/VM/LICENSE']).to eql(DEFAULT_LIMIT)
    expect(uxml['VM_QUOTA/VM/LICENSE_USED']).to eql('1')
    expect(uxml['VM_QUOTA/VM/RUNNING_LICENSE']).to eql(DEFAULT_LIMIT)
    expect(uxml['VM_QUOTA/VM/RUNNING_LICENSE_USED']).to eql('1')
  end

  it "chown in VM transient poweroff state should update quotas" do
    File.write('/tmp/opennebula_dummy_actions/disk_snapshot_create', 'success 5');

    cli_action("onevm deploy #{@vm_id} 0")

    vm = VM.new(@vm_id)
    vm.running?

    cli_action("onevm disk-attach #{@vm_id} -i #{@img_id}")
    vm.running?

    vm.poweroff

    cli_action("onevm diks-snapshot-create #{@vm_id} 0 test_snapshot")
    cli_action("onevm chown #{@vm_id} uB")

    uxml = cli_action_xml('oneuser show -x uA')

    expect(uxml['VM_QUOTA/VM/CPU']).to eql('10')
    expect(uxml['VM_QUOTA/VM/CPU_USED']).to eql('0')
    expect(uxml['VM_QUOTA/VM/RUNNING_CPU']).to eql('8')
    expect(uxml['VM_QUOTA/VM/RUNNING_CPU_USED']).to eql('0')
    expect(uxml['VM_QUOTA/VM/VCPU']).to eql('5')
    expect(uxml['VM_QUOTA/VM/VCPU_USED']).to eql('0')
    expect(uxml['VM_QUOTA/VM/RUNNING_VCPU']).to eql('4')
    expect(uxml['VM_QUOTA/VM/RUNNING_VCPU_USED']).to eql('0')
    expect(uxml['VM_QUOTA/VM/LICENSE']).to eql('3')
    expect(uxml['VM_QUOTA/VM/LICENSE_USED']).to eql('0')
    expect(uxml['VM_QUOTA/VM/RUNNING_LICENSE']).to eql('2')
    expect(uxml['VM_QUOTA/VM/RUNNING_LICENSE_USED']).to eql('0')

    uxml = cli_action_xml('oneuser show -x uB')

    expect(uxml['VM_QUOTA/VM/CPU']).to eql(DEFAULT_LIMIT)
    expect(uxml['VM_QUOTA/VM/CPU_USED']).to eql('1')
    expect(uxml['VM_QUOTA/VM/RUNNING_CPU']).to eql(DEFAULT_LIMIT)
    expect(uxml['VM_QUOTA/VM/RUNNING_CPU_USED']).to eql('0')
    expect(uxml['VM_QUOTA/VM/VCPU']).to eql(DEFAULT_LIMIT)
    expect(uxml['VM_QUOTA/VM/VCPU_USED']).to eql('1')
    expect(uxml['VM_QUOTA/VM/RUNNING_VCPU']).to eql(DEFAULT_LIMIT)
    expect(uxml['VM_QUOTA/VM/RUNNING_VCPU_USED']).to eql('0')
    expect(uxml['VM_QUOTA/VM/LICENSE']).to eql(DEFAULT_LIMIT)
    expect(uxml['VM_QUOTA/VM/LICENSE_USED']).to eql('1')
    expect(uxml['VM_QUOTA/VM/RUNNING_LICENSE']).to eql(DEFAULT_LIMIT)
    expect(uxml['VM_QUOTA/VM/RUNNING_LICENSE_USED']).to eql('0')
  end

  it "chgrp should update quotas" do
    cli_action("onevm chgrp #{@vm_id} gB")

    gxml = cli_action_xml('onegroup show -x gA')

    expect(gxml['VM_QUOTA/VM/CPU']).to eql('10')
    expect(gxml['VM_QUOTA/VM/CPU_USED']).to eql('0')
    expect(gxml['VM_QUOTA/VM/RUNNING_CPU']).to eql('8')
    expect(gxml['VM_QUOTA/VM/RUNNING_CPU_USED']).to eql('0')
    expect(gxml['VM_QUOTA/VM/VCPU']).to eql('5')
    expect(gxml['VM_QUOTA/VM/VCPU_USED']).to eql('0')
    expect(gxml['VM_QUOTA/VM/RUNNING_VCPU']).to eql('4')
    expect(gxml['VM_QUOTA/VM/RUNNING_VCPU_USED']).to eql('0')
    expect(gxml['VM_QUOTA/VM/LICENSE']).to eql('3')
    expect(gxml['VM_QUOTA/VM/LICENSE_USED']).to eql('0')
    expect(gxml['VM_QUOTA/VM/RUNNING_LICENSE']).to eql('2')
    expect(gxml['VM_QUOTA/VM/RUNNING_LICENSE_USED']).to eql('0')

    gxml = cli_action_xml('onegroup show -x gB')

    expect(gxml['VM_QUOTA/VM/CPU']).to eql(DEFAULT_LIMIT)
    expect(gxml['VM_QUOTA/VM/CPU_USED']).to eql('1')
    expect(gxml['VM_QUOTA/VM/RUNNING_CPU']).to eql(DEFAULT_LIMIT)
    expect(gxml['VM_QUOTA/VM/RUNNING_CPU_USED']).to eql('1')
    expect(gxml['VM_QUOTA/VM/VCPU']).to eql(DEFAULT_LIMIT)
    expect(gxml['VM_QUOTA/VM/VCPU_USED']).to eql('1')
    expect(gxml['VM_QUOTA/VM/RUNNING_VCPU']).to eql(DEFAULT_LIMIT)
    expect(gxml['VM_QUOTA/VM/RUNNING_VCPU_USED']).to eql('1')
    expect(gxml['VM_QUOTA/VM/LICENSE']).to eql(DEFAULT_LIMIT)
    expect(gxml['VM_QUOTA/VM/LICENSE_USED']).to eql('1')
    expect(gxml['VM_QUOTA/VM/RUNNING_LICENSE']).to eql(DEFAULT_LIMIT)
    expect(gxml['VM_QUOTA/VM/RUNNING_LICENSE_USED']).to eql('1')
  end

  it "poweroff should update quotas" do
    cli_action("onevm deploy #{@vm_id} 0")

    vm = VM.new(@vm_id)
    vm.running?

    check_quota(1, 1, 1, 1, 1, 1)

    vm.poweroff

    check_quota(1, 0, 1, 0, 1, 0)

    vm.resume

    check_quota(1, 1, 1, 1, 1, 1)

    vm.poweroff

    check_quota(1, 0, 1, 0, 1, 0)
  end

  it "suspend should update quotas" do
    check_quota(1, 1, 1, 1, 1, 1)

    cli_action("onevm deploy #{@vm_id} 0")

    vm = VM.new(@vm_id)
    vm.running?

    check_quota(1, 1, 1, 1, 1, 1)

    cli_action("onevm suspend #{@vm_id}")

    vm.state?("SUSPENDED")

    check_quota(1, 0, 1, 0, 1, 0)

    vm.resume

    check_quota(1, 1, 1, 1, 1, 1)
  end

  it "undeploy should update quotas" do
    cli_action("onevm deploy #{@vm_id} 0")

    vm = VM.new(@vm_id)
    vm.running?

    check_quota(1, 1, 1, 1, 1, 1);

    cli_action("onevm undeploy #{@vm_id}")

    vm.state?("UNDEPLOYED")

    check_quota(1, 0, 1, 0, 1, 0)

    cli_action("onevm deploy #{@vm_id} 0")
    vm.running?

    check_quota(1, 1, 1, 1, 1, 1)

    # Test Poweroff -> Undeploy
    vm.poweroff

    check_quota(1, 0, 1, 0, 1, 0)

    cli_action("onevm undeploy #{@vm_id}")

    vm.state?("UNDEPLOYED")

    check_quota(1, 0, 1, 0, 1, 0)
  end

  it "stop should update quotas" do
    cli_action("onevm deploy #{@vm_id} 0")

    vm = VM.new(@vm_id)
    vm.running?

    check_quota(1, 1, 1, 1, 1, 1)

    cli_action("onevm stop #{@vm_id}")

    vm.state?("STOPPED")

    check_quota(1, 0, 1, 0, 1, 0)

    cli_action("onevm deploy #{@vm_id} 0")
    vm.running?

    check_quota(1, 1, 1, 1, 1, 1)

    # Suspended -> stop
    cli_action("onevm suspend #{@vm_id}")

    vm.state?("SUSPENDED")

    check_quota(1, 0, 1, 0, 1, 0)

    cli_action("onevm stop #{@vm_id}")

    vm.state?("STOPPED")

    check_quota(1, 0, 1, 0, 1, 0)
  end

  it "resize should update quotas" do
    cli_action("onevm resize --cpu 2 --vcpu 4 #{@vm_id}")

    check_quota(2, 2, 4, 4, 1, 1)

    cli_action("onevm resize --cpu 2 --vcpu 12 #{@vm_id}", false)

    check_quota(2, 2, 4, 4, 1, 1)
  end

  it "update should update quotas" do
    cli_action("onevm deploy #{@vm_id} 0")

    vm = VM.new(@vm_id)

    tmpl = <<-EOT
      LICENSE = 2
    EOT

    cli_update("onevm update #{@vm_id}", tmpl, true)

    check_quota(1, 1, 1, 1, 2, 2)

    # Fail to update, quota exceeded
    tmpl = <<-EOT
      LICENSE = 3
    EOT

    cli_update("onevm update #{@vm_id}", tmpl, true, false)

    check_quota(1, 1, 1, 1, 2, 2)

    as_user('uA') do
      # Fail to update, restricted attribute
      tmpl = <<-EOT
        CPU_COST = 123
        LICENSE = 1
      EOT

      cli_update("onevm update #{@vm_id}", tmpl, true, false)
    end

    check_quota(1, 1, 1, 1, 2, 2)

    # Test update for non-running VM
    vm.poweroff

    tmpl = <<-EOT
      LICENSE = 1
    EOT

    cli_update("onevm update #{@vm_id}", tmpl, true)

    check_quota(1, 0, 1, 0, 1, 0)
  end

  #---------------------------------------------------------------------------
  # Test VM action failures - they should not modify the quota
  #---------------------------------------------------------------------------

  it "failure to instantiate VM should not change quota" do
    tmpl = <<-EOT
      NAME = "test_vm5"
      MEMORY = 1024
      CPU = 1
      VCPU = 1
      LICENSE = 1
      DISK = [
        IMAGE_ID = 11
      ]
    EOT

    tmpl_id = cli_create('onetemplate create', tmpl)

    cli_action("onetemplate chown #{tmpl_id} uA gA")

    as_user('uA') do
        # Fail Image doesn't exist, the failure is after VM quota authorization
      cli_create("onetemplate instantiate #{tmpl_id}", nil, false)

      check_quota(1, 1, 1, 1, 1, 1)
    end
  end

  it "failure to create VM should not change quota" do
    as_user('uA') do
      tmpl = <<-EOT
        NAME = "test_vm6"
        MEMORY = 1024
        CPU = 1
        VCPU = 1
        LICENSE = 1
        DISK = [
          IMAGE_ID = 0
        ]
      EOT

      # Fail Image doesn't exist, the failure is after VM quota authorization
      cli_create('onevm create', tmpl, false)

      check_quota(1, 1, 1, 1, 1, 1)
    end
  end

  it "failure to deploy should not modify the quota" do
    File.write('/tmp/opennebula_dummy_actions/deploy', 'failure');
    cli_action("onevm deploy #{@vm_id} 0")

    vm = VM.new(@vm_id)
    vm.state?("BOOT_FAILURE", "RUNNING")

    check_quota(1, 1, 1, 1, 1, 1)
  end

  it "failure to poweroff/suspend/stop/undeploy should not modify the quota" do
    cli_action("onevm deploy #{@vm_id} 0")

    vm = VM.new(@vm_id)
    vm.running?

    check_quota(1, 1, 1, 1, 1, 1)

    File.write('/tmp/opennebula_dummy_actions/shutdown', 'failure');
    cli_action("onevm poweroff #{@vm_id}")
    vm.running?

    check_quota(1, 1, 1, 1, 1, 1)

    File.write('/tmp/opennebula_dummy_actions/save', 'failure');
    cli_action("onevm suspend #{@vm_id}")
    vm.running?

    check_quota(1, 1, 1, 1, 1, 1)

    cli_action("onevm stop #{@vm_id}")
    vm.running?

    check_quota(1, 1, 1, 1, 1, 1)

    cli_action("onevm undeploy #{@vm_id}")
    vm.running?

    check_quota(1, 1, 1, 1, 1, 1)
  end

  it "failure to update should not modify the quota" do
    cli_action("onevm deploy #{@vm_id} 0")
  end

  #---------------------------------------------------------------------------
  # Test VM action, which should not modify quota
  #---------------------------------------------------------------------------

  def test_vm_actions(vm, running)
    state = nil
    if running > 0
      state = 'RUNNING'
    else
      state = 'POWEROFF'
    end

    cli_action("onevm disk-attach #{@vm_id} -i #{@img_id}")
    vm.state?(state)

    check_quota(1, running, 1, running, 1, running)

    cli_action("onevm disk-resize #{@vm_id} 0 200")
    vm.state?(state)

    check_quota(1, running, 1, running, 1, running)

    cli_action("onevm disk-snapshot-create #{@vm_id} 0 test_disk_snapshot")
    vm.state?(state)

    check_quota(1, running, 1, running, 1, running)

    cli_action("onevm disk-snapshot-delete #{@vm_id} 0 test_disk_snapshot")
    vm.state?(state)

    check_quota(1, running, 1, running, 1, running)

    cli_action("onevm disk-detach #{@vm_id} 0")
    vm.state?(state)

    check_quota(1, running, 1, running, 1, running)

    cli_action("onevm nic-attach #{@vm_id} --network #{@net_id}")
    vm.state?(state)

    check_quota(1, running, 1, running, 1, running)

    cli_action("onevm nic-dettach #{@vm_id} 0")
    vm.state?(state)

    check_quota(1, running, 1, running, 1, running)

    cli_update("onevm update-conf #{@vm_id}", "CPU=2", true)
    vm.state?(state)

    check_quota(1, running, 1, running, 1, running)
  end

  it "several vm actions should not update quota" do
    net_tmpl = <<-EOF
      NAME = test_vnet1
      BRIDGE = br0
      VN_MAD = dummy
      AR=[TYPE = "IP4", IP = "10.0.0.10", SIZE = "100" ]
    EOF

    @net_id = cli_create("onevnet create", net_tmpl)

    cli_action("onevm deploy #{@vm_id} 0")

    vm = VM.new(@vm_id)
    vm.running?

    # VM running - Test VM actions, which should not modify quota
    cli_action("onevm reboot #{@vm_id}")
    vm.running?

    check_quota(1, 1, 1, 1, 1, 1)

    cli_action("onevm snapshot-create #{@vm_id} test_snapshot")
    vm.running?

    check_quota(1, 1, 1, 1, 1, 1)

    cli_action("onevm snapshot-delete #{@vm_id} test_snapshot")
    vm.running?

    check_quota(1, 1, 1, 1, 1, 1)

    test_vm_actions(vm, 1)

    # VM poweroff - Test VM actions, which should not modify quota
    vm.poweroff

    test_vm_actions(vm, 0)
  end

  it "recover action should update quota" do
    File.write('/tmp/opennebula_dummy_actions/deploy', 'failure');
    cli_action("onevm deploy #{@vm_id} 0")

    vm = VM.new(@vm_id)
    vm.state?("BOOT_FAILURE", "RUNNING")

    check_quota(1, 1, 1, 1, 1, 1)

    cli_action("onevm recover --failure #{@vm_id}")

    check_quota(1, 1, 1, 1, 1, 1)

    cli_action("onevm recover --success #{@vm_id}")
    vm.running?

    check_quota(1, 1, 1, 1, 1, 1)

    cli_action("onevm recover --recreate #{@vm_id}")

    check_quota(1, 1, 1, 1, 1, 1)

    cli_action("onevm recover --delete #{@vm_id}")

    check_quota(0, 0, 0, 0, 0, 0)

    @vm_id = cli_create('onetemplate instantiate 0')

    cli_action("onevm recover --delete-db #{@vm_id}")

    check_quota(0, 0, 0, 0, 0, 0)

    @vm_id = nil
  end

  #---------------------------------------------------------------------------
  # Test onedb fsck
  #---------------------------------------------------------------------------

  it "should run fsck" do
    run_fsck
  end

  it "fsck should fix generic quota errors" do
    id = @vm_id

    # Update VM body to corrupt the quota
    cli_action("onedb change-body vm --id #{id} /VM/TEMPLATE/MEMORY 2048")
    cli_action("onedb change-body vm --id #{id} /VM/TEMPLATE/CPU 2")
    cli_action("onedb change-body vm --id #{id} /VM/TEMPLATE/VCPU 2")
    cli_action("onedb change-body vm --id #{id} /VM/USER_TEMPLATE/LICENSE 2")

    # The failures are for MEMORY, CPU, VCPU, LICENSE quota. All also with RUNNING_ prefix.
    # The quotas are fixed for user and group
    run_fsck(16)
  end
end
