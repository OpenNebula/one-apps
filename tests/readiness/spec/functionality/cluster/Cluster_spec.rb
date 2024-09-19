#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Cluster tests" do

  ##############################################################################
  # GENERAL OPERATIONS
  ##############################################################################
  context "general operations" do
    after(:each) do
      `onecluster delete test_cluster`
    end

    #   * create <name>
    #        Creates a new Cluster
    #   * show <clusterid>
    #        Shows information for the given Cluster
    #        valid options: xml
    #   * list
    #        Lists Clusters in the pool
    #        valid options: list, delay, xml, numeric

    it "should create a new Cluster" do
        id = cli_create("onecluster create test_cluster")
        expect(id).to be >= 100

        expect(cli_action("onecluster list")).to match(/#{id} *test_cluster/)
        cli_action("onecluster show #{id}")
        cli_action("onecluster show test_cluster -x")
    end

    it "should try to create an invalid Cluster and check the failure" do
        output = cli_action("onecluster create ''", false).stderr
        expect(output).to match(/Invalid NAME, it cannot be empty/)
    end

    it "should try to create an existing Cluster and check the failure" do
        id = cli_create("onecluster create test_cluster")

        output = cli_action("onecluster create test_cluster", false).stderr
        expect(output).to match(/NAME is already taken/)
    end

    #   * delete <range|clusterid_list>
    #        Deletes the given Cluster

    it "should delete an existing Cluster, numeric id" do
        id = cli_create("onecluster create test_cluster")

        cli_action("onecluster delete #{id}")
    end

    it "should delete an existing Cluster, by name" do
        id = cli_create("onecluster create test_cluster")

        cli_action("onecluster delete test_cluster")
    end

    it "should try to delete a non-existent Cluster and check the failure, numeric id" do
        output = cli_action("onecluster delete 12345", false).stderr
        expect(output).to match(/Error getting cluster/)
    end

    it "should try to delete a non-existent Cluster and check the failure, by name" do
        output = cli_action("onecluster delete non-existent", false).stderr
        expect(output).to match(/CLUSTER named .* not found./)
    end

    it "should try to delete a non empty Cluster and check the failure" do
        id = cli_create("onecluster create test_cluster")

        ds_id = cli_create("onedatastore create", "NAME = ds0\nTM_MAD=dummy\nDS_MAD=dummy")

        cli_action("onecluster adddatastore #{id} #{ds_id}")

        output = cli_action("onecluster delete #{id}", false).stderr
        expect(output).to match(/is not empty/)

        cli_action("onedatastore delete #{ds_id}")
    end
  end

  ##############################################################################
  # HOST CREATION
  ##############################################################################
  context "host creation" do
    after(:each) do
      `onehost delete test_host`
      `onecluster delete test_cluster`
    end

    # onehost
    #   * create <hostname>
    #        Creates a new Host
    #        valid options: im, vmm, vnm, cluster
    it "should create a Host in the default Cluster" do
      cli_create("onehost create test_host --im dummy --vm dummy")

      expect(cli_action_xml("onehost show test_host -x")['CLUSTER_ID']).to eql("0")
      expect(cli_action_xml("onehost show test_host -x")['CLUSTER']).to eql("default")
    end

    it "should create a Host in a Cluster, numeric id" do
      id = cli_create("onecluster create test_cluster")

      cli_create("onehost create test_host --im dummy --vm dummy --cluster #{id}")

      xml_host = cli_action_xml("onehost show test_host -x")
      expect(xml_host['CLUSTER_ID']).to eql(id.to_s)
      expect(xml_host['CLUSTER']).to eql("test_cluster")
    end

    it "should create a Host in a Cluster, by name" do
      id = cli_create("onecluster create test_cluster")

      cli_create("onehost create test_host --im dummy --vm dummy --cluster test_cluster")

      xml_host = cli_action_xml("onehost show test_host -x")
      expect(xml_host['CLUSTER_ID']).to eql(id.to_s)
      expect(xml_host['CLUSTER']).to eql("test_cluster")
    end

    it "should try to create a Host in a non-existent Cluster, by name" do
      output = cli_action("onehost create test_host --im dummy "<<
          "--vm dummy --cluster non-existent", false).stderr

      expect(output).to match(/CLUSTER named non-existent not found/)
    end

    it "should try to create a Host in a non-existent Cluster, numeric id" do
      output = cli_action("onehost create test_host --im dummy "<<
          "--vm dummy --cluster 123456", false).stderr

      expect(output).to match(/Error getting cluster/)
    end
  end

  ##############################################################################
  # HOST OPERATIONS
  ##############################################################################
  context "host operations" do
    before(:each) do
      @host_id    = cli_create("onehost create test_host --im dummy --vm dummy")
      @cluster_id = cli_create("onecluster create test_cluster")
    end

    after(:each) do
      `onehost delete test_host`

      `onecluster delete test_cluster`
      `onecluster delete new_cluster`
    end

    #   * addhost <clusterid> <hostid>
    #        Adds a Host to the given Cluster
    it "should add a Host, assigned to the default Cluster, to a Cluster, id, id" do
      cli_action("onecluster addhost #{@cluster_id} #{@host_id}")

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["HOSTS/ID[.=#{@host_id}]"]).not_to be nil

      xml_host = cli_action_xml("onehost show test_host -x")
      expect(xml_host['CLUSTER_ID']).to eql(@cluster_id.to_s)
      expect(xml_host['CLUSTER']).to eql("test_cluster")
    end

    it "should add a Host, assigned to the default Cluster, to a Cluster, name, name" do
      cli_action("onecluster addhost test_cluster test_host")

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["HOSTS/ID[.=#{@host_id}]"]).not_to be nil

      xml_host = cli_action_xml("onehost show test_host -x")
      expect(xml_host['CLUSTER_ID']).to eql(@cluster_id.to_s)
      expect(xml_host['CLUSTER']).to eql("test_cluster")
    end

    it "should add a Host, assigned to another Cluster, to a Cluster, id, id" do
      cli_action("onecluster addhost #{@cluster_id} #{@host_id}")

      id = cli_create("onecluster create new_cluster")

      cli_action("onecluster addhost #{id} #{@host_id}")

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["HOSTS/ID[.=#{@host_id}]"]).to be nil

      xml_cluster = cli_action_xml("onecluster show #{id} -x")
      expect(xml_cluster["HOSTS/ID[.=#{@host_id}]"]).not_to be nil

      xml_host = cli_action_xml("onehost show test_host -x")
      expect(xml_host['CLUSTER_ID']).to eql(id.to_s)
      expect(xml_host['CLUSTER']).to eql("new_cluster")
    end

    it "should add a Host, assigned to another Cluster, to a Cluster, name, name" do
      cli_action("onecluster addhost test_cluster test_host")

      id = cli_create("onecluster create new_cluster")

      cli_action("onecluster addhost new_cluster test_host")

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["HOSTS/ID[.=#{@host_id}]"]).to be nil

      xml_cluster = cli_action_xml("onecluster show #{id} -x")
      expect(xml_cluster["HOSTS/ID[.=#{@host_id}]"]).not_to be nil

      xml_host = cli_action_xml("onehost show test_host -x")
      expect(xml_host['CLUSTER_ID']).to eql(id.to_s)
      expect(xml_host['CLUSTER']).to eql("new_cluster")
    end

    it "should try to add a Host, assigned to the default Cluster, to a non-existent Cluster, id, id" do
      output = cli_action("onecluster addhost 123456 #{@host_id}", false).stderr
      expect(output).to match(/Error getting cluster/)

      xml_host = cli_action_xml("onehost show test_host -x")
      expect(xml_host['CLUSTER_ID']).to eql("0")
    end

    it "should try to add a Host, assigned to the default Cluster, to a non-existent Cluster, name, name" do
      output = cli_action("onecluster addhost non-existent test_host", false).stderr
      expect(output).to match(/CLUSTER named non-existent not found/)

      xml_host = cli_action_xml("onehost show test_host -x")
      expect(xml_host['CLUSTER_ID']).to eql("0")
    end

    it "should try to add a Host, assigned to another Cluster, to a non-existent Cluster, id, id" do
      cli_action("onecluster addhost #{@cluster_id} #{@host_id}")

      output = cli_action("onecluster addhost 123456 #{@host_id}", false).stderr
      expect(output).to match(/Error getting cluster/)

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["HOSTS/ID[.=#{@host_id}]"]).not_to be nil

      xml_host = cli_action_xml("onehost show test_host -x")
      expect(xml_host['CLUSTER_ID']).to eql(@cluster_id.to_s)
      expect(xml_host['CLUSTER']).to eql("test_cluster")
    end

    it "should try to add a Host, assigned to another Cluster, to a non-existent Cluster, name, name" do
      cli_action("onecluster addhost #{@cluster_id} #{@host_id}")

      output = cli_action("onecluster addhost non-existent test_host", false).stderr
      expect(output).to match(/CLUSTER named non-existent not found/)

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["HOSTS/ID[.=#{@host_id}]"]).not_to be nil

      xml_host = cli_action_xml("onehost show test_host -x")
      expect(xml_host['CLUSTER_ID']).to eql(@cluster_id.to_s)
      expect(xml_host['CLUSTER']).to eql("test_cluster")
    end

    it "should try to add a non-existent Host to a Cluster, numeric id" do
      output = cli_action("onecluster addhost #{@cluster_id} 123456", false).stderr
      expect(output).to match(/Error getting host/)

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["HOSTS/ID[.=123456]"]).to be nil
    end

    it "should try to add a non-existent Host to a Cluster, by name" do
      output = cli_action("onecluster addhost test_cluster non-existent", false).stderr
      expect(output).to match(/HOST named non-existent not found/)
    end

    it "should try to add a non-existent Host to a non-existent Cluster, numeric id" do
      output = cli_action("onecluster addhost 123456 123456", false).stderr
      expect(output).to match(/Error getting cluster/)
    end

    it "should try to add a non-existent Host to a non-existent Cluster, by name" do
      output = cli_action("onecluster addhost non-existent non-existent", false).stderr
      expect(output).to match(/CLUSTER named non-existent not found/)
    end

    #   * delhost <clusterid> <hostid>
    #        Deletes a Host from the given Cluster

    it "should delete a Host from its Cluster, id, id" do
      cli_action("onecluster addhost #{@cluster_id} #{@host_id}")
      cli_action("onecluster delhost #{@cluster_id} #{@host_id}")

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["HOSTS/ID[.=#{@host_id}]"]).to be nil

      xml_host = cli_action_xml("onehost show test_host -x")
      expect(xml_host['CLUSTER_ID']).to eql("0")
      expect(xml_host['CLUSTER']).to eql("default")
    end

    it "should delete a Host from its Cluster, name, name" do
      cli_action("onecluster addhost test_cluster test_host")
      cli_action("onecluster delhost test_cluster test_host")

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["HOSTS/ID[.=#{@host_id}]"]).to be nil

      xml_host = cli_action_xml("onehost show test_host -x")
      expect(xml_host['CLUSTER_ID']).to eql("0")
      expect(xml_host['CLUSTER']).to eql("default")
    end

    it "should try to delete a non-existent Host from a Cluster, id, id" do
      output = cli_action("onecluster delhost #{@cluster_id} 123456", false).stderr
      expect(output).to match(/Error getting host/)
    end

    it "should try to delete a non-existent Host from a Cluster, name, name" do
      output = cli_action("onecluster delhost test_cluster non-existent", false).stderr
      expect(output).to match(/HOST named non-existent not found/)
    end

    it "should reserve cluster capacity and add a Host" do
      reserved_cpu = 100
      reserved_mem = 5000000
      cluster_template = "RESERVED_CPU=\"#{reserved_cpu}\"\nRESERVED_MEM=\"#{reserved_mem}\""
      cli_update("onecluster update #{@cluster_id}", cluster_template, true)
      cli_action("onecluster addhost #{@cluster_id} #{@host_id}")

      host = Host.new(@host_id)
      host.monitored?

      xml_host = cli_action_xml("onehost show test_host -x")
      total_cpu = xml_host['HOST_SHARE/TOTAL_CPU']
      total_mem = xml_host['HOST_SHARE/TOTAL_MEM']

      expect(xml_host['HOST_SHARE/MAX_CPU']).to eql((total_cpu.to_i - reserved_cpu).to_s)
      expect(xml_host['HOST_SHARE/MAX_MEM']).to eql((total_mem.to_i - reserved_mem).to_s)

      # Reserved capacity should preserve dummy update
      cli_update("onehost update #{@host_id}", "", true)
      xml_host = cli_action_xml("onehost show test_host -x")
      expect(xml_host['HOST_SHARE/MAX_CPU']).to eql((total_cpu.to_i - reserved_cpu).to_s)
      expect(xml_host['HOST_SHARE/MAX_MEM']).to eql((total_mem.to_i - reserved_mem).to_s)

      # Remove host from cluster, max capacity should equal total capacity
      cli_action("onecluster delhost #{@cluster_id} #{@host_id}")
      xml_host = cli_action_xml("onehost show test_host -x")
      expect(xml_host['HOST_SHARE/MAX_CPU']).to eql((total_cpu.to_i).to_s)
      expect(xml_host['HOST_SHARE/MAX_MEM']).to eql((total_mem.to_i).to_s)
    end

    it "should add a Host and reserve cluster capacity" do
      cli_action("onecluster addhost #{@cluster_id} #{@host_id}")

      host = Host.new(@host_id)
      host.monitored?

      reserved_cpu = 100
      reserved_mem = 5000000
      cluster_template = "RESERVED_CPU=\"#{reserved_cpu}\"\nRESERVED_MEM=\"#{reserved_mem}\""
      cli_update("onecluster update #{@cluster_id}", cluster_template, true)

      xml_host = cli_action_xml("onehost show test_host -x")
      total_cpu = xml_host['HOST_SHARE/TOTAL_CPU']
      total_mem = xml_host['HOST_SHARE/TOTAL_MEM']

      expect(xml_host['HOST_SHARE/MAX_CPU']).to eql((total_cpu.to_i - reserved_cpu).to_s)
      expect(xml_host['HOST_SHARE/MAX_MEM']).to eql((total_mem.to_i - reserved_mem).to_s)
    end

  end

  ##############################################################################
  # DATASTORE CREATION
  ##############################################################################
  context "datastore creation" do
    after(:each) do
      `onedatastore delete test_datastore`
      `onecluster delete test_cluster`
    end

    # onedatastore
    #   * create <file>
    #        Creates a new Datastore from the given template file
    it "should create a Datastore in the default Cluster" do
      cli_create("onedatastore create", "NAME = test_datastore\nTM_MAD=dummy\nDS_MAD=dummy")

      expect(cli_action_xml("onedatastore show test_datastore -x")['CLUSTERS/ID']).to eql("0")
    end

    it "should create a Datastore in a Cluster, numeric id" do
      id = cli_create("onecluster create test_cluster")

      cli_create("onedatastore create --cluster #{id}", "NAME = test_datastore\nTM_MAD=dummy\nDS_MAD=dummy")

      xml_datastore = cli_action_xml("onedatastore show test_datastore -x")
      expect(xml_datastore["CLUSTERS/ID[.=#{id}]"]).to eql(id.to_s)
    end

    it "should create a Datastore in a Cluster, by name" do
      id = cli_create("onecluster create test_cluster")

      cli_create("onedatastore create --cluster test_cluster",
                "NAME = test_datastore\nTM_MAD=dummy\nDS_MAD=dummy")

      xml_datastore = cli_action_xml("onedatastore show test_datastore -x")
      expect(xml_datastore["CLUSTERS/ID[.=#{id}]"]).to eql(id.to_s)
    end

    it "should try to create a Datastore in a non-existent Cluster, by name" do
      output = cli_create("onedatastore create --cluster non-existent",
                "NAME = test_datastore\nTM_MAD=dummy\nDS_MAD=dummy", false).stderr

      expect(output).to match(/CLUSTER named non-existent not found/)
    end

    it "should try to create a Datastore in a non-existent Cluster, numeric id" do
      output = cli_create("onedatastore create --cluster 123456",
                "NAME = test_datastore\nTM_MAD=dummy\nDS_MAD=dummy", false).stderr

      expect(output).to match(/Error getting cluster/)
    end
  end

  ##############################################################################
  # DATASTORE OPERATIONS
  ##############################################################################
  context "datastore operations" do
    before(:each) do
      @datastore_id   = cli_create("onedatastore create", "NAME = test_datastore\nTM_MAD=dummy\nDS_MAD=dummy")
      @cluster_id     = cli_create("onecluster create test_cluster")

      cli_action("onecluster deldatastore default #{@datastore_id}")
    end

    after(:each) do
      `onedatastore delete test_datastore`

      `onecluster delete test_cluster`
      `onecluster delete new_cluster`
    end

    #   * adddatastore <clusterid> <datastoreid>
    #        Adds a Datastore to the given Cluster
    it "should add a Datastore, not assigned to any Cluster, to a Cluster, id, id" do
      cli_action("onecluster adddatastore #{@cluster_id} #{@datastore_id}")

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["DATASTORES/ID[.=#{@datastore_id}]"]).not_to be nil

      xml_datastore = cli_action_xml("onedatastore show test_datastore -x")
      expect(xml_datastore["CLUSTERS/ID[.=#{@cluster_id.to_s}]"]).to eql(@cluster_id.to_s)
    end

    it "should add a Datastore, not assigned to any Cluster, to a Cluster, name, name" do
      cli_action("onecluster adddatastore test_cluster test_datastore")

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["DATASTORES/ID[.=#{@datastore_id}]"]).not_to be nil

      xml_datastore = cli_action_xml("onedatastore show test_datastore -x")
      expect(xml_datastore["CLUSTERS/ID[.=#{@cluster_id.to_s}]"]).to eql(@cluster_id.to_s)
    end

    it "should add a Datastore, assigned to a Cluster, to another Cluster, id, id" do
      cli_action("onecluster adddatastore #{@cluster_id} #{@datastore_id}")

      id = cli_create("onecluster create new_cluster")

      cli_action("onecluster adddatastore #{id} #{@datastore_id}")

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["DATASTORES/ID[.=#{@datastore_id}]"]).not_to be nil

      xml_cluster = cli_action_xml("onecluster show #{id} -x")
      expect(xml_cluster["DATASTORES/ID[.=#{@datastore_id}]"]).not_to be nil

      xml_datastore = cli_action_xml("onedatastore show test_datastore -x")
      expect(xml_datastore["CLUSTERS/ID[.=#{id}]"]).to eql(id.to_s)
      expect(xml_datastore["CLUSTERS/ID[.=#{@cluster_id}]"]).to eql(@cluster_id.to_s)
    end

    it "should add a Datastore, assigned to a Cluster, to another Cluster, name, name" do
      cli_action("onecluster adddatastore test_cluster test_datastore")

      id = cli_create("onecluster create new_cluster")

      cli_action("onecluster adddatastore new_cluster test_datastore")

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["DATASTORES/ID[.=#{@datastore_id}]"]).not_to be nil

      xml_cluster = cli_action_xml("onecluster show #{id} -x")
      expect(xml_cluster["DATASTORES/ID[.=#{@datastore_id}]"]).not_to be nil

      xml_datastore = cli_action_xml("onedatastore show test_datastore -x")
      expect(xml_datastore["CLUSTERS/ID[.=#{id}]"]).to eql(id.to_s)
      expect(xml_datastore["CLUSTERS/ID[.=#{@cluster_id}]"]).to eql(@cluster_id.to_s)
    end

    it "should try to add a Datastore, not assigned to any Cluster, to a non-existent Cluster, id, id" do
      output = cli_action("onecluster adddatastore 123456 #{@datastore_id}", false).stderr
      expect(output).to match(/Error getting cluster/)

      xml_datastore = cli_action_xml("onedatastore show test_datastore -x")
      expect(xml_datastore["CLUSTERS/ID"]).to eql nil
    end

    it "should try to add a Datastore, not assigned to any Cluster, to a non-existent Cluster, name, name" do
      output = cli_action("onecluster adddatastore non-existent test_datastore", false).stderr
      expect(output).to match(/CLUSTER named non-existent not found/)

      xml_datastore = cli_action_xml("onedatastore show test_datastore -x")
      expect(xml_datastore["CLUSTERS/ID"]).to eql nil
    end

    it "should try to add a Datastore, assigned to a Cluster, to a non-existent Cluster, id, id" do
      cli_action("onecluster adddatastore #{@cluster_id} #{@datastore_id}")

      output = cli_action("onecluster adddatastore 123456 #{@datastore_id}", false).stderr
      expect(output).to match(/Error getting cluster/)

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["DATASTORES/ID[.=#{@datastore_id}]"]).not_to be nil

      xml_datastore = cli_action_xml("onedatastore show test_datastore -x")
      expect(xml_datastore["CLUSTERS/ID[.=#{@cluster_id.to_s}]"]).to eql(@cluster_id.to_s)
    end

    it "should try to add a Datastore, assigned to a Cluster, to a non-existent Cluster, name, name" do
      cli_action("onecluster adddatastore #{@cluster_id} #{@datastore_id}")

      output = cli_action("onecluster adddatastore non-existent test_datastore", false).stderr
      expect(output).to match(/CLUSTER named non-existent not found/)

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["DATASTORES/ID[.=#{@datastore_id}]"]).not_to be nil

      xml_datastore = cli_action_xml("onedatastore show test_datastore -x")
      expect(xml_datastore["CLUSTERS/ID[.=#{@cluster_id.to_s}]"]).to eql(@cluster_id.to_s)
    end

    it "should try to add a non-existent Datastore to a Cluster, numeric id" do
      output = cli_action("onecluster adddatastore #{@cluster_id} 123456", false).stderr
      expect(output).to match(/Error getting datastore/)

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["DATASTORES/ID[.=#{123456}]"]).to be nil
    end

    it "should try to add a non-existent Datastore to a Cluster, by name" do
      output = cli_action("onecluster adddatastore test_cluster non-existent", false).stderr
      expect(output).to match(/DATASTORE named non-existent not found/)
    end

    it "should try to add a non-existent Datastore to a non-existent Cluster, numeric id" do
      output = cli_action("onecluster adddatastore 123456 123456", false).stderr
      expect(output).to match(/Error getting cluster/)
    end

    it "should try to add a non-existent Datastore to a non-existent Cluster, by name" do
      output = cli_action("onecluster adddatastore non-existent non-existent", false).stderr
      expect(output).to match(/CLUSTER named non-existent not found/)
    end

    #   * deldatastore <clusterid> <datastoreid>
    #        Deletes a Datastore from the given Cluster

    it "should delete a Datastore from its only Cluster, id, id" do
      cli_action("onecluster adddatastore #{@cluster_id} #{@datastore_id}")
      cli_action("onecluster deldatastore #{@cluster_id} #{@datastore_id}")

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["DATASTORES/ID[.=#{@datastore_id}]"]).to be nil

      xml_datastore = cli_action_xml("onedatastore show test_datastore -x")
      expect(xml_datastore["CLUSTERS/ID[.=#{@cluster_id.to_s}]"]).to eql nil
    end

    it "should delete a Datastore from its only Cluster, name, name" do
      cli_action("onecluster adddatastore test_cluster test_datastore")
      cli_action("onecluster deldatastore test_cluster test_datastore")

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["DATASTORES/ID[.=#{@datastore_id}]"]).to be nil

      xml_datastore = cli_action_xml("onedatastore show test_datastore -x")
      expect(xml_datastore["CLUSTERS/ID[.=#{@cluster_id.to_s}]"]).to eql nil
    end

    it "should delete a Datastore from one of its Clusters, id, id" do
      id = cli_create("onecluster create new_cluster")

      cli_action("onecluster adddatastore #{@cluster_id} #{@datastore_id}")
      cli_action("onecluster adddatastore #{id} #{@datastore_id}")

      cli_action("onecluster deldatastore #{@cluster_id} #{@datastore_id}")

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["DATASTORES/ID[.=#{@datastore_id}]"]).to be nil

      xml_datastore = cli_action_xml("onedatastore show test_datastore -x")
      expect(xml_datastore["CLUSTERS/ID[.=#{id}]"]).to eql id.to_s
      expect(xml_datastore["CLUSTERS/ID[.=#{@cluster_id.to_s}]"]).to eql nil
    end

    it "should delete a Datastore from one of its Clusters, name, name" do
      id = cli_create("onecluster create new_cluster")

      cli_action("onecluster adddatastore test_cluster test_datastore")
      cli_action("onecluster adddatastore new_cluster test_datastore")

      cli_action("onecluster deldatastore test_cluster test_datastore")

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["DATASTORES/ID[.=#{@datastore_id}]"]).to be nil

      xml_datastore = cli_action_xml("onedatastore show test_datastore -x")
      expect(xml_datastore["CLUSTERS/ID[.=#{id}]"]).to eql id.to_s
      expect(xml_datastore["CLUSTERS/ID[.=#{@cluster_id.to_s}]"]).to eql nil
    end

    it "should try to delete a non-existent Datastore from a Cluster, id, id" do
      output = cli_action("onecluster deldatastore #{@cluster_id} 123456", false).stderr
      expect(output).to match(/Error getting datastore/)
    end

    it "should try to delete a non-existent Datastore from a Cluster, name, name" do
      output = cli_action("onecluster deldatastore test_cluster non-existent", false).stderr
      expect(output).to match(/DATASTORE named non-existent not found/)
    end
  end

  ##############################################################################
  # VNET CREATION
  ##############################################################################
  context "vnet creation" do
    after(:each) do
      `onevnet delete test_vnet`
      `onecluster delete test_cluster`
    end

    # onevnet
    #   * create <file>
    #        Creates a new Vnet from the given template file
    it "should create a Vnet in the default Cluster" do
      cli_create("onevnet create", "NAME = test_vnet\nVN_MAD=dummy\nBRIDGE=vbr0")

      expect(cli_action_xml("onevnet show test_vnet -x")['CLUSTERS/ID']).to eql("0")
    end

    it "should create a Vnet in a Cluster, numeric id" do
      id = cli_create("onecluster create test_cluster")

      cli_create("onevnet create --cluster #{id}", "NAME = test_vnet\nVN_MAD=dummy\nBRIDGE=vbr0")

      xml_vnet = cli_action_xml("onevnet show test_vnet -x")
      expect(xml_vnet["CLUSTERS/ID[.=#{id}]"]).to eql(id.to_s)
    end

    it "should create a Vnet in a Cluster, by name" do
      id = cli_create("onecluster create test_cluster")

      cli_create(
        "onevnet create --cluster test_cluster",
        "NAME = test_vnet\nVN_MAD=dummy\nBRIDGE=vbr0")

      xml_vnet = cli_action_xml("onevnet show test_vnet -x")
      expect(xml_vnet["CLUSTERS/ID[.=#{id}]"]).to eql(id.to_s)
    end

    it "should try to create a Vnet in a non-existent Cluster, by name" do
      output = cli_create(
        "onevnet create --cluster non-existent",
        "NAME = test_vnet\nVN_MAD=dummy\nBRIDGE=vbr0", false).stderr

      expect(output).to match(/CLUSTER named non-existent not found/)
    end

    it "should try to create a Vnet in a non-existent Cluster, numeric id" do
      output = cli_create(
        "onevnet create --cluster 123456",
        "NAME = test_vnet\nVN_MAD=dummy\nBRIDGE=vbr0", false).stderr

      expect(output).to match(/Error getting cluster/)
    end
  end

  ##############################################################################
  # VNET OPERATIONS
  ##############################################################################
  context "vnet operations" do
    before(:each) do
      @vnet_id    = cli_create("onevnet create", "NAME = test_vnet\nVN_MAD=dummy\nBRIDGE=vbr0")
      @cluster_id = cli_create("onecluster create test_cluster")

      cli_action("onecluster delvnet default #{@vnet_id}")
    end

    after(:each) do
      `onevnet delete test_vnet`

      `onecluster delete test_cluster`
      `onecluster delete new_cluster`
    end

    #   * addvnet <clusterid> <vnetid>
    #        Adds a Vnet to the given Cluster
    it "should add a Vnet, not assigned to any Cluster, to a Cluster, id, id" do
      cli_action("onecluster addvnet #{@cluster_id} #{@vnet_id}")

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["VNETS/ID[.=#{@vnet_id}]"]).not_to be nil

      xml_vnet = cli_action_xml("onevnet show test_vnet -x")
      expect(xml_vnet["CLUSTERS/ID[.=#{@cluster_id.to_s}]"]).to eql(@cluster_id.to_s)
    end

    it "should add a Vnet, not assigned to any Cluster, to a Cluster, name, name" do
      cli_action("onecluster addvnet test_cluster test_vnet")

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["VNETS/ID[.=#{@vnet_id}]"]).not_to be nil

      xml_vnet = cli_action_xml("onevnet show test_vnet -x")
      expect(xml_vnet["CLUSTERS/ID[.=#{@cluster_id.to_s}]"]).to eql(@cluster_id.to_s)
    end

    it "should add a Vnet, assigned to a Cluster, to another Cluster, id, id" do
      cli_action("onecluster addvnet #{@cluster_id} #{@vnet_id}")

      id = cli_create("onecluster create new_cluster")

      cli_action("onecluster addvnet #{id} #{@vnet_id}")

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["VNETS/ID[.=#{@vnet_id}]"]).not_to be nil

      xml_cluster = cli_action_xml("onecluster show #{id} -x")
      expect(xml_cluster["VNETS/ID[.=#{@vnet_id}]"]).not_to be nil

      xml_vnet = cli_action_xml("onevnet show test_vnet -x")
      expect(xml_vnet["CLUSTERS/ID[.=#{id}]"]).to eql(id.to_s)
      expect(xml_vnet["CLUSTERS/ID[.=#{@cluster_id}]"]).to eql(@cluster_id.to_s)
    end

    it "should add a Vnet, assigned to a Cluster, to another Cluster, name, name" do
      cli_action("onecluster addvnet test_cluster test_vnet")

      id = cli_create("onecluster create new_cluster")

      cli_action("onecluster addvnet new_cluster test_vnet")

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["VNETS/ID[.=#{@vnet_id}]"]).not_to be nil

      xml_cluster = cli_action_xml("onecluster show #{id} -x")
      expect(xml_cluster["VNETS/ID[.=#{@vnet_id}]"]).not_to be nil

      xml_vnet = cli_action_xml("onevnet show test_vnet -x")
      expect(xml_vnet["CLUSTERS/ID[.=#{id}]"]).to eql(id.to_s)
      expect(xml_vnet["CLUSTERS/ID[.=#{@cluster_id}]"]).to eql(@cluster_id.to_s)
    end

    it "should try to add a Vnet, not assigned to any Cluster, to a non-existent Cluster, id, id" do
      output = cli_action("onecluster addvnet 123456 #{@vnet_id}", false).stderr
      expect(output).to match(/Error getting cluster/)

      xml_vnet = cli_action_xml("onevnet show test_vnet -x")
      expect(xml_vnet["CLUSTERS/ID"]).to eql nil
    end

    it "should try to add a Vnet, not assigned to any Cluster, to a non-existent Cluster, name, name" do
      output = cli_action("onecluster addvnet non-existent test_vnet", false).stderr
      expect(output).to match(/CLUSTER named non-existent not found/)

      xml_vnet = cli_action_xml("onevnet show test_vnet -x")
      expect(xml_vnet["CLUSTERS/ID"]).to eql nil
    end

    it "should try to add a Vnet, assigned to a Cluster, to a non-existent Cluster, id, id" do
      cli_action("onecluster addvnet #{@cluster_id} #{@vnet_id}")

      output = cli_action("onecluster addvnet 123456 #{@vnet_id}", false).stderr
      expect(output).to match(/Error getting cluster/)

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["VNETS/ID[.=#{@vnet_id}]"]).not_to be nil

      xml_vnet = cli_action_xml("onevnet show test_vnet -x")
      expect(xml_vnet["CLUSTERS/ID[.=#{@cluster_id.to_s}]"]).to eql(@cluster_id.to_s)
    end

    it "should try to add a Vnet, assigned to a Cluster, to a non-existent Cluster, name, name" do
      cli_action("onecluster addvnet #{@cluster_id} #{@vnet_id}")

      output = cli_action("onecluster addvnet non-existent test_vnet", false).stderr
      expect(output).to match(/CLUSTER named non-existent not found/)

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["VNETS/ID[.=#{@vnet_id}]"]).not_to be nil

      xml_vnet = cli_action_xml("onevnet show test_vnet -x")
      expect(xml_vnet["CLUSTERS/ID[.=#{@cluster_id.to_s}]"]).to eql(@cluster_id.to_s)
    end

    it "should try to add a non-existent Vnet to a Cluster, numeric id" do
      output = cli_action("onecluster addvnet #{@cluster_id} 123456", false).stderr
      expect(output).to match(/Error getting virtual network/)

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["VNETS/ID[.=#{123456}]"]).to be nil
    end

    it "should try to add a non-existent Vnet to a Cluster, by name" do
      output = cli_action("onecluster addvnet test_cluster non-existent", false).stderr
      expect(output).to match(/VNET named non-existent not found/)
    end

    it "should try to add a non-existent Vnet to a non-existent Cluster, numeric id" do
      output = cli_action("onecluster addvnet 123456 123456", false).stderr
      expect(output).to match(/Error getting cluster/)
    end

    it "should try to add a non-existent Vnet to a non-existent Cluster, by name" do
      output = cli_action("onecluster addvnet non-existent non-existent", false).stderr
      expect(output).to match(/CLUSTER named non-existent not found/)
    end

    #   * delvnet <clusterid> <vnetid>
    #        Deletes a Vnet from the given Cluster

    it "should delete a Vnet from its only Cluster, id, id" do
      cli_action("onecluster addvnet #{@cluster_id} #{@vnet_id}")
      cli_action("onecluster delvnet #{@cluster_id} #{@vnet_id}")

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["VNETS/ID[.=#{@vnet_id}]"]).to be nil

      xml_vnet = cli_action_xml("onevnet show test_vnet -x")
      expect(xml_vnet["CLUSTERS/ID[.=#{@cluster_id.to_s}]"]).to eql nil
    end

    it "should delete a Vnet from its only Cluster, name, name" do
      cli_action("onecluster addvnet test_cluster test_vnet")
      cli_action("onecluster delvnet test_cluster test_vnet")

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["VNETS/ID[.=#{@vnet_id}]"]).to be nil

      xml_vnet = cli_action_xml("onevnet show test_vnet -x")
      expect(xml_vnet["CLUSTERS/ID[.=#{@cluster_id.to_s}]"]).to eql nil
    end

    it "should delete a Vnet from one of its Clusters, id, id" do
      id = cli_create("onecluster create new_cluster")

      cli_action("onecluster addvnet #{@cluster_id} #{@vnet_id}")
      cli_action("onecluster addvnet #{id} #{@vnet_id}")

      cli_action("onecluster delvnet #{@cluster_id} #{@vnet_id}")

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["VNETS/ID[.=#{@vnet_id}]"]).to be nil

      xml_vnet = cli_action_xml("onevnet show test_vnet -x")
      expect(xml_vnet["CLUSTERS/ID[.=#{id}]"]).to eql id.to_s
      expect(xml_vnet["CLUSTERS/ID[.=#{@cluster_id.to_s}]"]).to eql nil
    end

    it "should delete a Vnet from one of its Clusters, name, name" do
      id = cli_create("onecluster create new_cluster")

      cli_action("onecluster addvnet test_cluster test_vnet")
      cli_action("onecluster addvnet new_cluster test_vnet")

      cli_action("onecluster delvnet test_cluster test_vnet")

      xml_cluster = cli_action_xml("onecluster show #{@cluster_id} -x")
      expect(xml_cluster["VNETS/ID[.=#{@vnet_id}]"]).to be nil

      xml_vnet = cli_action_xml("onevnet show test_vnet -x")
      expect(xml_vnet["CLUSTERS/ID[.=#{id}]"]).to eql id.to_s
      expect(xml_vnet["CLUSTERS/ID[.=#{@cluster_id.to_s}]"]).to eql nil
    end

    it "should try to delete a non-existent Vnet from a Cluster, id, id" do
      output = cli_action("onecluster delvnet #{@cluster_id} 123456", false).stderr
      expect(output).to match(/Error getting virtual network/)
    end

    it "should try to delete a non-existent Vnet from a Cluster, name, name" do
      output = cli_action("onecluster delvnet test_cluster non-existent", false).stderr
      expect(output).to match(/VNET named non-existent not found/)
    end
  end
end
