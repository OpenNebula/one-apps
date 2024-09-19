
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Cluster scheduling tests" do
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

    # Create host, system DS, image and vnet in cluster A
    cli_create("onecluster create cluster_A")
    cli_create("onehost create host_A --im dummy --vm dummy --cluster cluster_A")

    cli_create("onedatastore create --cluster cluster_A", "NAME = ds_A\nTM_MAD=dummy\nDS_MAD=dummy")
    cli_create("onedatastore create --cluster cluster_A", "NAME = system_A\nTM_MAD=dummy\nTYPE=system_ds")

    wait_loop() {
        xml = cli_action_xml("onedatastore show -x ds_A")
        xml['FREE_MB'].to_i > 0
    }

    image_id = cli_create("oneimage create --name img_A " <<
                "--size 100 --type datablock -d ds_A")

    wait_loop() {
      xml = cli_action_xml("oneimage show -x #{image_id}")
      Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
    }

    cli_create("onevnet create -c cluster_A", "NAME = vnet_A\n"+vnet_tmpl)

    # Create host, image and vnet in cluster C
    cli_create("onecluster create cluster_B")
    cli_create("onehost create host_B --im dummy --vm dummy --cluster cluster_B")
    cli_create("onedatastore create --cluster cluster_B", "NAME = ds_B\nTM_MAD=dummy\nDS_MAD=dummy")
    cli_create("onedatastore create --cluster cluster_B", "NAME = system_B\nTM_MAD=dummy\nTYPE=system_ds")

    wait_loop() {
        xml = cli_action_xml("onedatastore show -x ds_B")
        xml['FREE_MB'].to_i > 0
    }

    image_id = cli_create("oneimage create --name img_B " <<
                "--size 100 --type datablock -d ds_B")

    wait_loop() {
      xml = cli_action_xml("oneimage show -x #{image_id}")
      Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
    }

    cli_create("onevnet create -c cluster_B", "NAME = vnet_B\n"+vnet_tmpl)

    # Create host, image and vnet without cluster
    cli_create("onehost create host_C --im dummy --vm dummy")
    cli_create("onedatastore create", "NAME = ds_C\nTM_MAD=dummy\nDS_MAD=dummy")

    wait_loop() {
        xml = cli_action_xml("onedatastore show -x ds_C")
        xml['FREE_MB'].to_i > 0
    }

    image_id = cli_create("oneimage create --name img_C " <<
                "--size 100 --type datablock -d ds_C")

    wait_loop() {
      xml = cli_action_xml("oneimage show -x #{image_id}")
      Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
    }


    tmpl = <<-EOF
    NAME = testvnet
    BRIDGE = br0
    VN_MAD = dummy
    AR=[TYPE = "IP4", IP = "10.0.0.10", SIZE = "100" ]
    EOF

    cli_create("onevnet create", "NAME = vnet_C\n"+vnet_tmpl)

    cli_action("onecluster delhost default host_C")
    cli_action("onecluster deldatastore default ds_C")
    cli_action("onecluster delvnet default vnet_C")
  end

  after(:each) do
    cli_action("onetemplate delete test_tmpl")
    `onevm recover --delete test_vm`
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------


  it "should try to use incompatible cluster resources, and fail. img-img" do
    template = <<-EOF
      NAME = test_tmpl
      MEMORY = 128
      CPU = 1
      DISK = [
        IMAGE = img_A,
        TARGET = hda
      ]
      DISK = [
        IMAGE = img_B,
        TARGET = hdb
      ]
    EOF

    cli_create("onetemplate create", template)

    output = cli_action("onetemplate instantiate test_tmpl --name test_vm", false).stderr
    expect(output).to match(/Incompatible clusters/)
  end

  it "should try to use incompatible cluster resources, and fail. img-vnet" do
    template = <<-EOF
      NAME = test_tmpl
      MEMORY = 128
      CPU = 1
      DISK = [
        IMAGE = img_A,
        TARGET = hdb
      ]
      NIC = [
        NETWORK = vnet_B
      ]
    EOF

    cli_create("onetemplate create", template)

    output = cli_action("onetemplate instantiate test_tmpl --name test_vm", false).stderr
    expect(output).to match(/Incompatible clusters/)
  end

  it "should try to use incompatible cluster resources, and fail. vnet-vnet" do
    template = <<-EOF
      NAME = test_tmpl
      MEMORY = 128
      CPU = 1
      NIC = [
        NETWORK = vnet_A
      ]
      NIC = [
        NETWORK = vnet_B
      ]
    EOF

    cli_create("onetemplate create", template)

    output = cli_action("onetemplate instantiate test_tmpl --name test_vm", false).stderr
    expect(output).to match(/Incompatible clusters/)
  end

  it "should create a VM using resources from cluster A, and be deployed in host A" do
    template = <<-EOF
      NAME = test_tmpl
      MEMORY = 128
      CPU = 1
      DISK = [
        IMAGE = img_A
      ]
      NIC = [
        NETWORK = vnet_A
      ]
    EOF

    cli_create("onetemplate create", template)

    cli_action("onetemplate instantiate test_tmpl --name test_vm")

    wait_loop() {
      xml = cli_action_xml("onevm show -x test_vm")
      VirtualMachine::LCM_STATE[xml['LCM_STATE'].to_i] == "RUNNING"
    }

    vm_xml = cli_action_xml("onevm show test_vm -x")
    expect(vm_xml['HISTORY_RECORDS/HISTORY[last()]/HOSTNAME']).to eql("host_A")
  end

  it "should create a VM using resources from cluster B, and be deployed in host B" do
    template = <<-EOF
      NAME = test_tmpl
      MEMORY = 128
      CPU = 1
      DISK = [
        IMAGE = img_B
      ]
      NIC = [
        NETWORK = vnet_B
      ]
    EOF

    cli_create("onetemplate create", template)

    cli_action("onetemplate instantiate test_tmpl --name test_vm")

    wait_loop() {
      xml = cli_action_xml("onevm show -x test_vm")
      VirtualMachine::LCM_STATE[xml['LCM_STATE'].to_i] == "RUNNING"
    }

    vm_xml = cli_action_xml("onevm show test_vm -x")
    expect(vm_xml['HISTORY_RECORDS/HISTORY[last()]/HOSTNAME']).to eql("host_B")
  end

  it "should try to create a VM using resources not in any cluster, and fail" do
    template = <<-EOF
      NAME = test_tmpl
      MEMORY = 128
      CPU = 1
      DISK = [
        IMAGE = img_C
      ]
      NIC = [
        NETWORK = vnet_C
      ]
    EOF

    cli_create("onetemplate create", template)

    output = cli_action("onetemplate instantiate test_tmpl --name test_vm", false)
    expect(output).to match(/is not in any cluster/)
  end
end