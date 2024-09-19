#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "VDC resources test" do
  #---------------------------------------------------------------------------
  # OpenNebula bootstraping:
  #   - Define infrastructure: hosts, datastore, users, networks,...
  #   - Common instance variables: templates,...
  #---------------------------------------------------------------------------

  before(:each) do
    @gr_id = cli_create("onegroup create testgroup")
    @cl_id = cli_create("onecluster create cl")
    @host_id = cli_create("onehost create test_host --im dummy --vm dummy")

    vnet_tmpl = <<-EOF
    NAME = test_vnet
    BRIDGE = br0
    VN_MAD = dummy
    AR=[TYPE = "IP4", IP = "10.0.0.10", SIZE = "100" ]
    EOF

    @vnet_id = cli_create("onevnet create", vnet_tmpl)

    @ds_id = cli_create("onedatastore create", "NAME = test_ds\nTM_MAD=dummy\nDS_MAD=dummy")

    @vdc_id = cli_create("onevdc create testvdc")

    cli_action("onevdc delgroup 0 testgroup")
    cli_action("onevdc addgroup testvdc testgroup")
  end

  after(:each) do
    `onegroup delete testgroup`
    `onecluster delete cl`
    `onehost delete test_host`
    `onevnet delete test_vnet`
    `onedatastore delete test_ds`
    `onevdc delete testvdc`

    expect(`oneacl list | wc -l`.strip).to eql "7"
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  ############################################################################
  # Add cluster
  ############################################################################

  it "should add a cluster and check the acl rules" do
    cli_action("onevdc addcluster testvdc 0 cl")

    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *-H----------------- *%#{@cl_id} *-m--/)
    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *--N---------------- *%#{@cl_id} *u---/)
    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *-------D----------- *%#{@cl_id} *u---/)
  end

  it "should add the cluster ALL and check the acl rules" do
    cli_action("onevdc addcluster testvdc 0 all")

    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *-H----------------- *\* *-m--/)
    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *--N---------------- *\* *u---/)
    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *-------D----------- *\* *u---/)
  end

  it "should try to add a cluster twice and check the failure" do
    cli_action("onevdc addcluster testvdc 0 cl")
    cli_action("onevdc addcluster testvdc 0 cl", false)

    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *-H----------------- *%#{@cl_id} *-m--/)
    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *--N---------------- *%#{@cl_id} *u---/)
    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *-------D----------- *%#{@cl_id} *u---/)
  end

  it "should try to add the cluster ALL twice and check the failure" do
    cli_action("onevdc addcluster testvdc 0 all")
    cli_action("onevdc addcluster testvdc 0 all", false)

    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *-H----------------- *\* *-m--/)
    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *--N---------------- *\* *u---/)
    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *-------D----------- *\* *u---/)
  end

  it "should try to add a cluster with a non-existing cluster and check the failure" do
    cli_action("onevdc addcluster testvdc 0 404", false)

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-H---------------- *%404 *-m--/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *--N--------------- *%404 *u---/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-------D---------- *%404 *u---/)
  end

  ############################################################################
  # Del cluster
  ############################################################################

  it "should del a cluster and check the acl rules" do
    cli_action("onevdc addcluster testvdc 0 cl")
    cli_action("onevdc delcluster testvdc 0 cl")

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-H---------------- *%#{@cl_id} *-m--/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *--N--------------- *%#{@cl_id} *u---/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-------D---------- *%#{@cl_id} *u---/)
  end

  it "should del the cluster ALL and check the acl rules" do
    cli_action("onevdc addcluster testvdc 0 all")
    cli_action("onevdc delcluster testvdc 0 all")

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-H---------------- *\* *-m--/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *--N--------------- *\* *u---/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-------D---------- *\* *u---/)
  end

  it "should try to del a cluster twice and check the failure" do
    cli_action("onevdc addcluster testvdc 0 cl")
    cli_action("onevdc delcluster testvdc 0 cl")
    cli_action("onevdc delcluster testvdc 0 cl", false)

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-H---------------- *%#{@cl_id} *-m--/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *--N--------------- *%#{@cl_id} *u---/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-------D---------- *%#{@cl_id} *u---/)
  end

  it "should try to del the cluster ALL twice and check the failure" do
    cli_action("onevdc addcluster testvdc 0 all")
    cli_action("onevdc delcluster testvdc 0 all")
    cli_action("onevdc delcluster testvdc 0 all", false)

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-H---------------- *\* *-m--/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *--N--------------- *\* *u---/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-------D---------- *\* *u---/)
  end

  it "should try to del a cluster from a VDC that is not assigned and check the failure" do
    cli_action("onevdc delcluster testvdc 0 cl", false)

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-H---------------- *%#{@cl_id} *-m--/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *--N--------------- *%#{@cl_id} *u---/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-------D---------- *%#{@cl_id} *u---/)
  end

  it "should del a cluster after the cluster has been deleted" do
    cli_action("onevdc addcluster testvdc 0 cl")
    cli_action("onecluster delete cl")

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-H---------------- *%#{@cl_id} *-m--/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *--N--------------- *%#{@cl_id} *u---/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-------D---------- *%#{@cl_id} *u---/)

    cli_action("onevdc delcluster testvdc 0 #{@cl_id}", false)

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-H---------------- *%#{@cl_id} *-m--/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *--N--------------- *%#{@cl_id} *u---/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-------D---------- *%#{@cl_id} *u---/)
  end


  ############################################################################
  # Add host
  ############################################################################

  it "should add a host and check the acl rules" do
    cli_action("onevdc addhost testvdc 0 test_host")

    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *-H----------------- *##{@host_id} *-m--/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *--N----------------.*/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-------D-----------.*/)
  end

  it "should add the host ALL and check the acl rules" do
    cli_action("onevdc addhost testvdc 0 all")

    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *-H----------------- *\* *-m--/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *--N----------------.*/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-------D-----------.*/)
  end

  it "should try to add a host twice and check the failure" do
    cli_action("onevdc addhost testvdc 0 test_host")
    cli_action("onevdc addhost testvdc 0 test_host", false)

    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *-H----------------- *##{@host_id} *-m--/)
  end

  it "should try to add the host ALL twice and check the failure" do
    cli_action("onevdc addhost testvdc 0 all")
    cli_action("onevdc addhost testvdc 0 all", false)

    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *-H----------------- *\* *-m--/)
  end

  it "should try to add a host with a non-existing host and check the failure" do
    cli_action("onevdc addhost testvdc 0 404", false)

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-H---------------- *%404 *-m--/)
  end

  ############################################################################
  # Del host
  ############################################################################

  it "should del a host and check the acl rules" do
    cli_action("onevdc addhost testvdc 0 test_host")
    cli_action("onevdc delhost testvdc 0 test_host")

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-H---------------- *##{@host_id} *-m--/)
  end

  it "should del the host ALL and check the acl rules" do
    cli_action("onevdc addhost testvdc 0 all")
    cli_action("onevdc delhost testvdc 0 all")

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-H---------------- *\* *-m--/)
  end

  it "should try to del a host twice and check the failure" do
    cli_action("onevdc addhost testvdc 0 test_host")
    cli_action("onevdc delhost testvdc 0 test_host")
    cli_action("onevdc delhost testvdc 0 test_host", false)

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-H---------------- *##{@host_id} *-m--/)
  end

  it "should try to del the host ALL twice and check the failure" do
    cli_action("onevdc addhost testvdc 0 all")
    cli_action("onevdc delhost testvdc 0 all")
    cli_action("onevdc delhost testvdc 0 all", false)

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-H---------------- *\* *-m--/)
  end

  it "should try to del a host from a VDC that is not assigned and check the failure" do
    cli_action("onevdc delhost testvdc 0 test_host", false)

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-H---------------- *##{@host_id} *-m--/)
  end

  it "should del a host after the host has been deleted" do
    cli_action("onevdc addhost testvdc 0 test_host")
    cli_action("onehost delete test_host")

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-H---------------- *##{@host_id} *-m--/)

    cli_action("onevdc delhost testvdc 0 #{@host_id}", false)

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-H---------------- *##{@host_id} *-m--/)
  end

  ############################################################################
  # Add vnet
  ############################################################################

  it "should add a vnet and check the acl rules" do
    cli_action("onevdc addvnet testvdc 0 test_vnet")

    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *--N---------------- *##{@vnet_id} *u---/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-H-----------------.*/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-------D-----------.*/)
  end

  it "should add the vnet ALL and check the acl rules" do
    cli_action("onevdc addvnet testvdc 0 all")

    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *--N---------------- *\* *u---/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-H-----------------.*/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-------D-----------.*/)
  end

  it "should try to add a vnet twice and check the failure" do
    cli_action("onevdc addvnet testvdc 0 test_vnet")
    cli_action("onevdc addvnet testvdc 0 test_vnet", false)

    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *--N---------------- *##{@vnet_id} *u---/)
  end

  it "should try to add the vnet ALL twice and check the failure" do
    cli_action("onevdc addvnet testvdc 0 all")
    cli_action("onevdc addvnet testvdc 0 all", false)

    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *--N---------------- *\* *u---/)
  end

  it "should try to add a vnet with a non-existing vnet and check the failure" do
    cli_action("onevdc addvnet testvdc 0 404", false)

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *--N--------------- *%404 *u---/)
  end

  ############################################################################
  # Del vnet
  ############################################################################

  it "should del a vnet and check the acl rules" do
    cli_action("onevdc addvnet testvdc 0 test_vnet")
    cli_action("onevdc delvnet testvdc 0 test_vnet")

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *--N--------------- *##{@vnet_id} *u---/)
  end

  it "should del the vnet ALL and check the acl rules" do
    cli_action("onevdc addvnet testvdc 0 all")
    cli_action("onevdc delvnet testvdc 0 all")

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *--N--------------- *\* *u---/)
  end

  it "should try to del a vnet twice and check the failure" do
    cli_action("onevdc addvnet testvdc 0 test_vnet")
    cli_action("onevdc delvnet testvdc 0 test_vnet")
    cli_action("onevdc delvnet testvdc 0 test_vnet", false)

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *--N--------------- *##{@vnet_id} *u---/)
  end

  it "should try to del the vnet ALL twice and check the failure" do
    cli_action("onevdc addvnet testvdc 0 all")
    cli_action("onevdc delvnet testvdc 0 all")
    cli_action("onevdc delvnet testvdc 0 all", false)

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *--N--------------- *\* *u---/)
  end

  it "should try to del a vnet from a VDC that is not assigned and check the failure" do
    cli_action("onevdc delvnet testvdc 0 test_vnet", false)

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *--N--------------- *##{@vnet_id} *u---/)
  end

  it "should del a vnet after the vnet has been deleted" do
    cli_action("onevdc addvnet testvdc 0 test_vnet")
    cli_action("onevnet delete test_vnet")

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *--N--------------- *##{@vnet_id} *u---/)

    cli_action("onevdc delvnet testvdc 0 #{@vnet_id}", false)

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *--N---------------- *##{@vnet_id} *u---/)
  end

  ############################################################################
  # Add datastore
  ############################################################################

  it "should add a datastore and check the acl rules" do
    cli_action("onevdc adddatastore testvdc 0 test_ds")

    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *-------D----------- *##{@ds_id} *u---/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *--N----------------.*/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-H-----------------.*/)
  end

  it "should add the datastore ALL and check the acl rules" do
    cli_action("onevdc adddatastore testvdc 0 all")

    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *-------D----------- *\* *u---/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *--N----------------.*/)
    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-H-----------------.*/)
  end

  it "should try to add a datastore twice and check the failure" do
    cli_action("onevdc adddatastore testvdc 0 test_ds")
    cli_action("onevdc adddatastore testvdc 0 test_ds", false)

    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *-------D----------- *##{@ds_id} *u---/)
  end

  it "should try to add the datastore ALL twice and check the failure" do
    cli_action("onevdc adddatastore testvdc 0 all")
    cli_action("onevdc adddatastore testvdc 0 all", false)

    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{@gr_id} *-------D----------- *\* *u---/)
  end

  it "should try to add a datastore with a non-existing datastore and check the failure" do
    cli_action("onevdc adddatastore testvdc 0 404", false)

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-------D---------- *%404 *u---/)
  end

  ############################################################################
  # Del datastore
  ############################################################################

  it "should del a datastore and check the acl rules" do
    cli_action("onevdc adddatastore testvdc 0 test_ds")
    cli_action("onevdc deldatastore testvdc 0 test_ds")

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-------D---------- *##{@ds_id} *u---/)
  end

  it "should del the datastore ALL and check the acl rules" do
    cli_action("onevdc adddatastore testvdc 0 all")
    cli_action("onevdc deldatastore testvdc 0 all")

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-------D---------- *\* *u---/)
  end

  it "should try to del a datastore twice and check the failure" do
    cli_action("onevdc adddatastore testvdc 0 test_ds")
    cli_action("onevdc deldatastore testvdc 0 test_ds")
    cli_action("onevdc deldatastore testvdc 0 test_ds", false)

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-------D---------- *##{@ds_id} *u---/)
  end

  it "should try to del the datastore ALL twice and check the failure" do
    cli_action("onevdc adddatastore testvdc 0 all")
    cli_action("onevdc deldatastore testvdc 0 all")
    cli_action("onevdc deldatastore testvdc 0 all", false)

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-------D---------- *\* *u---/)
  end

  it "should try to del a datastore from a VDC that is not assigned and check the failure" do
    cli_action("onevdc deldatastore testvdc 0 test_ds", false)

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-------D---------- *##{@ds_id} *u---/)
  end

  it "should del a datastore after the datastore has been deleted" do
    cli_action("onevdc adddatastore testvdc 0 test_ds")
    cli_action("onedatastore delete test_ds")

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-------D---------- *##{@ds_id} *u---/)

    cli_action("onevdc deldatastore testvdc 0 #{@ds_id}", false)

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{@gr_id} *-------D---------- *##{@ds_id} *u---/)
  end

end