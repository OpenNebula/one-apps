require "base64"
require "init"
require 'lib/DiskResize'
require 'ipaddr'
require 'json'

include DiskResize


#
# functions
#

def get_vm_ip(vm, eth)
    cmd = vm.ssh("ip a s dev #{eth}")

    result = []
    cmd.stdout.split("\n").each do |inetline|
        if inetline.match(/^\s*inet\s.*/)
            inetline = inetline.split
            if inetline.size > 1
                result.push(inetline[1].gsub(/(.*)\/.*/, "\\1"))
            end
        end
    end

    return result
end

def count_ifaces(vm)
    cmd = vm.ssh("ip a")
    ifaces = []
    cmd.stdout.split("\n").each do |line|
        line = line.match(/^[0-9]+:/).to_s
        if !line.empty?
            ifaces.push(line.gsub(/^([0-9]+):.*/, "\\1").to_i)
        end
    end

    return ifaces.count
end

# TODO: translate eth<num> to actual iface<num> in the VM, so we can keep using
# eth names for clarity
def eth2if(vm, eth)
    return eth
end

def onevr_cli(action_string, template=nil, expected_result=true)
    if !template.nil?
        file = Tempfile.new('functionality')
        file << template
        file.flush
        file.close

        action_string += " #{file.path}"
    end

    cmd  = cli_action(action_string, expected_result)

    if expected_result == false
        return cmd
    end
end


#
# DEPLOY
#

shared_examples_for "one_service_bootstrapped" do |vm|
    it 'ONE: service appliance finished with SUCCESS (required)' do
        wait_loop(:success => /bootstrap_success/,
                  :break => /_failure/) do
            cmd = @info[vm][:vm].ssh('cat /etc/one-appliance/status')
            if cmd.stdout =~ /_failure/
                logcmd = @info[vm][:vm].ssh(
                    'cat /var/log/one-appliance/configure.log ;' +
                    'cat /var/log/one-appliance/bootstrap.log ;'
                )
                STDERR.puts(logcmd.stdout)
            end
            cmd.stdout
        end
    end
end

shared_examples_for "one_context" do |vm|
    it "ONE: #{vm.to_s} contextualized (required)" do
        # wait for variables for after-network contextualization to be ready
        wait_loop do
            cmd = @info[vm][:vm].ssh('test -f /var/run/one-context/context.sh.network')
            cmd.success?
        end

        # wait for any contextualization to finish
        wait_loop(:success => true) do
            cmd = @info[vm][:vm].ssh('test -e /var/run/one-context/one-context.lock')
            cmd.fail?
        end

        if @info[:hv] == "VCENTER"
            # the previous is insufficiant so...
            # we wait until all one-context scripts are finished
            wait_loop(:success => true) do
                cmd = @info[vm][:vm].ssh('pgrep -f one-context')
                cmd.fail?
            end
        end
    end
end

shared_examples_for "wait_for_vrouter" do |vms=[:vrouter]|
    vms.each do |vm|
        it "ONE: #{vm} is running" do
            @info[vm][:vm].running?
        end

        # wait for contextualization
        include_examples 'one_context', vm

        # wait for service appliance script
        include_examples 'one_service_bootstrapped', vm

        # wait for keepalived
        include_examples 'vnf_running_keepalived', vm, 'WHATEVER'
    end
end

shared_examples_for "update_keepalived_master" do |vms|
    master_found = false

    it "VROUTER: waiting for one-failover..." do
        vms.each do |vm|
            wait_loop(:success => true,
                      :timeout => 120) do
                cmd = @info[vm][:vm].ssh('cat /run/one-failover.state')
                cmd.success?
            end
        end
    end

    it "VROUTER: searching for keepalived MASTER..." do
        wait_loop(:success => /MASTER/) do
            output = ""
            vms.each do |vm|
                cmd = @info[vm][:vm].ssh("cat /run/one-failover.state")
                state = JSON.parse(cmd.stdout)['state']
                if state =~ /MASTER/
                    @info[:vrouter][:vm] = @info[vm][:vm]
                    @info[:vrouter][:master] = vm
                    master_found = true
                    output = cmd.stdout
                end
            end
            output
        end
    end

    it "VROUTER: verify that keepalived cluster has a MASTER" do
        expect(master_found).to be(true)
    end
end

shared_examples_for 'simulate_failover' do
    it "VROUTER: simulate failover - terminate current MASTER" do
        master = @info[:vrouter][:master]
        vm_id = @info[master][:vm_id]
        cli_action("onevm terminate --hard #{vm_id}")
        @info[master][:vm].done?
    end

    vms = []
    it "VROUTER: find at least one backup server" do
        @info[:vrouter][:vms].each do |vm|
            if vm != @info[:vrouter][:master]
                vms.push(vm)
            end
        end
        vms.size > 0
    end

    # find new :vrouter (master)
    include_examples 'wait_for_vrouter', vms
    include_examples 'update_keepalived_master', vms
end


# VNF

shared_examples_for "prep_vnf" do |as_vrouter, image, hv, prefix, context, vm_image_url, vms|
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info across tests
        @info = {}
        @info[:image] = image
        @info[:prefix] = prefix
        @info[:context] = context
        @info[:bootstrap_checksum] = ""
        @info[:hv] = hv

        @info[:datastore_name] = "#{@defaults[:datastore_name]}"
        @info[:template] = @defaults[:template]
        @info[:network_attach] = @defaults[:network_attach]

        # Store network info
        @info[:vnet_a] = { name: 'vnet_a' }
        @info[:vnet_b] = { name: 'vnet_b' }
        @info[:vnet_mgt] = { name: 'vnet_mgt' }
        @info[:vnet_dmz] = { name: 'vnet_dmz' }

        [:vnet_a, :vnet_b, :vnet_mgt, :vnet_dmz].each do |vnet|
            xml = cli_action_xml("onevnet show '#{@info[vnet][:name]}' -x")
            @info[vnet][:gateway] = xml['TEMPLATE/GATEWAY'].to_s
            @info[vnet][:dns] = xml['TEMPLATE/DNS'].to_s

            network_address = xml['TEMPLATE/NETWORK_ADDRESS'].to_s
            if network_address == ""
                network_address = xml['AR_POOL/AR[AR_ID="0"]/IP'].to_s
            end

            @info[vnet][:network_address] = network_address
            @info[vnet][:network_mask] = xml['TEMPLATE/NETWORK_MASK'].to_s
            # TODO: may break in the future if someone modifies the ranges
            @info[vnet][:first_ip] = xml['AR_POOL/AR[AR_ID="1"]/IP'].to_s
        end

        # vnet ip reservation
        @info[:vnet_dmz_reserved1] = { name: 'vnet_dmz_reserved1' }
        @info[:vnet_dmz_reserved2] = { name: 'vnet_dmz_reserved2' }

        # delete reservations if already exists
        [:vnet_dmz_reserved1, :vnet_dmz_reserved2].each do |vnet|
            xml = cli_action_xml('onevnet list -x') rescue nil
            if xml["VNET[NAME=\"#{@info[vnet][:name]}\"]"]
                cli_action("onevnet delete '#{@info[vnet][:name]}'")
            end
        end

        start_ip = IPAddr.new(@info[:vnet_dmz][:first_ip])
        [:vnet_dmz_reserved1, :vnet_dmz_reserved2].each do |vnet|
            # offset by 5
            5.times {|_| start_ip = start_ip.succ }
            # TODO: hardwired AR_ID
            cli_action("onevnet reserve '#{@info[:vnet_dmz][:name]}'"\
                       " -n '#{@info[vnet][:name]}' -s 5 -a 1"\
                       " -i '#{start_ip}'")
            @info[vnet][:gateway] = @info[:vnet_dmz][:gateway]
            @info[vnet][:dns] = @info[:vnet_dmz][:dns]
            @info[vnet][:network_address] = @info[:vnet_dmz][:network_address]
            @info[vnet][:network_mask] = @info[:vnet_dmz][:network_mask]
        end

        # context template (expand placeholders)
        @info[:context] = @info[:context].gsub(/%VNET_A_GATEWAY%/, @info[:vnet_a][:gateway])
        @info[:context] = @info[:context].gsub(/%VNET_B_GATEWAY%/, @info[:vnet_b][:gateway])
        @info[:context] = @info[:context].gsub(/%VNET_MGT_GATEWAY%/, @info[:vnet_mgt][:gateway])
        @info[:context] = @info[:context].gsub(/%VNET_DMZ_GATEWAY%/, @info[:vnet_dmz][:gateway])

        # import VRouter image if missing
        if cli_action("oneimage show '#{@info[:image]}' >/dev/null", nil).fail?
            cmd = "oneimage create -d '#{@info[:datastore_name]}' --type OS " <<
                    "--name '#{@info[:image]}' " <<
                    "--path '#{@defaults[:tests][@info[:image]][:url]}'"

            cli_create(cmd)
        end

        wait_loop(:success => "READY", :break => "ERROR") {
            xml = cli_action_xml("oneimage show -x '#{@info[:image]}'")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        }

        # import VM image if missing
        if cli_action("oneimage show '#{@info[:image]}_vm' >/dev/null", nil).fail?
            cmd = "oneimage create -d '#{@info[:datastore_name]}' --type OS " <<
                    "--name '#{@info[:image]}_vm' " <<
                    "--path '#{vm_image_url}'"
            cli_create(cmd)
        end

        wait_loop(:success => "READY", :break => "ERROR") {
            xml = cli_action_xml("oneimage show -x '#{@info[:image]}_vm'")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        }
    end

    after(:all) do
        if as_vrouter
            cli_action("onevrouter delete #{@info[:vrouter][:vr_id]}")
            @info[:vrouter][:vms].each do |vm|
                @info[vm][:vm].done?
            end
        else
            cli_action("onevm terminate --hard #{@info[:vnf][:vm_id]}")
            @info[:vnf][:vm].done?
        end

        vms.each do |vm|
            cli_action("onevm terminate --hard #{@info[vm[:name]][:vm_id]}")
            @info[vm[:name]][:vm].done?
        end

        # delete reservations
        [:vnet_dmz_reserved1, :vnet_dmz_reserved2].each do |vnet|
            cli_action("onevnet delete '#{@info[vnet][:name]}'")
        end
    end

    # Fail-fast-begin: Fail all examples in given context if any of the
    # example containing `required` in the description fails
    before(:context) do
        # reset the stopper for every context
        $continue = true
    end

    before(:each) do |example|
        raise StandardError.new "Deploy failed, dependency error" unless $continue
    end

    after(:each) do |example|
        $continue = false if example.exception && \
            example.description.include?('required')
    end
    # Fail-fast-end
end

# VMS

shared_examples_for "deploy_vms" do |vms|
    vms.each do |vm|
        it "VM: deploy #{vm[:name]} (required)" do

            # Clone template and append new content
            tmpl = "vm_#{@info[:template]}_#{vm[:name]}_#{rand(36**8).to_s(36)}"

            vm_tmpl_id = cli_create("onetemplate clone '#{@info[:template]}' '#{tmpl}'")

            if vm[:net]
                # prepare network context
                network_context = <<-EOT
                NIC = [
                  NETWORK = "#{@info[vm[:net]][:name]}",
                  GATEWAY = "#{@info[vm[:net]][:gateway]}",
                  DNS = "#{@info[vm[:net]][:dns]}"
                  ]
                EOT

                context = vm[:context] + network_context
            else
                context = vm[:context]
            end

            # update context
            cli_update("onetemplate update '#{vm_tmpl_id}'", context, true)

            # Instantiate from modified template
            @info[vm[:name]] = {}
            @info[vm[:name]][:vm_dtime] = Time.now.to_i
            @info[vm[:name]][:vm_id] = cli_create("onetemplate instantiate --disk '#{@info[:image]}_vm':cache=unsafe:dev_prefix=#{@info[:prefix]} #{vm_tmpl_id}")
            @info[vm[:name]][:vm] = VM.new(@info[vm[:name]][:vm_id])
            @info[vm[:name]][:vm].running?

            cli_action("onetemplate delete #{vm_tmpl_id}")
        end
    end

    # wait for contextualization and store IPs
    names = vms.map {|x| x[:name]}
    include_examples 'verify_vms', names
end

shared_examples_for "verify_vms" do |vms|
    vms.each do |vm|
        # wait for contextualization
        include_examples 'one_context', vm

        it "VM: #{vm} - store the original static IP" do
            # VM has at least lo, eth0 => 2
            if count_ifaces(@info[vm][:vm]) > 2
                wait_loop(:success => false) do
                    ip = get_vm_ip(@info[vm][:vm], 'eth1')
                    if ip.empty?
                        @info[vm][:ip] = ""
                    else
                        @info[vm][:ip] = ip[0].to_s
                    end
                    @info[vm][:ip].empty?
                end
            end
        end
    end
end

shared_examples_for "vm_attach_nic" do |vm, vnet, ip=""|
    it "VM: attach new #{vnet} NIC (required)" do
        nic_attach_cmd = "onevm nic-attach #{@info[vm][:vm_id]} --network #{@info[vnet][:name]}"

        if ip != ""
            nic_attach_cmd += " --ip #{ip}"
        end

        original_iface_count = count_ifaces(@info[vm][:vm])
        cli_action(nic_attach_cmd)

        @info[vm][:vm].running?

        wait_loop do
            current_iface_count = count_ifaces(@info[vm][:vm])
            current_iface_count > original_iface_count
        end
    end
end

shared_examples_for "vm_attach_nic_external_alias" do |vm, vnet, parent_nic=1|
    it "VM: attach new #{vnet} NIC external alias (required)" do
        vnet_name = @info[vnet][:name]
        vnet_xml = cli_action_xml("onevnet show -x #{vnet_name}")
        vnet_id = vnet_xml["ID"].to_s

        onevr_cli("onevm nic-attach #{@info[vm][:vm_id]} --file", <<-EOT, true)
            NIC_ALIAS = [
                NETWORK_ID = "#{vnet_id}",
                PARENT     = "NIC#{parent_nic}",
                EXTERNAL   = "YES",
                MODEL      = "virtio"
            ]
        EOT

        @info[vm][:vm].running?

        @info[vm][:external_alias] = ''
        wait_loop(:success => false) do
            vm_xml = cli_action_xml("onevm show -x #{@info[vm][:vm_id]}")

            vm_xml.each('/VM/TEMPLATE/NIC_ALIAS') do |nic|
                if nic['NETWORK'].to_s == vnet_name
                    @info[vm][:external_alias] = nic['IP'].to_s
                    break
                end
            end

            @info[vm][:external_alias].empty?
        end
    end
end

shared_examples_for "vm_detach_nic" do |vm, vnet|
    it "VM: detach #{vnet} NIC (required)" do
        vnet_name = @info[vnet][:name]
        #vnet_xml = cli_action_xml("onevnet show -x #{vnet_name}")
        #vnet_id = vnet_xml["ID"].to_s
        vm_xml = cli_action_xml("onevm show -x #{@info[vm][:vm_id]}")

        nic_id = ""
        vm_xml.each('/VM/TEMPLATE/NIC') do |nic|
            if nic['NETWORK'].to_s == vnet_name
                nic_id = nic['NIC_ID'].to_s
                break
            end
        end

        nic_detach_cmd = "onevm nic-detach #{@info[vm][:vm_id]} #{nic_id}"

        original_iface_count = count_ifaces(@info[vm][:vm])
        cli_action(nic_detach_cmd)

        @info[vm][:vm].running?

        wait_loop do
            current_iface_count = count_ifaces(@info[vm][:vm])
            current_iface_count < original_iface_count
        end
    end
end


# Service VNF

shared_examples_for 'deploy_vnf' do |image, hv, prefix, context, vm_image_url, vms|
    # setup globals, prepare images for both VNF and VMs and cleanup
    include_examples 'prep_vnf', false, image, hv, prefix, context, vm_image_url, vms

    it "VNF: deploy as VM (required)" do
        # Clone template and append new content
        tmpl = "vrouter_#{@info[:template]}_#{@info[:image]}_#{rand(36**8).to_s(36)}"
        @info[:tmpl_id] = cli_create("onetemplate clone '#{@info[:template]}' '#{tmpl}'")

        # update context
        cli_update("onetemplate update '#{@info[:tmpl_id]}'", @info[:context], true)

        # Instantiate from modified template
        @info[:vnf] = {}
        @info[:vnf][:vm_dtime] = Time.now.to_i
        @info[:vnf][:vm_id] = cli_create("onetemplate instantiate --disk '#{@info[:image]}':cache=unsafe:dev_prefix=#{@info[:prefix]} #{@info[:tmpl_id]}")
        @info[:vnf][:vm] = VM.new(@info[:vnf][:vm_id])
        @info[:vnf][:vm].running?

        cli_action("onetemplate delete #{@info[:tmpl_id]}")
    end

    # wait for contextualization
    include_examples 'one_context', :vnf

    # wait for service appliance script
    include_examples 'one_service_bootstrapped', :vnf

    # start testing client VMs
    include_examples 'deploy_vms', vms
end

shared_examples_for "vm_update_context" do |vm, context_params|
    it "VNF: update context (required)" do
        if context_params.empty?
            expect(@info[vm][:context_params]).not_to eq(nil), "No updated context provided!"
            context_params = @info[vm][:context_params]
        end

        # store checksum to signal change later
        cmd = @info[vm][:vm].ssh('md5sum /var/log/one-appliance/configure.log')
        expect(cmd.success?).to be(true)
        @info[vm][:log_md5sum] = cmd.stdout

        # create context
        xml = cli_action_xml("onevm show -x #{@info[vm][:vm_id]}")
        public_ip = xml['TEMPLATE/CONTEXT/ETH0_IP']
        @info[vm][:vnf_public_ip] = public_ip.to_s

        context_params.each do |param, value|
            if xml.has_elements?("/VM/TEMPLATE/CONTEXT/#{param}")
                xml.delete_element("/VM/TEMPLATE/CONTEXT/#{param}")
            end

            parsed_value = value.gsub(/%VNF_PUBLIC_IP%/, @info[vm][:vnf_public_ip])
            xml.add_element('/VM/TEMPLATE/CONTEXT', param => parsed_value)
        end

        context = xml.template_like_str("TEMPLATE", true, '/TEMPLATE/CONTEXT')
        cli_update("onevm updateconf #{@info[vm][:vm_id]}", <<-EOT, false, true)
            GRAPHICS = [
              LISTEN = "0.0.0.0",
              TYPE = "VNC" ]
            #{context}
        EOT

        @info[vm][:vm].running?
    end

    # wait for contextualization
    include_examples 'one_context', vm

    it "VNF: wait until context update is triggered..." do
        # I have no better way to signal that updateconf really triggered anything...
        # this will wait until service log changes
        wait_loop do
            cmd = @info[vm][:vm].ssh('md5sum /var/log/one-appliance/configure.log')
            # repeat until checksum differs
            (!cmd.stdout.empty?) and (cmd.stdout != @info[vm][:log_md5sum])
        end
    end

    # wait for service appliance script
    include_examples 'one_service_bootstrapped', vm
end


# VROUTER

shared_examples_for 'deploy_vrouter' do |image, hv, prefix, context, vrouter_template,  vm_image_url, vms, count=1|
    # setup globals, prepare images for both VNF and VMs and cleanup
    include_examples 'prep_vnf', true, image, hv, prefix, context, vm_image_url, vms

    it "VROUTER: deploy as vrouter (required)" do
        # Clone template and append new content
        tmpl = "vrouter_#{@info[:template]}_#{@info[:image]}_#{rand(36**8).to_s(36)}"
        @info[:tmpl_id] = cli_create("onetemplate clone '#{@info[:template]}' '#{tmpl}'")

        # update context
        cli_update("onetemplate update '#{@info[:tmpl_id]}'", @info[:context], true)

        # vrouter context template (expand placeholders)
        vrouter_template = vrouter_template.gsub(/%VNET_A_GATEWAY%/, @info[:vnet_a][:gateway])
        vrouter_template = vrouter_template.gsub(/%VNET_B_GATEWAY%/, @info[:vnet_b][:gateway])
        vrouter_template = vrouter_template.gsub(/%VNET_MGT_GATEWAY%/, @info[:vnet_mgt][:gateway])
        vrouter_template = vrouter_template.gsub(/%VNET_DMZ_GATEWAY%/, @info[:vnet_dmz][:gateway])

        # create vrouter context
        vr_name = "vrouter-#{$$}"
        @info[:vrouter] = {}
        @info[:vrouter][:vr_id] = cli_create("onevrouter create", vrouter_template)

        # Instantiate from modified template
        @info[:vrouter][:vrouter_dtime] = Time.now.to_i
        cli_action("onevrouter instantiate \
                   --disk '#{@info[:image]}':cache=unsafe:dev_prefix=#{@info[:prefix]} \
                   --multiple #{count} --name '#{vr_name}-%i' \
                   '#{@info[:vrouter][:vr_id]}' '#{@info[:tmpl_id]}'")

        # populate vrouters list
        vr_xml = cli_action_xml("onevrouter show -x #{@info[:vrouter][:vr_id]}")
        @info[:vrouter][:vms] = []
        vrouters = vr_xml['VMS'].split.map {|x| x.strip.to_i}
        vrouters.sort.each do |vm_id|
            num = @info[:vrouter][:vms].size + 1
            vr_name = "vr#{num}"
            @info[:vrouter][:vms].push(vr_name)
            @info[vr_name] = {}
            @info[vr_name][:vm] = VM.new(vm_id)
            @info[vr_name][:vm_id] = vm_id
        end

        # save the first as vrouter
        @info[:vrouter][:vm] = @info[@info[:vrouter][:vms][0]][:vm]

        cli_action("onetemplate delete #{@info[:tmpl_id]}")
    end

    # wait for contextualization
    include_examples 'wait_for_vrouter'

    # start testing client VMs
    include_examples 'deploy_vms', vms
end

shared_examples_for "vrouter_attach_nic" do |vnet, mgt=false, float=false, ip=""|
    it "VROUTER: attach new #{vnet} NIC (required)" do
        # store the current interface count
        @info[:vrouter][:vms].each do |vm|
            @info[vm][:iface_count] = count_ifaces(@info[vm][:vm])
        end

        if mgt
            onevr_cli("onevrouter nic-attach #{@info[:vrouter][:vr_id]} --file", <<-EOT, true)
                NIC = [
                  NETWORK = #{@info[vnet][:name]},
                  VROUTER_MANAGEMENT = "YES"
                  ]
            EOT
        else
            nic_attach_cmd = "onevrouter nic-attach #{@info[:vrouter][:vr_id]} --network #{@info[vnet][:name]}"

            if float
                nic_attach_cmd += ' --float'

                if ip == ""
                    ip = @info[vnet][:gateway]
                end
            end

            if ip != ""
                nic_attach_cmd += " --ip #{ip}"
            end

            cli_action(nic_attach_cmd)
        end

        # wait until new interface emerges inside the vm
        @info[:vrouter][:vms].each do |vm|
            old_iface_count = @info[vm][:iface_count]
            # note: zero means that not even loopback was found -> skip
            if old_iface_count > 0
                wait_loop do
                    @info[vm][:iface_count] = count_ifaces(@info[vm][:vm])
                    @info[vm][:iface_count] > old_iface_count
                end
            end
        end
    end
end

shared_examples_for "vrouter_detach_nic" do |vnet|
    it "VROUTER: detach #{vnet} NIC (required)" do
        # store the current interface count
        @info[:vrouter][:vms].each do |vm|
            @info[vm][:iface_count] = count_ifaces(@info[vm][:vm])
        end

        vnet_name = @info[vnet][:name]
        vr_xml = cli_action_xml("onevrouter show -x #{@info[:vrouter][:vr_id]}")
        nic_id = ""
        vr_xml.each('/VROUTER/TEMPLATE/NIC') do |nic|
            if nic['NETWORK'].to_s == vnet_name
                nic_id = nic['NIC_ID'].to_s
                break
            end
        end
        nic_detach_cmd = "onevrouter nic-detach #{@info[:vrouter][:vr_id]} #{nic_id}"
        cli_action(nic_detach_cmd)

        # wait until detached interface disappears
        @info[:vrouter][:vms].each do |vm|
            old_iface_count = @info[vm][:iface_count]
            # note: zero means that not even loopback was found -> skip
            if old_iface_count > 0
                wait_loop do
                    @info[vm][:iface_count] = count_ifaces(@info[vm][:vm])
                    @info[vm][:iface_count] < old_iface_count
                end
            end
        end
    end
end


#
# VNFs
#

# KEEPALIVED

shared_examples_for "vnf_running_keepalived" do |vm, state = ''|
    it "VNF: KEEPALIVED - should be Up & Ready on '#{vm}' (required)" do
        wait_loop(:timeout => 120) do
            cmd = @info[vm][:vm].ssh('pgrep -f /usr/sbin/keepalived')
            cmd.success?
        end
    end

    it "VNF: KEEPALIVED - should run as '#{state}'" do
        wait_loop(:success => true,
                  :timeout => 120) do
            cmd = @info[vm][:vm].ssh('cat /run/one-failover.state')
            cmd.success?
        end
        wait_loop(:success => /#{state}/,
                  :timeout => 120) do
            cmd = @info[vm][:vm].ssh('cat /run/one-failover.state')
            state = JSON.parse(cmd.stdout)['state']
        end if %w[MASTER BACKUP].include?(state)
    end
end

shared_examples_for 'vnf_keepalived_vrid' do |vm, vrids|
    it "VNF: KEEPALIVED - should have a vrrp instance(s) with virtual router id(s) #{vrids.to_s}" do
        logcmd = @info[vm][:vm].ssh('cat /etc/keepalived/conf.d/vrrp.conf')
        cmd = @info[vm][:vm].ssh('grep virtual_router_id /etc/keepalived/conf.d/vrrp.conf')
        expect(cmd.success?).to be(true)
        actual_vrids = cmd.stdout.split("\n").map {|x| x.strip.split[1]}

        vrids = vrids.map {|x| x.to_s}
        expect(actual_vrids).to match_array(vrids), logcmd.stdout
    end
end

shared_examples_for 'vnf_keepalived_password' do |vm, pass|
    it "VNF: KEEPALIVED - should have a vrrp instance(s) with password(s) #{pass.to_s}" do
        logcmd = @info[vm][:vm].ssh('cat /etc/keepalived/conf.d/vrrp.conf')
        cmd = @info[vm][:vm].ssh('grep auth_pass /etc/keepalived/conf.d/vrrp.conf')
        expect(cmd.success?).to be(true)
        actual_pass = cmd.stdout.split("\n").map {|x| x.strip.split[1]}

        pass = pass.map {|x| x.to_s}
        expect(actual_pass).to match_array(pass), logcmd.stdout
    end
end


# DHCP4

shared_examples_for "vnf_dhcp4_running" do |vm, enabled, ifaces = nil|
    it "VNF: DHCP4 - one-dhcp4 service should be #{enabled ? 'started' : 'stopped'}" do
        wait_loop(:success => /status: #{enabled ? 'started' : 'stopped'}/,
                  :timeout => 120) do
            cmd = @info[vm][:vm].ssh('rc-service one-dhcp4 status')
            cmd.stdout.lines.first
        end
    end

    it "VNF: DHCP4 - wait for process to emerge/disappear..." do
        wait_loop(:success => enabled,
                  :timeout => 120) do
            # search for process
            cmd = @info[vm][:vm].ssh('pgrep -f /usr/sbin/kea-dhcp4')
            cmd.success?
        end
    end

    it "VNF: DHCP4 - should be #{enabled ? 'enabled' : 'disabled'}" do
        # save log if dhcp should be running
        if enabled
            cmd = @info[vm][:vm].ssh('cat /etc/kea/kea-dhcp4.conf')
            expect(cmd.success?).to be(true)
            kea_config = JSON.parse(cmd.stdout)
            logfile = kea_config["Dhcp4"]["loggers"][0]["output_options"][0]["output"]
            cmd = @info[vm][:vm].ssh("cat #{logfile}")
            expect(cmd.success?).to be(true)
            message = cmd.stdout
        else
            message = "Kea is running..."
        end

        # search for process
        cmd = @info[vm][:vm].ssh('pgrep -f /usr/sbin/kea-dhcp4')
        expect(cmd.success?).to be(enabled), message
    end

    if enabled and ifaces != nil
        include_examples "vnf_dhcp4_interfaces", vm, ifaces
    end
end

shared_examples_for "vnf_dhcp4_interfaces" do |vm, ifaces=[]|
    it "VNF: DHCP4 - listens on #{ifaces}" do
        cmd = @info[vm][:vm].ssh('cat /etc/kea/kea-dhcp4.conf')
        expect(cmd.success?).to be(true)
        kea_config = JSON.parse(cmd.stdout)
        actual_ifaces = kea_config["Dhcp4"]["interfaces-config"]["interfaces"]
        expect(actual_ifaces).to match_array(ifaces), cmd.stdout
    end
end

shared_examples_for "vnf_dhcp4_pool_check" do |vm, vnet|
    it "VNF: DHCP4 - check pool range for #{vnet.to_s}" do
        cmd = @info[vm][:vm].ssh('cat /etc/kea/kea-dhcp4.conf')
        expect(cmd.success?).to be(true)
        kea_config = JSON.parse(cmd.stdout)
        subnets = kea_config["Dhcp4"]["subnet4"]
        found = false
        desired_net = IPAddr.new(@info[vnet][:network_address] + "/" +
                                 @info[vnet][:network_mask])

        subnets.each do |subnet|
            config_net = IPAddr.new(subnet['subnet'])
            if config_net == desired_net
                found = true
                start_ip = config_net.to_range.to_a[2].to_s
                end_ip = config_net.to_range.to_a[-2].to_s
                expect(subnet["pools"][0]["pool"]).to match(/#{start_ip}\s*-\s*#{end_ip}/)
            end
        end

        expect(found).to be(true), cmd.stdout
    end
end

shared_examples_for "vnf_dhcp4_lease_time_check" do |vm, lease|
    it "VNF: DHCP4 - lease time is '#{lease}'" do
        cmd = @info[vm][:vm].ssh('cat /etc/kea/kea-dhcp4.conf')
        expect(cmd.success?).to be(true)
        kea_config = JSON.parse(cmd.stdout)
        actual_lease = kea_config["Dhcp4"]["valid-lifetime"]
        expect(actual_lease.to_s).to eq(lease.to_s), cmd.stdout
    end
end


# DNS

shared_examples_for "vnf_dns_running" do |vm, enabled, ifaces = []|
    it "VNF: DNS - one-dns service should be #{enabled ? 'started' : 'stopped'}" do
        wait_loop(:success => /status: #{enabled ? 'started' : 'stopped'}/,
                  :timeout => 120) do
            cmd = @info[vm][:vm].ssh('rc-service one-dns status')
            cmd.stdout.lines.first
        end
    end

    it "VNF: DNS - wait for process to emerge/disappear..." do
        wait_loop(:success => enabled,
                  :timeout => 120) do
            # search for process
            cmd = @info[vm][:vm].ssh('pgrep -f /usr/sbin/unbound')
            cmd.success?
        end
    end

    it "VNF: DNS - should be #{enabled ? 'enabled' : 'disabled'}" do
        # save log if dns should be running
        if enabled
            logcmd = @info[vm][:vm].ssh('grep -i unbound /var/log/messages')
            # this can break on LXD where /var/log/messages is full of: can't open tty
            #expect(logcmd.success?).to be(true)
            message = logcmd.stdout
        else
            message = "Unbound is running..."
        end

        # search for process
        cmd = @info[vm][:vm].ssh('pgrep -f /usr/sbin/unbound')
        expect(cmd.success?).to be(enabled), message
    end

    if enabled && ifaces != []
        include_examples "vnf_dns_interfaces", vm, true, ifaces
    end
end

shared_examples_for "vnf_dns_interfaces" do |vm, listen=true, ifaces=[]|
    if listen
        it "VNF: DNS - listens on #{ifaces}" do
            cmd = @info[vm][:vm].ssh('cat /etc/unbound/unbound.conf')
            expect(cmd.success?).to be(true)
            config = cmd.stdout

            ifaces.each do |iface|
                expect(config).to match(/^\s*interface:\s*#{iface}\s*$/)
            end
        end
    else
        it "VNF: DNS - does not listen on #{ifaces}" do
            cmd = @info[vm][:vm].ssh('cat /etc/unbound/unbound.conf')
            expect(cmd.success?).to be(true)
            config = cmd.stdout

            ifaces.each do |iface|
                expect(config).not_to match(/^\s*interface:\s*#{iface}\s*$/)
            end
        end
    end
end

shared_examples_for "vnf_dns_resolv_domain" do |vm, domain, resolvable=true|
    if resolvable
        value = 1
    else
        value = 0
    end
    result = ['fail', 'succeed'][value]

    it "VNF: DNS - resolving the domain: '#{domain}' should #{result}" do
        wait_loop(:success => resolvable,
                  :timeout => 60) do
            cmd = @info[vm][:vm].ssh("LANG=C host #{domain}")
            if cmd.success? && !cmd.stdout.strip.empty?
                cmd = @info[vm][:vm].ssh("ping -4 -c 3 -w 5 -q #{domain}")
                if cmd.fail?
                    STDERR.puts cmd.stdout + "\n" + cmd.stderr
                end
                cmd.success?
            else
                STDERR.puts "DNS resolve of domain '#{domain}' failed"
                STDERR.puts cmd.stdout + "\n" + cmd.stderr
                false
            end
        end
    end
end


# ROUTER4

shared_examples_for "vnf_router4" do |vm, enabled, ifaces|
    if enabled
        it 'VNF: ROUTER4 - one-router4 service should be started' do
            wait_loop(:success => /status: started/,
                      :timeout => 120) do
                cmd = @info[vm][:vm].ssh('rc-service one-router4 status')
                cmd.stdout.lines.first
            end
        end
    end

    ifaces.each do |iface|
        it "VNF: ROUTER4 - ip forwarding on the '#{iface}' should be #{enabled ? 'enabled' : 'disabled'}" do
            wait_loop(:success => /net.ipv4.conf.#{iface}.forwarding\s*=\s*#{enabled ? '1' : '0'}/,
                      :timeout => 120) do
                cmd = @info[vm][:vm].ssh("sysctl net.ipv4.conf.#{iface}.forwarding")
                expect(cmd.success?).to be(true)
                cmd.stdout
            end
        end
    end
end

# WireGuard

shared_examples_for "vnf_wg" do |vm, enabled, vpn_vm|
    require 'base64'
    require 'open3'

    def get_wg_info(vm)
        wg = {}

        wait_loop(:timeout => 120) do
            xml = vm.xml

            wg[:peer0] = xml['USER_TEMPLATE/ONEGATE_VNF_WG_PEER0']
            wg[:peer1] = xml['USER_TEMPLATE/ONEGATE_VNF_WG_PEER1']
            wg[:peer2] = xml['USER_TEMPLATE/ONEGATE_VNF_WG_PEER2']

            wg[:conf] = xml['USER_TEMPLATE/ONEGATE_VNF_WG_SERVER']
            wg[:tstm] = xml['USER_TEMPLATE/ONEGATE_VNF_WG_SERVER_TIMESTAMP']

            set = [:peer0, :peer1, :peer2, :conf, :tstm].count do |x|
                !wg[x].nil? && !wg[x].empty?
            end

            set == 5
        end

        wg
    end

    if enabled
        it 'VNF: WG - one-wg service should be started' do
            wait_loop(:success => /status: started/,
                      :timeout => 120) do
                cmd = @info[vm][:vm].ssh('rc-service one-wg status')
                cmd.stdout.lines.first
            end
        end

        wg = {}

        it 'VNF: WG - VR should include configuration attributes' do
            wg = get_wg_info(@info[vm][:vm])

            expect(wg).not_to be_empty
        end

        if vm == :vrouter
            it 'VNF: WG - VR should update all VMs part of the virtual router' do
                @info[vm][:vms].each do |vr_name|
                    wgconf = get_wg_info(@info[vr_name][:vm])

                    expect(wgconf).not_to be_empty
                end
            end
        end

        it 'VNF: WG - VR should connect to a VPN VM' do
            File.write('/var/lib/one/wg0.conf', Base64.strict_decode64(wg[:peer1]))

            out, err, status = Open3.capture3("sudo /usr/bin/wg-quick up /var/lib/one/wg0.conf")

            expect(status.success?).to be true

            vm = @info[vpn_vm][:vm]

            vm.wait_ping(vm.xml['//CONTEXT/ETH1_IP'])

            out, err, status = Open3.capture3("sudo /usr/bin/wg-quick down /var/lib/one/wg0.conf")

            expect(status.success?).to be true
        end
    end
end

# NAT

shared_examples_for "vnf_nat" do |vm, enabled, ifaces = []|
    if enabled
        it 'VNF: NAT4 - one-nat4 service should be started' do
            wait_loop(:success => /status: started/,
                      :timeout => 120) do
                cmd = @info[vm][:vm].ssh('rc-service one-nat4 status')
                cmd.stdout.lines.first
            end
        end
    end

    rules_s = ''

    it "VNF: NAT - custom NAT4 chain should exist in the nat table" do
        cmd = @info[vm][:vm].ssh('iptables -t nat -S NAT4-MASQ')
        expect(cmd.success?).to be(true) if enabled
        rules_s = cmd.stdout
    end

    if ifaces.empty?
        it 'VNF: NAT - should be disabled' do
            expect(rules_s).not_to match(/-A NAT4-MASQ .* -j MASQUERADE/)
        end
    else
        ifaces.each do |iface|
            it "VNF: NAT - ip masquerade on the '#{iface}' should be #{enabled ? 'enabled' : 'disabled'}" do
                if enabled
                    expect(rules_s).to match(/-A NAT4-MASQ -o #{iface} -j MASQUERADE/)
                else
                    expect(rules_s).not_to match(/-A NAT4-MASQ -o #{iface} -j MASQUERADE/)
                end
            end
        end
    end
end

shared_examples_for "vnf_nat_verify" do |vm_client, vm_server, vnet|
    it "VNF: NAT - verify that #{vm_client}'s packets are NATed on '#{vnet}' before they reach '#{vm_server}'" do
        # we start server
        server_script = <<-EOT
        #!/bin/sh

        LANG=C
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

        export LANG
        export PATH

        echo $$ > /nat_#{vm_client}.pid

        exec nc -n -w 60 -l -p 2222 -v -s #{@info[vm_server][:ip]}

        EOT

        server_script = Base64.encode64(server_script)
        server_cmd = @info[vm_server][:vm].ssh("echo '#{server_script}' | base64 -d > /nat_#{vm_client}.sh;" +
                                               "chmod 0755 /nat_#{vm_client}.sh;" +
                                               "nohup /bin/sh /nat_#{vm_client}.sh > /nat_#{vm_client}.log 2>&1 &")
        expect(server_cmd.success?).to be(true), server_cmd.stdout

        # we run client request
        client_cmd = @info[vm_client][:vm].ssh("echo | nc -n -w 10 #{@info[vm_server][:ip]} 2222")
        expect(client_cmd.success?).to be(true), client_cmd.stdout

        # we wait until the correct line shows up in the server log with the VNF address (@info[vnet][:gateway])
        wait_loop(:success => /connect to #{@info[vm_server][:ip]}:2222 from #{@info[vnet][:gateway]}:[0-9]/,
                  :timeout => 120) do
            cmd = @info[vm_server][:vm].ssh("cat /nat_#{vm_client}.log")
            cmd.stdout
        end
    end

    it "VNF: NAT - cleanup test env, for '#{vm_client}' on #{vm_server}" do
        cmdpid = @info[vm_server][:vm].ssh("cat /nat_#{vm_client}.pid")
        expect(cmdpid.success?).to be(true), cmdpid.stdout

        # kill netcat so we can use this test again in the another example
        cmd = @info[vm_server][:vm].ssh("kill #{cmdpid.stdout} ; pkill -f /usr/bin/nc")
        wait_loop(:success => true) do
            cmd = @info[vm_server][:vm].ssh('pgrep -f /usr/bin/nc')
            cmd.fail?
        end

        cmd = @info[vm_server][:vm].ssh("rm -f /nat_#{vm_client}.log /nat_#{vm_client}.pid")
        expect(cmd.success?).to be(true)
    end
end

# TODO: can this be fixed in context?
shared_examples_for "vnf_start_script_workaround_nodns" do |vm|
    it "VNF: TODOFIX (#{vm.to_s.upcase}) - workaround the start script issue by starting simple webserver separately" do
        #cmd = @info[vm][:vm].ssh("nohup setsid ruby /var/tmp/simple-webserver.rb &")
        #cmd = @info[vm][:vm].ssh("/bin/bash -c 'nohup ruby /var/tmp/simple-webserver.rb & disown ; true'")
        cmd = @info[vm][:vm].ssh("rc-service ruby-webserver start")
        expect(cmd.success?).to be(true)
    end
end

shared_examples_for "vnf_start_script_workaround_dns" do |vm|
    it "VNF: TODOFIX (#{vm.to_s.upcase}) - workaround the start script issue by starting nginx webserver separately" do
        cmd = @info[vm][:vm].ssh("rc-service nginx start")
        expect(cmd.success?).to be(true)
    end
end

# SDNAT

shared_examples_for "vnf_sdnat_running" do |vm, enabled|
    it "VNF: SDNAT4 - one-sdnat4 service should be #{enabled ? 'started' : 'stopped'}" do
        wait_loop(:success => /status: #{enabled ? 'started' : 'stopped'}/, :timeout => 120) do
            cmd = @info[vm][:vm].ssh('rc-service one-sdnat4 status')
            cmd.stdout.lines.first
        end
    end
end

shared_examples_for "vnf_sdnat_verify" do |vm_client, vm_server|
    it "VNF: SDNAT4 - verify that #{vm_client} is reaching the #{vm_server} via the external alias" do
        wait_loop(:success => /^Hello from: #{@info[vm_server][:ip]}/,
                  :timeout => 30) do
            cmd = @info[vm_client][:vm].ssh("curl 'http://#{@info[vm_server][:external_alias]}:8080'")
            cmd.stdout
        end
    end
end


# LB

shared_examples_for "vnf_lb_running" do |vm, enabled|
    it "VNF: LB - one-lvs service should be #{enabled ? 'started' : 'stopped'}" do
        wait_loop(:success => /status: #{enabled ? 'started' : 'stopped'}/, :timeout => 120) do
            cmd = @info[vm][:vm].ssh('rc-service one-lvs status')
            cmd.stdout.lines.first
        end
    end
end

shared_examples_for "vnf_lb_is_empty" do |vm|
    it "VNF: LB - no LVS should be configured" do
        cmd = @info[vm][:vm].ssh('ipvsadm --save')
        expect(cmd.success?).to be(true)
        expect(cmd.stdout.strip).to eq('')
    end

    it "VNF: LB - no iptables should be configured" do
        cmd = @info[vm][:vm].ssh('iptables -t mangle -S PREROUTING')
        expect(cmd.success?).to be(true)
        expect(cmd.stdout.strip).to eq('-P PREROUTING ACCEPT')
    end
end

shared_examples_for 'vnf_lb_setup_dynamic_real_server' do |vm_lb, vm, lb, protocol, port, server_port|
    it "VNF: LB (#{vm.to_s.upcase}): create dynamic real server (#{protocol}:#{port})" do
        @info[vm][:real_server_ip] = get_vm_ip(@info[vm][:vm], 'eth1')[0]
        expect(@info[vm][:real_server_ip]).not_to eq('')

        cmd = @info[vm][:vm].ssh("onegate vm update --data ONEGATE_LB#{lb}_IP='#{@info[vm_lb][:vnf_public_ip]}' && \
                                  onegate vm update --data ONEGATE_LB#{lb}_PROTOCOL='#{protocol}' && \
                                  onegate vm update --data ONEGATE_LB#{lb}_PORT='#{port}' && \
                                  onegate vm update --data ONEGATE_LB#{lb}_SERVER_HOST='#{@info[vm][:real_server_ip]}' && \
                                  onegate vm update --data ONEGATE_LB#{lb}_SERVER_PORT='#{server_port}'")
        expect(cmd.success?).to be(true)
    end
end

shared_examples_for "vnf_lb_verify" do |vm_lb, port|
    it "VNF: LB - verify that LoadBalancer forwards traffic to real servers" do
        wait_loop(:success => /^Hello from:/,
                  :timeout => 30) do
            uri = URI.parse("http://#{@info[vm_lb][:vnf_public_ip]}:#{port}")
            begin
                response = Net::HTTP.get_response(uri)
                response.body
            rescue
                nil
            end
        end
    end
end

#
# HAProxy
#

shared_examples_for "vnf_haproxy_running" do |vm, enabled|
    it "VNF: HAPROXY - one-haproxy service should be #{enabled ? 'started' : 'stopped'}" do
        wait_loop(:success => /status: #{enabled ? 'started' : 'stopped'}/, :timeout => 120) do
            cmd = @info[vm][:vm].ssh('rc-service one-haproxy status')
            cmd.stdout.lines.first
        end
    end
end

shared_examples_for "vnf_haproxy_is_empty" do |vm|
    it "VNF: HAPROXY - no LB should be configured" do
        cmd = @info[vm][:vm].ssh('cat /etc/haproxy/servers.cfg || echo')
        expect(cmd.success?).to be(true)

        servers_cfg = cmd.stdout.strip
        expect(servers_cfg.empty?).to be(true)
    end
end

shared_examples_for "vnf_haproxy_setup_dynamic_backend_server" do |vm_lb, vm, lb, protocol, port, server_port|
    it "VNF: HAPROXY (#{vm.to_s.upcase}): create dynamic backend server (#{protocol}:#{port})" do
        @info[vm][:backend_server_ip] = get_vm_ip(@info[vm][:vm], 'eth1')[0]
        expect(@info[vm][:backend_server_ip]).not_to eq('')

        cmd = @info[vm][:vm].ssh("onegate vm update --data ONEGATE_HAPROXY_LB#{lb}_IP='#{@info[vm_lb][:vnf_public_ip]}' && \
                                  onegate vm update --data ONEGATE_HAPROXY_LB#{lb}_PORT='#{port}' && \
                                  onegate vm update --data ONEGATE_HAPROXY_LB#{lb}_SERVER_HOST='#{@info[vm][:backend_server_ip]}' && \
                                  onegate vm update --data ONEGATE_HAPROXY_LB#{lb}_SERVER_PORT='#{server_port}'")
        expect(cmd.success?).to be(true)
    end
end

shared_examples_for "vnf_haproxy_verify" do |vm_lb, port|
    it "VNF: HAPROXY - verify that HAPROXY forwards traffic to backend servers" do
        wait_loop(:success => /^Hello from:/,
                  :timeout => 30) do
            uri = URI.parse("http://#{@info[vm_lb][:vnf_public_ip]}:#{port}")
            begin
                response = Net::HTTP.get_response(uri)
                response.body
            rescue
                nil
            end
        end
    end
end

shared_examples_for 'vnf_vm_quadro_vnets_first_verification' do

    # dhcp lease

    it 'VM1: lease an address (required)' do
        cmd = @info['vm1'][:vm].ssh("udhcpc -i eth1 -A 5 -nqf -t 3")
        expect(cmd.success?).to be(true)
    end

    it 'VM1: check that onelease hook is working' do
        @info['vm1'][:leased_ip] = get_vm_ip(@info['vm1'][:vm], 'eth1')[0]

        expect(@info['vm1'][:leased_ip]).to eq(@info['vm1'][:ip])
    end

    it 'VM2: lease an address (required)' do
        cmd = @info['vm2'][:vm].ssh("udhcpc -i eth1 -A 5 -nqf -t 3")
        expect(cmd.success?).to be(true)
    end

    it 'VM2: check that onelease hook is working' do
        @info['vm2'][:leased_ip] = get_vm_ip(@info['vm2'][:vm], 'eth1')[0]

        expect(@info['vm2'][:leased_ip]).to eq(@info['vm2'][:ip])
    end

    it 'VM3: fail to lease an address (required)' do
        cmd = @info['vm3'][:vm].ssh("udhcpc -i eth1 -A 5 -nqf -t 3")
        expect(cmd.success?).to be(false)
    end

    it 'VM4: fail to lease an address (required)' do
        cmd = @info['vm4'][:vm].ssh("udhcpc -i eth1 -A 5 -nqf -t 3")
        expect(cmd.success?).to be(false)
    end

    # setup network for non-dhcp clients again

    it 'VM3: setup networking back (required)' do
        cmd = @info['vm3'][:vm].ssh("ip addr add #{@info['vm3'][:ip]} dev eth1")
        expect(cmd.success?).to be(true)

        defroute = "{ ip r del default || true ; } && ip r add default via #{@info['vm3'][:ip]}"
        cmd = @info['vm3'][:vm].ssh(defroute)
        expect(cmd.success?).to be(true)
    end

    it 'VM4: setup networking back (required)' do
        cmd = @info['vm4'][:vm].ssh("ip addr add #{@info['vm4'][:ip]} dev eth1")
        expect(cmd.success?).to be(true)

        defroute = "{ ip r del default || true ; } && ip r add default via #{@info['vm4'][:ip]}"
        cmd = @info['vm4'][:vm].ssh(defroute)
        expect(cmd.success?).to be(true)
    end

    # pinging

    it 'VNF: DHCP4 - vm1 pings vm2' do
        cmd = @info['vm1'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm2'][:leased_ip]}")
        expect(cmd.success?).to be(true)
    end

    it 'VNF: DHCP4 - vm1 pings vm4' do
        cmd = @info['vm1'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm4'][:ip]}")
        expect(cmd.success?).to be(true)
    end

    it 'VNF: DHCP4 - vm2 pings vm1' do
        cmd = @info['vm2'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm1'][:leased_ip]}")
        expect(cmd.success?).to be(true)
    end

    it 'VNF: DHCP4 - vm2 pings vm4' do
        cmd = @info['vm2'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm4'][:ip]}")
        expect(cmd.success?).to be(true)
    end

    it 'VNF: DHCP4 - vm1 does not ping vm3' do
        cmd = @info['vm1'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm3'][:ip]}")
        expect(cmd.success?).to be(false)
    end

    it 'VNF: DHCP4 - vm2 does not ping vm3' do
        cmd = @info['vm2'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm3'][:ip]}")
        expect(cmd.success?).to be(false)
    end

    it 'VNF: DHCP4 - vm3 does not ping vm1' do
        cmd = @info['vm3'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm1'][:leased_ip]}")
        expect(cmd.success?).to be(false)
    end

    it 'VNF: DHCP4 - vm3 does not ping vm2' do
        cmd = @info['vm3'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm2'][:leased_ip]}")
        expect(cmd.success?).to be(false)
    end

    it 'VNF: DHCP4 - vm3 does not ping vm4' do
        cmd = @info['vm3'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm4'][:ip]}")
        expect(cmd.success?).to be(false)
    end

    it 'VNF: DHCP4 - vm4 does not ping vm1' do
        cmd = @info['vm4'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm1'][:leased_ip]}")
        expect(cmd.success?).to be(false)
    end
end

shared_examples_for 'legacy_vrouter_duo_vnets_verification' do
    # wait for keepalived
    include_examples 'vnf_running_keepalived', :vrouter, 'MASTER'

    # forwarding is enabled on...
    include_examples 'vnf_router4', :vrouter, true, ["eth0", "eth1", "eth2"]

    # NAT is disabled
    include_examples 'vnf_nat', :vrouter, false

    # DHCP4 is disabled
    include_examples 'vnf_dhcp4_running', :vrouter, false

    it 'VROUTER: DNS - should not be running' do
        cmd = @info[:vrouter][:vm].ssh('pgrep -f /usr/sbin/unbound')
        expect(cmd.success?).to be(false)
    end

    # pinging

    it 'VROUTER: vm1 pings vnet_a\'s VIP gateway' do
        wait_loop do
            cmd = @info['vm1'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info[:vnet_a][:gateway]}")
            cmd.success?
        end
    end

    it 'VROUTER: vm2 pings vnet_b\'s VIP gateway' do
        wait_loop do
            cmd = @info['vm2'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info[:vnet_b][:gateway]}")
            cmd.success?
        end
    end

    it 'VROUTER: vm1 pings vm2' do
        cmd = @info['vm1'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm2'][:ip]}")
        expect(cmd.success?).to be(true)
    end

    it 'VROUTER: vm2 pings vm1' do
        cmd = @info['vm2'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm1'][:ip]}")
        expect(cmd.success?).to be(true)
    end
end

shared_examples_for 'legacy_vrouter_trio_vnets_verification' do
    # wait for keepalived
    include_examples 'vnf_running_keepalived', :vrouter, 'MASTER'

    # forwarding is enabled on...
    include_examples 'vnf_router4', :vrouter, true, ["eth0", "eth1", "eth2"]

    # forwarding is disabled on...
    include_examples 'vnf_router4', :vrouter, false, ["eth3"]

    # NAT is disabled
    include_examples 'vnf_nat', :vrouter, false

    # DHCP4 is disabled
    include_examples 'vnf_dhcp4_running', :vrouter, false

    it 'VROUTER: DNS - should not be running' do
        cmd = @info[:vrouter][:vm].ssh('pgrep -f /usr/sbin/unbound')
        expect(cmd.success?).to be(false)
    end

    # pinging

    it 'VROUTER: vm1 pings vnet_a\'s VIP gateway' do
        wait_loop do
            cmd = @info['vm1'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info[:vnet_a][:gateway]}")
            cmd.success?
        end
    end

    it 'VROUTER: vm2 pings vnet_b\'s VIP gateway' do
        wait_loop do
            cmd = @info['vm2'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info[:vnet_b][:gateway]}")
            cmd.success?
        end
    end

    it 'VROUTER: vm1 pings vm2' do
        cmd = @info['vm1'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm2'][:ip]}")
        expect(cmd.success?).to be(true)
    end

    it 'VROUTER: vm2 pings vm1' do
        cmd = @info['vm2'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm1'][:ip]}")
        expect(cmd.success?).to be(true)
    end

    it 'VROUTER: vm1 does not ping vm3' do
        cmd = @info['vm1'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm3'][:ip]}")
        expect(cmd.success?).to be(false)
    end

    it 'VROUTER: vm2 does not ping vm3' do
        cmd = @info['vm2'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm3'][:ip]}")
        expect(cmd.success?).to be(false)
    end

    it 'VROUTER: vm3 does not ping vm1' do
        cmd = @info['vm3'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm1'][:ip]}")
        expect(cmd.success?).to be(false)
    end

    it 'VROUTER: vm3 does not ping vm2' do
        cmd = @info['vm3'][:vm].ssh("ping -4 -I eth1 -c 3 -w 5 -q #{@info['vm2'][:ip]}")
        expect(cmd.success?).to be(false)
    end
end
