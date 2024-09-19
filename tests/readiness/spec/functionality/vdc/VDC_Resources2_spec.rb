#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
require 'VN'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Deleted resource is removed from VDC:" do
  #---------------------------------------------------------------------------
  # OpenNebula bootstraping:
  #   - Define infrastructure: hosts, datastore, users, networks,...
  #   - Common instance variables: templates,...
  #---------------------------------------------------------------------------

  before(:each) do
    @vdc_id = cli_create("onevdc create testvdc")
  end

  after(:each) do
    `onevdc delete testvdc`
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  ############################################################################
  # Cluster
  ############################################################################

  it "should add a cluster to VDC check it's added, delete the cluster and check it's removed from VDC" do
    @cl_id = cli_create("onecluster create cl")
    cli_action("onevdc addcluster testvdc 0 cl")
    expect(cli_action("onevdc list").stdout).to match(/testvdc *0 *1 *0 *0 *0/)

    cli_action("onecluster delete cl")
    expect(cli_action("onevdc list").stdout).to match(/testvdc *0 *0 *0 *0 *0/)
  end


  ############################################################################
  # Host
  ############################################################################

  it "should add a host to VDC check it's added, delete the host and check it's removed from VDC" do
    @host_id = cli_create("onehost create test_host --im dummy --vm dummy")
    cli_action("onevdc addhost testvdc 0 test_host")
    expect(cli_action("onevdc list").stdout).to match(/testvdc *0 *0 *1 *0 *0/)

    cli_action("onehost delete test_host")
    expect(cli_action("onevdc list").stdout).to match(/testvdc *0 *0 *0 *0 *0/)
  end


  ############################################################################
  # Vnet
  ############################################################################

  it "should add a vnet to VDC check it's added, delete vnet and check it's removed from VDC" do
    vnet_tmpl = <<-EOF
    NAME = test_vnet
    BRIDGE = br0
    VN_MAD = dummy
    AR=[TYPE = "IP4", IP = "10.0.0.10", SIZE = "100" ]
    EOF

    vnet = VN.create(vnet_tmpl)
    vnet.ready?

    cli_action("onevdc addvnet testvdc 0 test_vnet")
    expect(cli_action("onevdc list").stdout).to match(/testvdc *0 *0 *0 *1 *0/)

    vnet.delete
    vnet.deleted?

    expect(cli_action("onevdc list").stdout).to match(/testvdc *0 *0 *0 *0 *0/)
  end


  ############################################################################
  # Datastore
  ############################################################################

  it "should add a datastore to VDC, check it's added, delete vnet and check it's removed from VDC" do
    @ds_id = cli_create("onedatastore create", "NAME = test_ds\nTM_MAD=dummy\nDS_MAD=dummy")
    cli_action("onevdc adddatastore testvdc 0 test_ds")
    expect(cli_action("onevdc list").stdout).to match(/testvdc *0 *0 *0 *0 *1/)

    cli_action("onedatastore delete test_ds")
    expect(cli_action("onevdc list").stdout).to match(/testvdc *0 *0 *0 *0 *0/)
  end


  ############################################################################
  # Group
  ############################################################################

  it "should add a group, check it's added, delete group and check it's removed from VDC" do
    @gr_id = cli_create("onegroup create test_gr")
    cli_action("onevdc addgroup testvdc test_gr")
    expect(cli_action("onevdc list").stdout).to match(/testvdc *1 *0 *0 *0 *0/)

    cli_action("onegroup delete test_gr")
    expect(cli_action("onevdc list").stdout).to match(/testvdc *0 *0 *0 *0 *0/)
  end


end