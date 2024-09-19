require 'init_functionality'
require 'sunstone_test'
require 'sunstone/Vm'

RSpec.describe "Sunstone remote actions", :type => 'skip' do

    virt_viewer_file_action = 'save_virt_viewer'
    vnc_action = 'startvnc'
    spice_action = 'startspice'
    guac_vnc_action = 'guac_vnc'
    guac_ssh_action = 'guac_ssh'
    guac_rdp_action = 'guac_rdp'
    rdp_file_action = 'save_rdp'

    def deploy_vm(name: "", template: "")
        template_id = cli_create("onetemplate create", template)
        vm_id = cli_create("onetemplate instantiate #{template_id} --name #{name}")
        cli_action("onevm deploy #{vm_id} #{@host_id}")

        vm = VM.new(vm_id)
        vm.running?

        return vm
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

    #----------------------------------------------------------------------
    #----------------------------------------------------------------------

    before(:all) do
        @fireedge_is_up = !!RSpec.configuration.main_defaults[:manage_fireedge]

        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        @sunstone_test = SunstoneTest.new(@auth)

        # Create dummy host
        @host_id = cli_create('onehost create localhost -i dummy -v dummy')
        @host = Host.new(@host_id)
        @host.monitored?
        
        # Create virtual network
        @vnet_name = 'test_vnet'
        @vnet_id = cli_create("onevnet create", build_vnet_template(@vnet_name, 10, "INBOUND_AVG_BW=1500"))
        @sunstone_test.wait_resource_create('vnet', @vnet_id)
        
        # Create datablock image
        @img_name = 'test_img'
        @img_id = cli_create("oneimage create --name #{@img_name} --size 100 --type datablock -d default")
        @sunstone_test.wait_resource_create('image', @img_id)

        # Create VM with NIC (RDP & SSH activated)
        @vm_one_name = 'test_vm_one'
        @vm_one = deploy_vm(
            :name => 'test_vm_one',
            :template => build_vm_template(
                :name => 'test_vm_rdp_and_ssh',
                :networks => [{ :name => @vnet_name, :rdp => 'YES', :ssh => 'YES' }],
                :extra_attributes => "DISK = [ IMAGE=\"#{@img_name}\", IMAGE_UNAME=\"oneadmin\"]"
            )
        )

        # Create VM with NIC alias and SPICE
        @vm_two_name = 'test_vm_two'
        @vm_two = deploy_vm(
            :name => 'test_vm_two',
            :template => build_vm_template(
                :name => 'test_alias_rdp_and_spice',
                :networks => [
                    { :name => @vnet_name },
                    { :name => @vnet_name, :nic_alias => true }
                ],
                :graphics => 'SPICE',
                :extra_attributes => "DISK = [ IMAGE=\"#{@img_name}\", IMAGE_UNAME=\"oneadmin\" ]"
            )
        )

        @sunstone_test.login
        @vm = Sunstone::Vm.new(@sunstone_test)
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "should check buttons are enabled for VM with NIC" do
        # Get all remote buttons enable by VM name
        remote_buttons = @vm.get_remote_buttons(@vm_one_name)

        # Virt Viewer file shouldn't be visible in this host because it is a dummy host.
        expect(remote_buttons.include?(virt_viewer_file_action)).to be false
        expect(remote_buttons.include?(vnc_action)).to be !@fireedge_is_up
        expect(remote_buttons.include?(spice_action)).to be false

        expect(remote_buttons.include?(guac_vnc_action)).to be @fireedge_is_up
        expect(remote_buttons.include?(guac_ssh_action)).to be @fireedge_is_up
        expect(remote_buttons.include?(guac_rdp_action)).to be @fireedge_is_up

        expect(remote_buttons.include?(rdp_file_action)).to be true
	end

	it "should check buttons are enabled for VM with NIC Alias" do
        # Get all remote buttons enable by VM name
        remote_buttons = @vm.get_remote_buttons(@vm_two_name)

        # Virt Viewer file shouldn't be visible in this host because it is a dummy host.
        expect(remote_buttons.include?(virt_viewer_file_action)).to be false
        expect(remote_buttons.include?(vnc_action)).to be false
        expect(remote_buttons.include?(spice_action)).to be true

        expect(remote_buttons.include?(guac_vnc_action)).to be @fireedge_is_up
        expect(remote_buttons.include?(guac_ssh_action)).to be false
        expect(remote_buttons.include?(guac_rdp_action)).to be false

        expect(remote_buttons.include?(rdp_file_action)).to be true
	end
end
