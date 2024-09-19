require 'init'
require 'sunstone_test'
require 'sunstone/Host'
require 'sunstone/VNet'
require 'sunstone/App'
require 'sunstone/Template'
require 'sunstone/Vm'
require 'sunstone/Guacamole'
require 'sunstone/User'
require 'sunstone/CloudView'

RSpec.describe 'Sunstone', :type => 'skip' do

    virt_viewer_file_action = 'save_virt_viewer'
    vnc_action = 'startvnc'
    spice_action = 'startspice'
    guac_vnc_action = 'guac_vnc'
    guac_ssh_action = 'guac_ssh'
    guac_rdp_action = 'guac_rdp'
    rdp_file_action = 'save_rdp'
    SSH_CREDENTIALS = { USERNAME: 'one', PASSWORD: 'opennebula' }

    def deploy_vm(name: "", template: "", wait_until_running: true)
        template_id = cli_create("onetemplate create", template)
        vm_id = cli_create("onetemplate instantiate #{template_id} --name #{name}")
        vm = VM.new(vm_id)

        cli_action("onevm deploy #{vm_id} #{@host_name}", nil) if vm.state == 'PENDING'

        vm.running? if wait_until_running

        return vm
    end

    def build_vm_template(name: "", networks: [], graphics: "VNC", extra_attributes: "")
        template = <<-EOF
            NAME = #{name}
            CPU = 0.1
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

    def wait_host_is_monitored(host)
        xml = cli_action_xml("onehost show -x '#{host}'")

        host = Host.new(xml['ID'])
        host.monitored?
    end

    def wait_vm_is_running(vm_name)
        xml = cli_action_xml("onevm show '#{vm_name}' -x") rescue nil

        vm = VM.new(xml['ID'])
        vm.running?({ :timeout => 600 }) # 10 min
    end

    def wait_image_state(image, state)
        wait_loop(:success => state) do
            xml = cli_action_xml("oneimage show '#{image}' -x")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        end
    end

    def get_vm_info_from_cli(vm_name)
        xml = cli_action_xml("onevm show '#{vm_name}' -x") rescue nil

        vm_state = OpenNebula::VirtualMachine::LCM_STATE[xml['LCM_STATE'].to_i]
        started_time = Time.at( xml['STIME'].to_i ).strftime('%T %d/%m/%Y')

        private_ips = xml.retrieve_elements('TEMPLATE/NIC/IP')
        external_ips = xml.retrieve_elements('TEMPLATE/NIC/EXTERNAL_IP')
        alias_ips = xml.retrieve_elements('TEMPLATE/NIC_ALIAS/IP')

        ips = []
        ips.concat(private_ips) unless private_ips.nil?
        ips.concat(external_ips) unless external_ips.nil?
        ips.concat(alias_ips) unless alias_ips.nil?

        vm_id   = xml['ID'].to_s
        vm_name = xml['NAME'].to_s

        [vm_id, vm_name, vm_state, started_time, ips]
    end

    def script_for_ssh()
        <<-EOF
            # Allow authentication with password
            sudo sed -i '/^[^#]*PasswordAuthentication[[:space:]]no/c\PasswordAuthentication yes' /etc/ssh/sshd_config

            # restart SSH service
            sudo service sshd restart

            # Create user with password
            sudo useradd -p $(openssl passwd -1 #{SSH_CREDENTIALS[:PASSWORD]}) #{SSH_CREDENTIALS[:USERNAME]}
        EOF
    end

    def go_to_sunstone_tab
        # Close all tabs except sunstone tab
        $driver.window_handles.each do |handle|
            next if handle == @sunstone_tab

            # Switch to tab and close it
            $driver.switch_to.window handle
            $driver.close
        end

        # Go to Sunstone
        $driver.switch_to.window(@sunstone_tab)
    end

    def exists_in_system_log?(log, time_ago = 60)
        # get frontend name without '.test'
        frontend_name = @main_defaults[:frontend].split('.test')

        expect(frontend_name[0]).not_to be_nil

        ['/var/log/syslog', '/var/log/messages'].each do |file|
            # get last successful message
            cmd = "grep '#{log}' #{file} | tail -1"
            stdout_str, _, _ = Open3.capture3(cmd)

            next if stdout_str == ''

            # split log line to get datetime at first position
            log_line = stdout_str.split(frontend_name[0])

            expect(log_line[0]).not_to be_nil

            datetime_from_log = DateTime.parse(log_line[0])
            datetime_one_minute_ago = DateTime.now - time_ago

            return datetime_from_log > datetime_one_minute_ago
        end

        return false
    end

    def is_debian9?
        hostname = `hostname`
        hostname.match('debian9') ? true : false
    end

    def is_alma9?
        hostname = `hostname`
        hostname.match('alma9') ? true : false
    end

    def create_resources
        STDERR.puts '==> Creating needed resources...'

        STDERR.puts '==> Creating virtual networks...'
        # Create virtual networks 
        # test_net
        @vnet_id = cli_create("onevnet create", build_vnet_template(@vnet_name_rc, 10, "INBOUND_AVG_BW=1500"))
        @sunstone_test.wait_resource_create('vnet', @vnet_id)
        STDERR.puts "==> Virtual network #{@vnet_name_rc} created"

        # vnet_bridge
        hash = { bridge: 'br0',
                 mode: 'bridge' }

        ad_ranges = [{ type: 'ip4',
                       ip: '192.168.150.100',
                       size: '100' }]

        @vnet.create(@vnet_name, hash, ad_ranges)
        @sunstone_test.wait_resource_create('vnet', @vnet_name)
        STDERR.puts "==> Virtual network #{@vnet_name} created"

        STDERR.puts '==> Creating images...'
        # Create images
        # Datablock image
        @img_id = cli_create("oneimage create --name #{@img_name} --size 100 --type datablock -d default")
        @sunstone_test.wait_resource_create('image', @img_id)
        STDERR.puts "==> Image #{@img_name} created"

        STDERR.puts '==> Creating virtual machines...'
        # Create VMs
        # Windows VM
        wait_image_state(@windows_image_name, 'READY')

        hash = { name: @windows_vm_name }
        vnets = { vnet: [{ name: @vnet_name, rdp: 'yes' }] }

        @vm.navigate_instantiate(@windows_template_name)
        @vm.add_network(vnets, 0)
        @vm.instantiate(hash)

        @sunstone_test.wait_resource_create('vm', @windows_vm_name)
        
        xml = cli_action_xml("onevm show '#{@windows_vm_name}' -x") rescue nil
        @windows_vm = VM.new(xml["ID"])
        cli_action("onevm deploy #{@windows_vm.id} #{@host_name}", nil) if @windows_vm.state == 'PENDING'
        @windows_vm.running?
        STDERR.puts "==> VM #{@windows_vm_name} created"

        # VM with NIC (RDP & SSH activated)
        @vm_one = deploy_vm(
            :name =>  @vm_one_name,
            :template => build_vm_template(
                :name => @vm_one_template_name,
                :networks => [{ :name => @vnet_name_rc, :rdp => 'YES', :ssh => 'YES' }],
                :extra_attributes => "DISK = [ IMAGE=\"#{@img_name}\", IMAGE_UNAME=\"oneadmin\"]"
            )
        )
        STDERR.puts "==> VM #{@vm_one_name} created"

        # VM with NIC alias and SPICE
        @vm_two = deploy_vm(
            :name => @vm_two_name,
            :template => build_vm_template(
                :name => @vm_two_template_name,
                :networks => [
                    { :name => @vnet_name_rc },
                    { :name => @vnet_name_rc, :nic_alias => true }
                ],
                :graphics => 'SPICE',
                :extra_attributes => "DISK = [ IMAGE=\"#{@img_name}\", IMAGE_UNAME=\"oneadmin\" ]"
            ),
            :wait_until_running => false
        )
        STDERR.puts "==> VM #{@vm_two_name} created"
        
        # Alpine VM (from marketplace)
        hash = { app_name: @alpine_app,
                 ds_name: @ds_name }
        @app.download(hash)
        @sunstone_test.wait_resource_create('template', @alpine_template_name)
        @sunstone_test.wait_resource_create('image', @alpine_image_name)
        wait_image_state(@alpine_image_name, 'READY')
        STDERR.puts "==> App #{@alpine_app} downloaded"

        context = {
            configuration: { start_script: script_for_ssh() },
            custom_vars: SSH_CREDENTIALS
        }

        @template.navigate_update(@alpine_template_name)
        @template.update_context(context)
        @template.submit

        @sunstone_test.wait_resource_update(
            'template',
            @alpine_template_name,
            { :key => 'TEMPLATE/CONTEXT/USERNAME', :value => SSH_CREDENTIALS[:USERNAME]  }
        )

        vnets = { vnet: [@vnet_name, { name: @vnet_name, ssh: 'yes' }] }

        @vm.navigate_instantiate(@alpine_template_name)
        @vm.add_network(vnets, 0)
        @vm.instantiate(:name => @alpine_vm_name)

        @sunstone_test.wait_resource_create('vm', @alpine_vm_name)
        
        xml = cli_action_xml("onevm show '#{@alpine_vm_name}' -x") rescue nil
        @alpine_vm = VM.new(xml["ID"])
        cli_action("onevm deploy #{@alpine_vm.id} #{@host_name}", nil) if @alpine_vm.state == 'PENDING'
        @alpine_vm.running?
        STDERR.puts "==> VM #{@alpine_vm_name} created"

        # Change VM permissions
        STDERR.puts "==> Changing Virtual Machines permissions"
        @vm.change_permission(@alpine_vm_name, :other => 'u--')
        @vm.change_permission(@windows_vm_name, :other => 'u--')

        @sunstone_test.wait_resource_update(
            'vm', @alpine_vm_name, { :key => 'PERMISSIONS/OTHER_U', :value => '1' })

        @sunstone_test.wait_resource_update(
            'vm', @windows_vm_name, { :key => 'PERMISSIONS/OTHER_U', :value => '1' })

        STDERR.puts '==> All needed resources were created.'
    end

    #----------------------------------------------------------------------
    #----------------------------------------------------------------------

    before(:all) do
        @client = OpenNebula::Client.new

        user = @client.one_auth.split(':')
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        @auth_oneuser = {
            :username => 'oneuser',
            :password => 'oneuser'
        }

        @sunstone_test = SunstoneTest.new(@auth)
        @host = Sunstone::Host.new(@sunstone_test)
        @vnet = Sunstone::VNet.new(@sunstone_test)
        @app = Sunstone::App.new(@sunstone_test)
        @template = Sunstone::Template.new(@sunstone_test)
        @vm = Sunstone::Vm.new(@sunstone_test)
        @guacamole = Sunstone::Guacamole.new(@sunstone_test)
        @user = Sunstone::User.new(@sunstone_test)
        @cloudview = Sunstone::CloudView.new(@sunstone_test)

        # Hosts names
        @host_name              = RSpec.configuration.main_defaults[:node]

        # Datastores names
        @ds_name                = 'default'
        
        # App names
        @alpine_app             = 'Alpine Linux 3.17'
        
        # Images names
        @alpine_image_name      = @alpine_app
        @img_name               = 'test_img'
        @windows_image_name     = 'windows2012'
        
        # Virtual networks names
        @vnet_name              = 'vnet_bridge'
        @vnet_name_rc           = 'test_vnet'
        
        # Templates names
        @alpine_template_name   = @alpine_app
        @vm_one_template_name   = 'test_vm_rdp_and_ssh'
        @vm_two_template_name   = 'test_alias_rdp_and_spice'
        @windows_template_name  = 'windows2012'
        
        # VMs names
        @alpine_vm_name         = 'Alpine-Linux-3.17'
        @vm_one_name            = 'test_vm_one'
        @vm_two_name            = 'test_vm_two'
        @windows_vm_name        = 'Windows-2012'
        
        wait_host_is_monitored(@host_name)
        
        @sunstone_test.login
        @sunstone_tab = $driver.window_handle
        
        create_resources
    end

    before(:each) do
        sleep 1
    end

    ########################################################################
    # ONEADMIN CHECK REMOTE CONNECTIONS BUTTON
    ########################################################################

    it "should check buttons are enabled for VM with NIC" do
        # Get all remote buttons enable by VM name
        remote_buttons = @vm.get_remote_buttons(@vm_one_name)

        expect(remote_buttons.include?(virt_viewer_file_action)).to be true
        expect(remote_buttons.include?(vnc_action)).to be false
        expect(remote_buttons.include?(spice_action)).to be false

        expect(remote_buttons.include?(guac_vnc_action)).to be true
        expect(remote_buttons.include?(guac_ssh_action)).to be true
        expect(remote_buttons.include?(guac_rdp_action)).to be true

        expect(remote_buttons.include?(rdp_file_action)).to be true
	end

	it "should check buttons are enabled for VM with NIC Alias" do
        begin
            @vm_two.running?

            # Get all remote buttons enable by VM name
            remote_buttons = @vm.get_remote_buttons(@vm_two_name)

            expect(remote_buttons.include?(virt_viewer_file_action)).to be true
            expect(remote_buttons.include?(vnc_action)).to be false
            expect(remote_buttons.include?(spice_action)).to be true

            expect(remote_buttons.include?(guac_vnc_action)).to be true
            expect(remote_buttons.include?(guac_ssh_action)).to be true
            expect(remote_buttons.include?(guac_rdp_action)).to be true

            expect(remote_buttons.include?(rdp_file_action)).to be true
        rescue Exception => e
            if is_alma9?
                skip("SPICE doesn't work in Alma 9")
            else 
                raise e 
            end
        end
	end

    ########################################################################
    # REMOTE CONNECTIONS IN ADMIN VIEW BY ONEADMIN USER
    ########################################################################

    it 'should open Guacamole VNC in new tab' do
        @vm.open_remote_connection(@alpine_vm_name, 'guac_vnc', @sunstone_tab)

        expect($driver.title).to eql @alpine_vm_name
    end

    it 'should check Guacamole VNC interface' do
        # connection_state  => 'CONNECTED'
        # vm.state          => 'RUNNING'
        # vm.title          => '#0 - alpine_vm_name'
        # vm.started_time   => 'hh:mm:ss dd/mm/yyyy'
        # vm.ips            => '192.168.150.100\n192.168.150.101'
        # canvas            => Canvas element
        # actions           => Toolbar actions elements on header
        interface = @guacamole.get_info_from_interface

        vm_id, vm_name, vm_state, started_time, ips = get_vm_info_from_cli(@alpine_vm_name)

        xml = cli_action_xml("onevm show '#{@alpine_vm_name}' -x") rescue nil

        ips.each do |ip|
            expect(interface[:vm][:ips].include?(ip)).to be true
        end

        id_exists = interface[:vm][:title].include?("##{vm_id}")
        name_exists = interface[:vm][:title].include?(vm_name)

        expect(id_exists).to be true
        expect(name_exists).to be true
        expect(interface[:vm][:state]).to eql vm_state
        expect(interface[:vm][:started_time]).to eql "Started on: #{started_time}"
        expect(interface[:connection_state]).to eql 'CONNECTED'
        expect(interface[:canvas]).not_to be_nil
        expect(interface[:actions].length).to eql 6
    end

    it 'should open Guacamole SSH in new tab' do
        go_to_sunstone_tab

        @vm.open_remote_connection(@alpine_vm_name, 'guac_ssh', @sunstone_tab)

        expect($driver.title).to eql @alpine_vm_name
    end

    it 'should check Guacamole SSH' do
        go_to_sunstone_tab

        log_str = 'SSH connection successful.'

        expect(exists_in_system_log?(log_str)).to be true
    end

    it 'should open Guacamole RDP in new tab' do
        skip("RDP doesn't work in debian 9") if is_debian9?

        @vm.open_remote_connection(@windows_vm_name, 'guac_rdp', @sunstone_tab)

        expect($driver.title).to eql @windows_vm_name
    end

    it 'should check Guacamole RDP interface' do
        skip("RDP doesn't work in debian 9") if is_debian9?

        STDERR.puts '==> Waiting 15 minutes to enable RDP...' 
        sleep 900 # 15 min

        # connection_state  => 'CONNECTED'
        # vm.state          => 'RUNNING'
        # vm.title          => '#0 - windows_vm_name'
        # vm.started_time   => 'hh:mm:ss dd/mm/yyyy'
        # vm.ips            => '192.168.150.102'
        # canvas            => Canvas element
        # actions           => Toolbar actions elements on header
        interface = @guacamole.get_info_from_interface

        vm_id, vm_name, vm_state, started_time, ips = get_vm_info_from_cli(@windows_vm_name)

        ips.each do |ip|
            expect(interface[:vm][:ips].include?(ip)).to be true
        end

        id_exists = interface[:vm][:title].include?("##{vm_id}")
        name_exists = interface[:vm][:title].include?(vm_name)

        expect(id_exists).to be true
        expect(name_exists).to be true
        expect(interface[:vm][:state]).to eql vm_state
        expect(interface[:vm][:started_time]).to eql "Started on: #{started_time}"
        expect(interface[:connection_state]).to eql 'CONNECTED'
        expect(interface[:canvas]).not_to be_nil
        expect(interface[:actions].length).to eql 7
    end

    ########################################################################
    # CREATE REGULAR USER AND SIGN IN TO HIS ACCOUNT
    ########################################################################

    it 'should create one user with cloud view and log in with it' do
        go_to_sunstone_tab

        username = @auth_oneuser[:username]
        groups = { primary: 'users' }

        @user.create_user(username, groups)

        @sunstone_test.wait_resource_create('user', username)
        xml = cli_action_xml("oneuser show '#{username}' -x") rescue nil

        expect(xml['NAME']).to eql username
        expect(xml['GNAME']).to eql groups[:primary]

        @sunstone_test.sign_out(false)
        @sunstone_test.login(@auth_oneuser)
    end

    ########################################################################
    # REMOTE CONNECTIONS IN CLOUD VIEW BY REGULAR USER
    ########################################################################

    it 'should open Guacamole VNC from cloud view' do
        @cloudview.open_remote_connection(@alpine_vm_name, 'guac_vnc', @sunstone_tab)

        expect($driver.title).to eql @alpine_vm_name
    end

    it 'should check Guacamole VNC interface from cloud view' do
        # connection_state  => 'CONNECTED'
        # vm.state          => 'RUNNING'
        # vm.title          => '#0 - alpine_vm_name'
        # vm.started_time   => 'hh:mm:ss dd/mm/yyyy'
        # vm.ips            => '192.168.150.100\n192.168.150.101'
        # canvas            => Canvas element
        # actions           => Toolbar actions elements on header
        interface = @guacamole.get_info_from_interface

        vm_id, vm_name, vm_state, started_time, ips = get_vm_info_from_cli(@alpine_vm_name)

        xml = cli_action_xml("onevm show '#{@alpine_vm_name}' -x") rescue nil

        ips.each do |ip|
            expect(interface[:vm][:ips].include?(ip)).to be true
        end

        id_exists = interface[:vm][:title].include?("##{vm_id}")
        name_exists = interface[:vm][:title].include?(vm_name)

        expect(id_exists).to be true
        expect(name_exists).to be true
        expect(interface[:vm][:state]).to eql vm_state
        expect(interface[:vm][:started_time]).to eql "Started on: #{started_time}"
        expect(interface[:connection_state]).to eql 'CONNECTED'
        expect(interface[:canvas]).not_to be_nil
        expect(interface[:actions].length).to eql 6
    end

    it 'should open Guacamole SSH from cloud view' do
        go_to_sunstone_tab

        @cloudview.open_remote_connection(@alpine_vm_name, 'guac_ssh', @sunstone_tab)

        expect($driver.title).to eql @alpine_vm_name
    end

    it 'should check Guacamole SSH from cloud view' do
        go_to_sunstone_tab

        log_str = 'SSH connection successful.'

        expect(exists_in_system_log?(log_str)).to be true
    end

    it 'should open Guacamole RDP from cloud view' do
        skip("RDP doesn't work in debian 9") if is_debian9?

        @cloudview.open_remote_connection(@windows_vm_name, 'guac_rdp', @sunstone_tab)

        expect($driver.title).to eql @windows_vm_name
    end

    it 'should check Guacamole RDP interface from cloud view' do
        skip("RDP doesn't work in debian 9") if is_debian9?

        # connection_state  => 'CONNECTED'
        # vm.state          => 'RUNNING'
        # vm.title          => '#0 - windows_vm_name'
        # vm.started_time   => 'hh:mm:ss dd/mm/yyyy'
        # vm.ips            => '192.168.150.102'
        # canvas            => Canvas element
        # actions           => Toolbar actions elements on header
        interface = @guacamole.get_info_from_interface

        vm_id, vm_name, vm_state, started_time, ips = get_vm_info_from_cli(@windows_vm_name)

        ips.each do |ip|
            expect(interface[:vm][:ips].include?(ip)).to be true
        end

        id_exists = interface[:vm][:title].include?("##{vm_id}")
        name_exists = interface[:vm][:title].include?(vm_name)

        expect(id_exists).to be true
        expect(name_exists).to be true
        expect(interface[:vm][:state]).to eql vm_state
        expect(interface[:vm][:started_time]).to eql "Started on: #{started_time}"
        expect(interface[:connection_state]).to eql 'CONNECTED'
        expect(interface[:canvas]).not_to be_nil
        expect(interface[:actions].length).to eql 7
    end

    # Logout and delete all the resources
    after(:all) do
        go_to_sunstone_tab
        @sunstone_test.sign_out

        @vm_one.terminate_hard
        @vm_two.terminate_hard
        @alpine_vm.terminate_hard
        @windows_vm.terminate_hard
        cli_action("onetemplate delete \"#{@alpine_template_name}\" --recursive")
        cli_action("onetemplate delete \"#{@vm_one_template_name}\" --recursive")
        cli_action("onetemplate delete \"#{@vm_two_template_name}\" --recursive")
        cli_action("onevnet delete \"#{@vnet_name_rc}\"")
        cli_action("onevnet delete \"#{@vnet_name}\"")
        cli_action("oneuser delete \"#{@auth_oneuser[:username]}\"")
    end
end
