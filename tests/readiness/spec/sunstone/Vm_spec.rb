require 'init_functionality'
require 'sunstone_test'
require 'sunstone/Vm'
require 'sunstone/VNet'
require 'sunstone/Template'

RSpec.describe "Sunstone vm tab", :type => 'skip' do

    def deploy_vm(name: "", template: "")
        template_id = create_template(:template => template)
        vm_id = cli_create("onetemplate instantiate #{template_id} --name #{name}")
        xml = cli_action_xml("onevm show #{vm_id} -x")
        wait_vm_lcm_state(vm_id, "LCM_INIT");
        cli_action("onevm deploy #{vm_id} #{@host_id}")
    end

    def create_template(template: "")
        template_id = cli_create("onetemplate create", template)
    end

    def build_vm_template(name: "", networks: [], graphics: "VNC", extra_attributes: "")
        template = <<-EOF
            NAME = #{name}
            CPU = 1
            MEMORY = 128
            GRAPHICS = [ LISTEN="0.0.0.0", TYPE=#{graphics} ]
            #{extra_attributes}
        EOF

        networks.each_with_index { |nic, index|
            nic = { :rdp => "NO", :ssh => "NO", :nic_alias => false }.merge!(nic)
            nic_index = "onetest-NIC#{index}"

            template << "NIC = [ NAME=#{nic_index}, NETWORK=#{nic[:name]}, \
                RDP=#{nic[:rdp]}, SSH=#{nic[:ssh]}]"

            template << "NIC_ALIAS = [ NETWORK=#{nic[:name]}, PARENT=#{nic_index}, \
                RDP=YES, SSH=YES ]" if nic[:nic_alias]
        }

        template
    end

    def build_vnet_template(name, size, extra_attributes)
        template = <<-EOF
            NAME = #{name}
            BRIDGE = br0
            VN_MAD = dummy
            AR=[ TYPE = "IP4", IP = "10.0.0.10", SIZE = "#{size}" ]
            #{extra_attributes}
        EOF
    end

    def wait_host_state(host, state)
        wait_loop(:timeout => 60) do
          xml = cli_action_xml("onehost show #{host} -x")
          OpenNebula::Host::HOST_STATES[xml['STATE'].to_i] == state
        end
    end

    def wait_vm_lcm_state(vm, state)
        wait_loop(:timeout => 120) do
          xml = cli_action_xml("onevm show #{vm} -x")
          OpenNebula::VirtualMachine::LCM_STATE[xml['LCM_STATE'].to_i] == state
        end
    end

    def wait_vm_state(vm, state)
        wait_loop(:timeout => 120) do
          xml = cli_action_xml("onevm show #{vm} -x")
          OpenNebula::VirtualMachine::VM_STATE[xml['STATE'].to_i] == state
        end
    end

    def get_vm_lcm_state(vm)
        xml = nil
        wait_loop(:success => true, :timeout => 60) do
          xml = cli_action_xml("onevm show #{vm} -x")
          !OpenNebula::VirtualMachine::LCM_STATE[xml['LCM_STATE'].to_i].empty?
        end
        lcm_state = OpenNebula::VirtualMachine::LCM_STATE[xml['LCM_STATE'].to_i]
    end

    #----------------------------------------------------------------------
    #----------------------------------------------------------------------

    before(:all) do
        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        @sunstone_test = SunstoneTest.new(@auth)

        # Create cluster
        @cluster_id = cli_create("onecluster create test")

        # Create dummy host
        @host_name = 'localhost'
        @host_id = cli_create("onehost create #{@host_name} -i dummy -v dummy")
        wait_host_state(@host_id, "MONITORED")
        
        @host2_name = '127.0.0.1'
        @host2_id = cli_create("onehost create #{@host2_name} -c #{@cluster_id} -i dummy -v dummy")
        wait_host_state(@host_id, "MONITORED")

        # Create virtual network
        @name_vnet = "test_vnet"
        @vnet_id = cli_create("onevnet create", build_vnet_template(@name_vnet, 10, "INBOUND_AVG_BW=1500"))
        @sunstone_test.wait_resource_create("vnet", @name_vnet)

        # Create datablock image
        @name_img = "test_img"
        @img_id = cli_create("oneimage create --name #{@name_img} --size 100 --type datablock -d default")
        @sunstone_test.wait_resource_create("image", @name_img)

        @vm_id = deploy_vm(
            :name => "test_vm",
            :template => build_vm_template(
                :name => "test_nic_rdp",
                :networks => [{ :name => @name_vnet, :rdp => "YES", :ssh => "YES" }],
                :extra_attributes => "DISK = [ IMAGE=\"#{@name_img}\", IMAGE_UNAME=\"oneadmin\", EXTRA = \"extra\"]"
            )
        )
        @vm_id_charters = deploy_vm(
          :name => "test_vm_charters",
          :template => build_vm_template(
              :name => "test_vm_charters"
          )
        )
        @vm_id_alias = deploy_vm(
            :name => "test_vm_alias",
            :template => build_vm_template(
                :name => "test_alias_rdp",
                :networks => [{ :name => @name_vnet }, { :name => @name_vnet, :nic_alias => true }],
                :graphics => "SPICE",
                :extra_attributes => <<-EOF
                    PCI = [ 
                        CLASS=\"0200\", 
                        TYPE=\"NIC\", 
                        DEVICE=\"1018\", 
                        VENDOR=\"15b3\", 
                        ADDRESS=\"0000:d8:00:5\" 
                    ]
                    DISK = [ 
                        IMAGE=\"#{@name_img}\", 
                        IMAGE_UNAME=\"oneadmin\"
                    ]
                EOF
            )
        )
        @template_with_nets_disabled = create_template(
            :template => build_vm_template(
                :name => "test_vm_nets_disabled",
                :extra_attributes => <<-EOF
                    SUNSTONE = [
                        NETWORK_ALIAS = \"no\",
                        NETWORK_AUTO = \"no\",
                        NETWORK_RDP = \"no\",
                        NETWORK_SSH = \"no\"
                    ]"
                EOF
            )
        )

        @template_with_hot_resize = deploy_vm(
            :name => "test_vm_hot_resize",
            :template => build_vm_template(
                :name => "test_vm_hot_resize",
                :extra_attributes => <<-EOF
                    HOT_RESIZE = [
                        CPU_HOT_ADD_ENABLED = \"YES\",
                        MEMORY_HOT_ADD_ENABLED = \"YES\"
                    ]
                    VCPU_MAX = 2
                    MEMORY_MAX = 512
                EOF
            )
        )

        wait_vm_lcm_state("test_vm", "RUNNING")
        wait_vm_lcm_state("test_vm_charters", "RUNNING")
        wait_vm_lcm_state("test_vm_alias", "RUNNING")
        wait_vm_lcm_state("test_vm_hot_resize", "RUNNING")

        @sunstone_test.login
        @vm = Sunstone::Vm.new(@sunstone_test)
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "should check no duplicated nics" do
        count_nics = @vm.get_nics_vm("test_vm_alias");
        expect(count_nics.length).to eq(3)
    end

    it 'should check nics in dropdown' do
        ips_from_datatable = @vm.get_nics_from_vm_dt('test_vm_alias')

        xml = cli_action_xml("onevm show -x test_vm_alias") rescue nil
        private_ips = xml.retrieve_elements('TEMPLATE/NIC/IP')
        external_ips = xml.retrieve_elements('TEMPLATE/NIC/EXTERNAL_IP')
        alias_ips = xml.retrieve_elements('TEMPLATE/NIC_ALIAS/IP')

        ips = []
        ips.concat(private_ips) unless private_ips.nil?
        ips.concat(external_ips) unless external_ips.nil?
        ips.concat(alias_ips) unless alias_ips.nil?

        ips.each do |ip|
            expect(ips_from_datatable.include?(ip)).to be true
        end
    end

    it "should check disabled interface network" do
        @sunstone_test.wait_resource_create("template", "test_vm_nets_disabled")
        cbs = @vm.find_network_checkboxes("test_vm_nets_disabled")

        expect(cbs[:interface_type]).to be false
        expect(cbs[:net_selection]).to be false
        expect(cbs[:rdp_connection]).to be false
        expect(cbs[:ssh_connection]).to be false
    end

    it "should instantiate a template" do
        hash = { name: "vm_ui", mem: "2", cpu: "0.2" }

        @vm.navigate_instantiate("test_nic_rdp")
        @vm.instantiate(hash)
        @sunstone_test.wait_resource_create("vm", "vm_ui")
    end

    it "should check a template via UI" do
        hash_info = [{ key: "CPU", value: "0.2" }]
        @vm.check(2, "vm_ui", hash_info)
    end

    it "should check vm has an IP alias address" do
        vm_test = "test_vm_alias"
        count_nics = @vm.get_nics_vm(vm_test);
        if count_nics.any?
          datatable = @sunstone_test.get_element_by_css("form#tab_network_form table")
          if(datatable && datatable.displayed?)
                trs = datatable.find_elements(tag_name: "tr")
                if trs.any?
                    trs[2].find_element(:css, "td:first-child").click
                    alias_nic = trs[2].find_element(:xpath, "./following-sibling::tr[1]")
                    values = alias_nic.find_element(:id, "alias_3").text().split("   ")
                    vm = cli_action_xml("onevm show -x #{vm_test}") rescue nil
                    expect(vm["TEMPLATE/NIC_ALIAS/IP"]).not_to be_nil
                end
            end
        end
    end

    it "should add charters" do
      name_vm = "test_vm_charters"
      sleep 10 #this time is required for the calculation of the leases
      snstoneConf = @vm.get_sunstone_config
      @vm.navigate_vm(name_vm)
      @vm.navigate_to_vm_detail_tab('actions_tab-label')
      @vm.add_leases()
      show_vm = cli_action_json("onevm show -j #{name_vm}") rescue nil
      pass = @vm.check_leases(show_vm["VM"]["TEMPLATE"]["SCHED_ACTION"], snstoneConf[:leases])
      expect(pass).to be(true)
    end

    it "should preserve data disk info from template" do
      vm = cli_action_xml("onevm show -x test_vm") rescue nil
      expect(vm["TEMPLATE/DISK/EXTRA"]).to eql "extra"
    end

    it "should create a vm snapshot" do
        snap_name = "test_snap"
        @vm.snapshot("test_vm", snap_name)

        wait_vm_lcm_state("test_vm", "RUNNING")

        @sunstone_test.wait_resource_update('vm', 'test_vm',
            { :key => 'TEMPLATE/SNAPSHOT/NAME', :value => snap_name })

        vm = cli_action_xml("onevm show -x test_vm") rescue nil
        expect(vm["TEMPLATE/SNAPSHOT/NAME"]).to eql snap_name
    end

    it "should create a disk snapshot" do
        snap_name = "disk_snap"
        @vm.disk_snapshot("test_vm_alias", snap_name)

        wait_vm_lcm_state("test_vm_alias", "RUNNING")

        @sunstone_test.wait_resource_update('vm', 'test_vm_alias',
            { :key => 'SNAPSHOTS/SNAPSHOT/NAME', :value => snap_name })

        vm = cli_action_xml("onevm show -x test_vm_alias") rescue nil
        expect(vm["SNAPSHOTS/SNAPSHOT/NAME"]).to eql snap_name
    end

    it "should rename a disk snapshot" do
        snap_rename = "img_snap_rename"
        @vm.snapshot_rename("test_vm_alias", snap_rename)

        wait_vm_lcm_state("test_vm_alias", "RUNNING")

        @sunstone_test.wait_resource_update('vm', 'test_vm_alias',
            { :key => 'SNAPSHOTS/SNAPSHOT/NAME', :value => snap_rename })

        vm = cli_action_xml("onevm show -x test_vm_alias") rescue nil
        expect(vm["SNAPSHOTS/SNAPSHOT/NAME"]).to eql snap_rename
    end

    it "should add labels to vm" do
        arr_labels = [
            'Label With Spaces',
            'label-hyphenated',
            'LABEL_UPPERCASE',
            '  label trimmed  ',
            'label/with_subtree'
        ]
        @vm.add_labels('test_vm', arr_labels)

        vm = cli_action_xml('onevm show -x test_vm') rescue nil
        vm_labels = vm['USER_TEMPLATE/LABELS'].split(',')

        expect(vm_labels).to include 'Label With Spaces'
        expect(vm_labels).to include 'Label-hyphenated'
        expect(vm_labels).to include 'Label_uppercase'
        expect(vm_labels).to include 'Label Trimmed'
        expect(vm_labels).to include 'Label/With_subtree'
    end

    it 'should hot resize memory' do
        @vm.resize_memory('test_vm_hot_resize', '256')

        wait_vm_lcm_state("test_vm_hot_resize", "RUNNING")

        vm = cli_action_xml("onevm show -x test_vm_hot_resize") rescue nil
        expect(vm["TEMPLATE/MEMORY"]).to eql "256"
    end

    it 'should hot resize vcpu' do
        @vm.resize_vcpu('test_vm_hot_resize', '1')

        wait_vm_lcm_state("test_vm_hot_resize", "RUNNING")

        vm = cli_action_xml("onevm show -x test_vm_hot_resize") rescue nil
        expect(vm["TEMPLATE/CPU"]).to eql "1"
    end

    it 'should suspend a VM' do
        @vm.suspend('test_vm')
        wait_vm_state('test_vm', 'SUSPENDED')

        # Check vm state in Sunstone GUI
        expect(@vm.check_vm_states('test_vm', ['SUSPENDED'])).to be true
    end

    it 'should stop a VM' do
        @vm.stop('test_vm')
        wait_vm_lcm_state('test_vm', 'LCM_INIT')
        wait_vm_state('test_vm', 'STOPPED')

        # Check vm state in Sunstone GUI
        expect(@vm.check_vm_states('test_vm', ['STOPPED'])).to be true
    end

    it 'should resume a VM' do
        @vm.resume('test_vm')
        wait_vm_state('test_vm', 'PENDING')

        # Check vm state in Sunstone GUI
        expect(@vm.check_vm_states('test_vm', ['PENDING'])).to be true
    end

    it 'should deploy a VM' do 
        @vm.deploy('test_vm', @host_name)
        wait_vm_lcm_state('test_vm', 'RUNNING')

        # Check vm state in Sunstone GUI
        expect(@vm.check_vm_states('test_vm', ['RUNNING'])).to be true
    end

    it 'should undeploy a VM' do
        @vm.undeploy('test_vm')
        wait_vm_state('test_vm', 'UNDEPLOYED')

        # Check vm state in Sunstone GUI
        expect(@vm.check_vm_states('test_vm', ['UNDEPLOYED'])).to be true
    end

    it "should filtered DS and VNets when selecting a host" do
        hash = { name: "vm_test_filtering", mem: "2", cpu: "0.2" }

        @vm.navigate_instantiate("test_vm_hot_resize")
        @vm.change_instantiation_host("127.0.0.1")
        @vm.check_instantiation_empty_datastores()
        @vm.check_instantiation_empty_vnets()
        @vm.instantiate(hash)
        @sunstone_test.wait_resource_create("vm", "vm_test_filtering")
    end

    it 'should check vm autorefresh with fireedge up' do
        if RSpec.configuration.main_defaults[:manage_fireedge]
            vm_name = 'autorefresh_vm'
            # Instantiate a VM
            hash = { 
                :name => vm_name,
                :mem => '0.5',
                :cpu => '0.2'
            }

            @vm.navigate_instantiate('test_nic_rdp')
            @vm.instantiate(hash)
            # Navigate to VM info tab
            @vm.navigate_vm(vm_name)

            # Deploy VM
            cli_action("onevm deploy #{vm_name} #{@host_id}")

            # Wait until VM is running
            wait_vm_lcm_state(vm_name, 'RUNNING')

            # Evaluate LCM State == RUNNING
            status_td = @sunstone_test.get_element_by_id('lcm_state_value')
            status_val = nil
            begin
                status_val = status_td.find_element(:css, 'label')
            rescue => e
                status_val = status_td
            end

            lcm_status_sunstone = status_val.text
            expect(lcm_status_sunstone).to eql 'RUNNING'
        end
    end
end
