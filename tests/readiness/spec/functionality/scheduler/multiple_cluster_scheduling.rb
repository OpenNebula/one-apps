
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Multiple cluster scheduling tests" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

  #---------------------------------------------------------------------------
  # OpenNebula bootstraping:
  #   - Define infrastructure: hosts, datastore, users, networks,...
  #   - Common instance variables: templates,...
  #---------------------------------------------------------------------------
  before(:all) do

    vnet_tmpl = <<-EOF
    BRIDGE = br0
    VN_MAD = dummy
    AR=[TYPE = "IP4", IP = "10.0.0.10", SIZE = "100" ]
    EOF

    cli_create("onecluster create cluster_A")
    cli_create("onecluster create cluster_B")
    cli_create("onecluster create cluster_C")
    cli_create("onecluster create cluster_D")

    cli_create("onehost create host_A --im dummy --vm dummy --cluster cluster_A")
    cli_create("onehost create host_B --im dummy --vm dummy --cluster cluster_B")
    cli_create("onehost create host_C --im dummy --vm dummy --cluster cluster_C")
    cli_create("onehost create host_D --im dummy --vm dummy --cluster cluster_D")

    cli_create("onedatastore create", "NAME = ds_ABC\nTM_MAD=dummy\nDS_MAD=dummy")

    cli_action("onecluster deldatastore default ds_ABC")

    cli_action("onecluster adddatastore cluster_A ds_ABC")
    cli_action("onecluster adddatastore cluster_B ds_ABC")
    cli_action("onecluster adddatastore cluster_C ds_ABC")

    wait_loop() {
        xml = cli_action_xml("onedatastore show -x ds_ABC")
        xml['FREE_MB'].to_i > 0
    }

    cli_create("onedatastore create", "NAME = system_ABCD\nTM_MAD=dummy\nTYPE=system_ds")

    cli_action("onecluster deldatastore default system_ABCD")

    cli_action("onecluster adddatastore cluster_A system_ABCD")
    cli_action("onecluster adddatastore cluster_B system_ABCD")
    cli_action("onecluster adddatastore cluster_C system_ABCD")
    cli_action("onecluster adddatastore cluster_D system_ABCD")

    image_id = cli_create("oneimage create --name img_ABC " <<
                "--size 100 --type datablock -d ds_ABC")

    wait_loop() {
      xml = cli_action_xml("oneimage show -x #{image_id}")
      Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
    }

    cli_create("onevnet create", "NAME = vnet_BCD\n"+vnet_tmpl)

    cli_action("onecluster delvnet default vnet_BCD")

    cli_action("onecluster addvnet cluster_B vnet_BCD")
    cli_action("onecluster addvnet cluster_C vnet_BCD")
    cli_action("onecluster addvnet cluster_D vnet_BCD")
  end

  after(:each) do
    `onetemplate delete test_tmpl`
    `onevm recover --delete test_vm`
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  # Test for Bug #4637
  it "should create a VM using resources from cluster B & C, and be deployed in system DS in multiple clusters" do
    template = <<-EOF
      NAME = test_tmpl
      MEMORY = 128
      CPU = 1
      DISK = [
        IMAGE = img_ABC
      ]
      NIC = [
        NETWORK = vnet_BCD
      ]
    EOF

    cli_create("onetemplate create", template)

    cli_action("onetemplate instantiate test_tmpl --name test_vm")

    wait_loop() {
      xml = cli_action_xml("onevm show -x test_vm")
      VirtualMachine::LCM_STATE[xml['LCM_STATE'].to_i] == "RUNNING"
    }

    vm_xml = cli_action_xml("onevm show test_vm -x")
    expect(vm_xml['HISTORY_RECORDS/HISTORY[last()]/HOSTNAME']).to eql("host_B").or eql("host_C")
  end
end