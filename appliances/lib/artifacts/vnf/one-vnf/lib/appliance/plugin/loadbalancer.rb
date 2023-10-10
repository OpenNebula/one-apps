# -------------------------------------------------------------------------- #
# Copyright 2002-2022, OpenNebula Project, OpenNebula Systems                #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

# rubocop:disable Style/Next
# rubocop:disable Style/RedundantReturn

# LoadBalancer VNF plugin
class LoadBalancer < Appliance::Plugin

    #
    # plugin interface
    #

    def initialize(app_config, logger)
        super('loadbalancer', app_config, logger)
    end

    def configure(app_config)
        super

        # TODO: how to treat interfaces? Filter out LB addresses?

        # list of LB interfaces (and by extension their vnets via NIC ids)
        @ifaces = []
        if @config.key?('interfaces')
            @ifaces = @config['interfaces']
        end

        # TODO: is this naming scheme always valid: <one-name> == ETH<NIC_ID> ?
        # This will create dict such as this:
        # { 0: "eth0", 3: "eth1" }
        @nic_ids = {}
        @ifaces.each do |nic|
            @nic_ids[nic['one-name'].delete('^0-9')] = nic['real-name']
        end

        # TODO: improve reconfigure on SIGHUP or reload
        # TODO: create and check new custom chain for LB
        execute_cmd("ipvsadm --clear")
        execute_cmd("iptables -t mangle -F PREROUTING")

        #
        # prepare loadbalancer variables
        #

        # TODO: do sanity checks

        # TODO: this will erase the old on reconfigure
        # the following uses lb hash (ip:port:proto;) as keys
        @lbs = {}
        @static_real_servers = {}
        @dynamic_real_servers = {}

        # each lb must have unique index
        @lb_indices = {}

        @lb_configs = nil
        if @config.key?('lbs')
            @lb_configs = @config['lbs']
            unless @lb_configs.is_a?(Array)
                logger.error "VNF LB: List of LBs must be an array - ABORT..."
                return -1
            end
        end

        if @config.key?('fwmark-offset')
            @fwmark_offset = @config['fwmark-offset']
            unless @fwmark_offset.is_a?(Integer) && @fwmark_offset > 0
                @fwmark_offset = 10000
                logger.debug "VNF LB: fwmark must be an integer greater than zero - falling back to the default (#{fwmark_offset})..."
            end
        end

        @lb_onegate_enabled = nil
        if @config.key?('onegate') && (!!@config['onegate'] == @config['onegate'])
            @lb_onegate_enabled = @config['onegate']
        end

        #
        # check that this plugin is actually enabled...
        #

        # possibly skip rest of the configure section
        if @config.key?('enabled') && (!!@config['enabled'] == @config['enabled'])
            unless @config['enabled']
                logger.debug 'VNF LB: LoadBalancer plugin is disabled - no LB will be configured...'
                return 0
            end
        else
            logger.debug "VNF LB: LoadBalancer plugin is not enabled or value is not boolean (#{@config['enabled']}) - no LB will be configured..."
            return 0
        end

        #
        # loop through config and create all validated lbs
        #

        # TODO: improve sanity checks

        @lb_configs.each do |lb_config|
            lb_hash, lb = configure_loadbalancer(
                              @lb_indices,
                              lb_config,
                              @fwmark_offset)

            unless lb
                next
            end

            lb = deploy_loadbalancer(lb, :add)
            unless lb && lb['status'] == :deploy_success
                logger.debug "VNF LB: Failed to setup LoadBalancer: #{lb_hash} - skipping..."
                next
            end

            #
            # prepare global variables
            #

            # store validated lb

            if @lbs.key?(lb_hash)
                logger.debug "VNF LB: Duplicit LoadBalancer (#{lb_hash}) - skipping..."
                next
            else
                @lbs[lb_hash] = lb
            end

            unless @static_real_servers.key?(lb_hash)
                @static_real_servers[lb_hash] = {}
            end

            unless @dynamic_real_servers.key?(lb_hash)
                @dynamic_real_servers[lb_hash] = {}
            end

            #
            # add static real servers
            #

            if lb_config.key?('real-servers')
                real_servers = lb_config['real-servers']
            else
                next
            end

            unless real_servers.is_a?(Array) && (real_servers.count > 0)
                logger.debug 'VNF LB: No static real servers to configure for this LB'
                next
            end

            real_servers.each do |server_config|
                server_hash, real_server = create_real_server(server_config, lb)

                unless real_server
                    logger.debug "VNF LB: Real server config is incomplete - skipping..."
                    next
                end

                real_server = deploy_real_server(real_server, :add)
                unless real_server && real_server['status'] == :deploy_success
                    logger.debug "VNF LB: Failed to setup real server: #{server_hash} - skipping..."
                    next
                end

                # save the static real server to track changes for refresh
                @static_real_servers[lb_hash][server_hash] = real_server

                # TODO: signal that real server was successfully deployed
            end
        end
    end

    def run
        #
        # Dynamic real servers (OneGate)
        #

        # no need to poll OneGate or monitor if we don't have any LB
        return 0 unless @lbs.count > 0

        #
        # search for dynamic real servers if OneGate is enabled
        #

        if @lb_onegate_enabled
            @dynamic_real_servers, rc = refresh_dynamic_real_servers(
                                            @lbs,
                                            @static_real_servers,
                                            @dynamic_real_servers)

            unless rc == 0
                logger.debug 'VNF LB: Failed to refresh dynamic real servers - check OneGate setup...'
            end
        end

        #
        # Refresh / monitoring of real servers section
        #

        # parse current LVS config
        @active_real_servers = get_active_real_servers(@lbs)

        # walk through all LBs and re-add real servers or remove dead ones
        refresh_active_real_servers(
            @lbs,
            @active_real_servers,
            @static_real_servers,
            @dynamic_real_servers)
    end

    def cleanup
        # this is executed on the one-vnf service termination or when the VNF
        # plugin is disabled/stopped
        logger.info 'Cleaning up Loadbalancer (removing all LVS rules)...'
        execute_cmd("ipvsadm --clear")
        execute_cmd("iptables -t mangle -F PREROUTING")
    end

    private

    #
    # other internal methods
    #

    def execute_cmd(cmd_str, logme = true)
        stdout, stderr, rc = Open3.capture3(cmd_str)
        if (rc.exitstatus != 0) && logme
            logger.error "VNF LB ERROR: #{stdout + stderr}"
        end

        return stdout, rc
    end

    def configure_loadbalancer(lb_indices, lb_config, fwmark_offset)
        # gather lb info
        lb = {}
        lb['fwmark'] = nil
        lb['address'] = nil
        lb['protocol'] = nil
        lb['tcp'] = nil
        lb['udp'] = nil
        lb['port'] = nil
        lb['scheduler'] = nil
        lb['method'] = nil
        lb['timeout'] = nil

        # unique index
        if lb_config.key?('index') && lb_config['index'].is_a?(Integer)
            if lb_indices.key?(lb_config['index'].to_i)
                logger.debug "VNF LB: Duplicit LoadBalancer index (#{lb_config['index']}) - skipping..."
                return nil, nil
            else
                lb_indices[lb_config['index'].to_i] = true
            end
        else
            logger.debug "VNF LB: LoadBalancer is missing integer index - skipping..."
            return nil, nil
        end

        # calculate fwmark
        if lb_config.key?('lb-fwmark') && !lb_config['lb-fwmark'].to_s.strip.empty?
            unless lb_config['lb-fwmark'].to_i > 0
                logger.debug "VNF LB: fwmark must be an integer > 0 ('#{lb_config['lb-fwmark']}') - skipping..."
                return nil, nil
            end
            lb['fwmark'] = lb_config['lb-fwmark'].to_i
        else
            # use offset and index instead (safer)
            lb['fwmark'] = fwmark_offset.to_i + lb_config['index'].to_i
        end

        if lb_config.key?('lb-address') && !lb_config['lb-address'].to_s.strip.empty?
            lb['address'] = lb_config['lb-address'].to_s.strip
        else
            logger.debug "VNF LB: LoadBalancer is missing address - skipping..."
            return nil, nil
        end

        if lb_config.key?('lb-port') && !lb_config['lb-port'].to_s.strip.empty?
            lb['port'] = lb_config['lb-port'].to_i
        end

        if lb_config.key?('lb-protocol') && !lb_config['lb-protocol'].to_s.strip.empty?
            lb['protocol'] = lb_config['lb-protocol'].to_s.strip.downcase
            case lb['protocol']
            when 'tcp'
                lb['tcp'] = true
            when 'udp'
                lb['udp'] = true
            when 'both'
                lb['tcp'] = true
                lb['udp'] = true
            else
                logger.debug "VNF LB: Unsupported protocol: '#{lb_config['lb-protocol']}' - skipping..."
                return nil, nil
            end
        end

        # port v protocol sanity check
        if lb['port'] || lb['tcp'] || lb['udp']
            unless lb['port'] && ( lb['tcp'] || lb['udp'] )
                logger.debug "VNF LB: Both port ('#{lb['port']}') and protocol must be set or none - skipping..."
                return nil, nil
            end
        end

        if lb_config.key?('lb-scheduler') && !lb_config['lb-scheduler'].to_s.strip.empty?
          lb['scheduler'] =  lb_config['lb-scheduler'].to_s.strip.downcase
          # TODO: should I validate the value? Currently leaving to ipvsadm
        end

        if lb_config.key?('lb-method') && !lb_config['lb-method'].to_s.strip.empty?
            lb['method'] = lb_config['lb-method'].to_s.strip.downcase
            unless lb_method(lb)
                logger.debug "VNF LB: Unsupported method: '#{lb_config['lb-method']}' - skipping..."
                return nil, nil
            end
        else
            # default is masquerade
            lb['method'] = 'nat'
        end

        if lb_config.key?('lb-timeout') && !lb_config['lb-timeout'].to_s.strip.empty?
            unless lb_config['lb-timeout'].to_i > 0
                logger.debug "VNF LB: Timeout must be an integer > 0 ('#{lb_config['lb-timeout']}') - skipping..."
                return nil, nil
            end
            lb['timeout'] = lb_config['lb-timeout'].to_i
        else
            # default is 10s
            lb['timeout'] = 10
        end

        #
        # return loadbalancer with hash/index
        #

        lb_hash = gen_lb_hash(lb)

        return lb_hash, lb
    end

    # creates just a stub for internal usage
    def create_loadbalancer(lb_config)
        # gather lb info
        lb = {}
        lb['address'] = nil
        lb['protocol'] = nil
        lb['port'] = nil
        lb['tcp'] = nil
        lb['udp'] = nil

        if lb_config.key?('lb-address') && !lb_config['lb-address'].to_s.strip.empty?
            lb['address'] = lb_config['lb-address'].to_s.strip
        else
            return nil, nil
        end

        if lb_config.key?('lb-port') && !lb_config['lb-port'].to_s.strip.empty?
            lb['port'] = lb_config['lb-port'].to_i
        end

        if lb_config.key?('lb-protocol') && !lb_config['lb-protocol'].to_s.strip.empty?
          lb['protocol'] = lb_config['lb-protocol'].to_s.strip.downcase
            case lb['protocol']
            when 'tcp'
                lb['tcp'] = true
            when 'udp'
                lb['udp'] = true
            when 'both'
                lb['tcp'] = true
                lb['udp'] = true
            else
                return nil, nil
            end
        end

        # port v protocol sanity check
        if lb['port'] || lb['tcp'] || lb['udp']
            unless lb['port'] && ( lb['tcp'] || lb['udp'] )
                return nil, nil
            end
        end

        #
        # return loadbalancer with hash/index
        #

        lb_hash = gen_lb_hash(lb)

        return lb_hash, lb
    end

    # sanitize a server config and return validated real server
    def create_real_server(server_config, lb)
        server = {}
        server['lb'] = lb
        server['server-host'] = nil
        server['server-port'] = nil
        server['server-weight'] = nil
        server['server-ulimit'] = nil
        server['server-llimit'] = nil

        # TODO: sanity checks - eg. port must be integer ('x'.to_i makes zero...)
        if server_config.key?('server-host') && !server_config['server-host'].to_s.strip.empty?
          server['server-host'] = server_config['server-host'].to_s.strip
        else
            logger.debug 'VNF LB: Missing mandatory real server host - skipping...'
            return nil, nil
        end

        if server_config.key?('server-port') && !server_config['server-port'].to_s.strip.empty?
            unless server_config['server-port'].to_i >= 0
                logger.debug 'VNF LB: Real server port must be an integer - skipping...'
                return nil, nil
            end
            server['server-port'] = server_config['server-port'].to_i
        end

        if server_config.key?('server-weight') && !server_config['server-weight'].to_s.strip.empty?
            unless server_config['server-weight'].to_i >= 0
                logger.debug 'VNF LB: Server weight must be an integer - ignoring...'
            end
            server['server-weight'] = server_config['server-weight'].to_i
        end

        if server_config.key?('server-ulimit') && !server_config['server-ulimit'].to_s.strip.empty?
            unless server_config['server-ulimit'].to_i >= 0
                logger.debug 'VNF LB: Server upper limit must be an integer - ignoring...'
            end
            server['server-ulimit'] = server_config['server-ulimit'].to_i
        end

        if server_config.key?('server-llimit') && !server_config['server-llimit'].to_s.strip.empty?
            unless server_config['server-llimit'].to_i >= 0
                logger.debug 'VNF LB: Server lower limit must be an integer - ignoring...'
            end
            server['server-llimit'] = server_config['server-llimit'].to_i
        end

        #
        # return real server with hash/index
        #

        rs_hash = "#{server['server-host']}:#{server['server-port']}"

        return rs_hash, server
    end

    def gen_lb_hash(lb)
        return "#{lb['address']}:#{lb['port']}:#{lb['protocol']};"
    end

    def assemble_lb_cmds(lb, cmds = [])

        #
        # assemble ipvsadm command for LB
        #

        case lb['status']
        when :add
            cmd = 'ipvsadm -A'
        when :update
            cmd = 'ipvsadm -E'
        when :delete
            cmd = 'ipvsadm -D'
        end
        undo_cmd = 'ipvsadm -D'

        cmd += " -f #{lb['fwmark']}"
        undo_cmd += " -f #{lb['fwmark']}"

        cmd += " -s #{lb['scheduler']}" if lb['scheduler']

        cmds.append({:cmd => cmd, :undo => undo_cmd})

        #
        # create iptable rule(s) with a firewall mark
        #

        # TODO: improve this with ifaces and chains

        if lb['tcp'] && lb['udp']
            # tcp
            cmd = "iptables -t mangle -A"
            undo_cmd = "iptables -t mangle -D"

            arg = " PREROUTING -d #{lb['address']}"
            arg += " -m tcp -p tcp --dport #{lb['port']}"
            arg += " -j MARK --set-mark #{lb['fwmark']}"

            cmd += arg
            undo_cmd += arg

            cmds.append({:cmd => cmd, :undo => undo_cmd})

            # udp
            cmd = "iptables -t mangle -A"
            undo_cmd = "iptables -t mangle -D"

            arg = " PREROUTING -d #{lb['address']}"
            arg += " -m udp -p udp --dport #{lb['port']}"
            arg += " -j MARK --set-mark #{lb['fwmark']}"

            cmd += arg
            undo_cmd += arg

            cmds.append({:cmd => cmd, :undo => undo_cmd})
        elsif lb['tcp'] || lb['udp']
            cmd = "iptables -t mangle -A"
            undo_cmd = "iptables -t mangle -D"

            arg = " PREROUTING -d #{lb['address']}"
            arg += " -m tcp -p tcp --dport #{lb['port']}" if lb['tcp']
            arg += " -m udp -p udp --dport #{lb['port']}" if lb['udp']
            arg += " -j MARK --set-mark #{lb['fwmark']}"

            cmd += arg
            undo_cmd += arg

            cmds.append({:cmd => cmd, :undo => undo_cmd})
        else
            cmd = "iptables -t mangle -A"
            undo_cmd = "iptables -t mangle -D"

            arg = " PREROUTING -d #{lb['address']}"
            arg += " -j MARK --set-mark #{lb['fwmark']}"

            cmd += arg
            undo_cmd += arg

            cmds.append({:cmd => cmd, :undo => undo_cmd})
        end

        return cmds
    end

    def deploy_loadbalancer(lb, status = :add)
        lb['status'] = status

        unless [:add, :update].include? lb['status']
            logger.error "VNF LB: This is a bug: wrong internal state for deploy of LoadBalancer (status: #{lb['status']})..."
            return nil
        end

        rc = run_cmds(assemble_lb_cmds(lb))

        if rc == 0
            lb['status'] = :deploy_success
        else
            lb['status'] = :deploy_fail
        end

        return lb
    end

    def assemble_rs_cmds(server, cmds = [])
        lb = server['lb']

        case server['status']
        when :add
            cmd = 'ipvsadm -a'
        when :update
            cmd = 'ipvsadm -e'
        when :delete
            cmd = 'ipvsadm -d'
        end
        undo_cmd = 'ipvsadm -d'

        arg = " -f #{lb['fwmark']}"

        if server['server-port']
            arg += " -r #{server['server-host']}:#{server['server-port']}"
        else
            arg += " -r #{server['server-host']}"
        end
        cmd += arg
        undo_cmd += arg

        case server['status']
        when :add,:update
            cmd += " -w #{server['server-weight']}" if server['server-weight']
            cmd += " -x #{server['server-ulimit']}" if server['server-ulimit']
            cmd += " -y #{server['server-llimit']}" if server['server-llimit']
            cmd += " #{lb_method(lb)}"
        end

        cmds.append({:cmd => cmd, :undo => undo_cmd})

        return cmds
    end

    def deploy_real_server(server, status = :add)
        server['status'] = status

        unless [:add, :update].include? server['status']
            logger.error "VNF LB: This is a bug: wrong internal state for deploy of real server (status: #{server['status']})..."
            return nil
        end

        rc = run_cmds(assemble_rs_cmds(server))

        if rc == 0
            server['status'] = :deploy_success
        else
            server['status'] = :deploy_fail
        end

        return server
    end

    def remove_real_server(server)
        server['status'] = :delete

        rc = run_cmds(assemble_rs_cmds(server))

        if rc == 0
            server['status'] = :undeploy_success
        else
            server['status'] = :undeploy_fail
        end

        return server
    end

    def run_cmds(cmds)
        cmds_undo_stack = []
        cmds.each do |cmd_item|
            _, rc = execute_cmd(cmd_item[:cmd])
            if rc.exitstatus != 0
                # revert all previous steps
                cmds_undo_stack.each do |undo_cmd|
                    execute_cmd(undo_cmd) || true
                end
                return -1
            end
            cmds_undo_stack.unshift(cmd_item[:undo])
        end
        return 0
    end

    def lb_method(lb)
        case lb['method']
        when 'nat'
            return '-m'
        when 'dr'
            return '-g'
        end
        return nil
    end

    def refresh_dynamic_real_servers(lbs, static_real_servers, dynamic_real_servers)
        # query OneGate
        output, rc = execute_cmd('onegate service show --json')
        if rc.exitstatus != 0
            return dynamic_real_servers, -1
        end

        oneflow_service = JSON.parse(output)

        # collect all VM IDs inside this OneGate/OneFlow service
        # TODO: verify that those keys are really there
        found_vms = []
        found_roles = oneflow_service['SERVICE']['roles']
        found_roles.each do |role|
            role['nodes'].each do |node|
                _vmid = node['vm_info']['VM']['ID']
                found_vms.append(_vmid.to_i) if !_vmid.to_s.strip.empty?
            end
        end

        # find all relevant context variables from user template
        onegate_lbs = {}
        found_vms.each do |vmid|
            # query OneGate
            output, rc = execute_cmd("onegate vm show --json #{vmid}")
            if rc.exitstatus != 0
                next
            end

            onegate_lbs[vmid] = {}

            vm_info = JSON.parse(output)
            vm_info['VM']['USER_TEMPLATE'].each do |context_var, context_value|
                if m = /^ONEGATE_LB(?<lbindex>[0-9]+)_(?<lbkey>.*)$/.match(context_var)
                    lb_index = m['lbindex'].to_i
                    lb_key = m['lbkey'].to_s.downcase

                    unless onegate_lbs[vmid].key?(lb_index)
                        onegate_lbs[vmid][lb_index] = {}
                    end

                    onegate_lbs[vmid][lb_index][lb_key] = context_value
                end
            end
        end

        # create an empty copy of dynamic real servers
        active_real_servers = {} # to track active setup
        dynamic_real_servers.each do |lb_hash, _|
            active_real_servers[lb_hash] = {}
        end

        # walk through all found dynamic lb configs and add real servers in the
        # case that such lb was configured otherwise skip it
        onegate_lbs.each do |vmid, dyn_lbs|
            dyn_lbs.each do |_, dyn_lb|
                lb_config = {}
                lb_config['lb-address'] = (dyn_lb['ip'] if dyn_lb.key?('ip')) || ""
                lb_config['lb-protocol'] = (dyn_lb['protocol'] if dyn_lb.key?('protocol')) || ""
                lb_config['lb-port'] = (dyn_lb['port'] if dyn_lb.key?('port')) || ""

                # if lb is incomplete then hash is incomplete and no such lb will
                # be found
                lb_hash, lb = create_loadbalancer(lb_config)

                unless lb
                    logger.debug "VNF LB: Dynamic real servers - LoadBalancer designation is incomplete: #{dyn_lb} - skipping..."
                    next
                end

                # skip lb which is not configured
                unless lbs.key?(lb_hash)
                    logger.debug "VNF LB: Dynamic real servers - LoadBalancer does not exist: #{lb_hash} - skipping..."
                    next
                end

                server_config = {}
                server_config['server-host'] = (dyn_lb['server_host'] if dyn_lb.key?('server_host')) || ""
                server_config['server-port'] = (dyn_lb['server_port'] if dyn_lb.key?('server_port')) || ""
                server_config['server-weight'] = (dyn_lb['server_weight'] if dyn_lb.key?('server_weight')) || ""
                server_config['server-ulimit'] = (dyn_lb['server_ulimit'] if dyn_lb.key?('server_ulimit')) || ""
                server_config['server-llimit'] = (dyn_lb['server_llimit'] if dyn_lb.key?('server_llimit')) || ""

                # skip server which does not have at least a host
                if server_config['server-host'].to_s.strip.empty?
                    logger.debug "VNF LB: Dynamic real servers - missing host part: #{dyn_lb} - skipping..."
                    next
                end

                #
                # configure dynamic real servers
                #

                server_hash, real_server = create_real_server(server_config, lbs[lb_hash])

                unless real_server
                    logger.debug "VNF LB: Dynamic real servers - config is incomplete: #{dyn_lb} - skipping..."
                    next
                end

                if static_real_servers[lb_hash].key?(server_hash)
                    # TODO: skip or overwrite...
                    logger.debug "VNF LB: Dynamic real servers - conflict with existing static real server (#{server_hash}) - skipping..."
                    next
                end

                if dynamic_real_servers[lb_hash].key?(server_hash)
                    # update old one but do not deploy - let refresh do that
                    #real_server = deploy_real_server(real_server, :update)
                    true
                else
                    real_server = deploy_real_server(real_server, :add)

                    unless real_server && real_server['status'] == :deploy_success
                        logger.debug "VNF LB: Dynamic real servers - failed to setup: #{server_hash} - skipping..."
                        next
                    end
                end

                # save the dynamic real server to track changes for refresh
                dynamic_real_servers[lb_hash][server_hash] = real_server
                active_real_servers[lb_hash][server_hash] = real_server

                # TODO: signal that real server was successfully deployed
            end
        end

        #
        # delete old real servers configured via OneGate
        #

        dynamic_real_servers.each do |lb_hash, real_servers|
            real_servers.each do |server_hash, real_server|
                if !active_real_servers[lb_hash].key?(server_hash)
                    real_server = remove_real_server(real_server)

                    unless real_server['status'] == :undeploy_success
                        logger.debug "VNF LB: Dynamic real servers - failed to properly remove: #{server_hash}"
                    end
                end
            end
        end
        dynamic_real_servers = active_real_servers

        return dynamic_real_servers, 0
    end

    def refresh_active_real_servers(lbs, active_rs, static_rs, dynamic_rs)
        # we will utilize Healthcheck object running all tests concurrently
        healthcheck = Healthcheck.new

        # record and test all known real servers
        all_rs = {}
        results = {}
        lbs.each do |lb_hash, lb|
            all_rs[lb_hash] = {}
            results[lb_hash] = {}

            # add all static real servers
            static_rs.each do |_, real_servers|
                real_servers.each do |server_hash, real_server|
                    all_rs[lb_hash][server_hash] = real_server
                    results[lb_hash][server_hash] = healthcheck.async.test(real_server)
                end
            end

            # add all dynamic real servers
            dynamic_rs.each do |_, real_servers|
                real_servers.each do |server_hash, real_server|
                    all_rs[lb_hash][server_hash] = real_server
                    results[lb_hash][server_hash] = healthcheck.async.test(real_server)
                end
            end
        end

        # now we can gather the results (one by one)
        all_rs.each do |lb_hash, real_servers|
            real_servers.each do |server_hash, real_server|
                test_result = results[lb_hash][server_hash].value

                if test_result == 0
                    # real server is alive

                    if active_rs[lb_hash].key?(server_hash)
                        # update it
                        real_server = deploy_real_server(real_server, :update)
                    else
                        # re-add it
                        real_server = deploy_real_server(real_server, :add)
                    end

                    unless real_server && real_server['status'] == :deploy_success
                        logger.debug "VNF LB: Failed to refresh real server: #{server_hash} - skipping..."
                        next
                    end
                else
                    # real server is dead

                    # skip it if already is removed
                    next unless active_rs[lb_hash].key?(server_hash)

                    real_server = remove_real_server(real_server)

                    unless real_server['status'] == :undeploy_success
                        logger.debug "VNF LB: Failed to remove dead real server: #{server_hash}"
                    end
                end
            end
        end
    end

    def get_active_real_servers(lbs)
        # initialize active real servers
        active_real_servers = {}
        lbs.each do |lb_hash, _|
            active_real_servers[lb_hash] = {}
        end

        # query ipvsadm
        output, rc = execute_cmd('ipvsadm --save')
        if rc.exitstatus != 0
            return nil
        end

        # parse ipvsadm output and create triplets (fwmark, host, port)
        rs_triplets = []
        output.each_line do |rs|
            rs_triplet = {}

            if m = / -f (?<fwmark>[0-9]+) /.match(rs)
                rs_triplet['fwmark'] = m['fwmark'].to_i
            end

            if m = / -r (?<host>[^:]+):(?<port>[0-9]+) /.match(rs)
                rs_triplet['host'] = m['host'].to_s
                rs_triplet['port'] = m['port'].to_i
            end

            if rs_triplet.key?('fwmark') && rs_triplet.key?('host')
                rs_triplets.append(rs_triplet)
            end
        end

        # for each triplet find lb and create real server
        rs_triplets.each do |rs_triplet|
            lbs.each do |lb_hash, lb|
                next unless lb['fwmark'] == rs_triplet['fwmark']

                server_config = {}
                server_config['server-host'] = rs_triplet['host']

                # to be in sync with the usage in the rest of the plugin:
                #   no port ==> nil
                #
                # therefore ignore port 0 (zero)
                if rs_triplet['port'] > 0
                    server_config['server-port'] = rs_triplet['port']
                end

                server_hash, real_server = create_real_server(server_config, lb)

                unless real_server
                    logger.debug "VNF LB: This is a bug in parsing active real servers (#{rs_triplet}) - skipping..."
                    break
                end

                active_real_servers[lb_hash][server_hash] = real_server
                break
            end
        end

        return active_real_servers
    end
end

# TODO: this deserves more love
class Healthcheck
    include Concurrent::Async

    def test(real_server)
        tcp = real_server['lb']['tcp']
        udp = real_server['lb']['udp']
        timeout = real_server['lb']['timeout']
        host = real_server['server-host']
        port = real_server['server-port']

        result = 0

        if tcp || udp
            result = tcp_check(host, port, timeout) if tcp

            return result unless result == 0

            result = udp_check(host, port, timeout) if udp
        else
            result = ping_check(host, timeout)
        end

        return result
    end

    # shamelessly copied from here:
    # https://spin.atomicobject.com/2013/09/30/socket-connection-timeout-ruby/
    def tcp_connect(host, port, timeout)
      # Convert the passed host into structures the non-blocking calls
      # can deal with
      addr = Socket.getaddrinfo(host, nil)
      sockaddr = Socket.pack_sockaddr_in(port, addr[0][3])

      Socket.new(Socket.const_get(addr[0][0]), Socket::SOCK_STREAM, 0).tap do |socket|
        socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)

        begin
          # Initiate the socket connection in the background. If it doesn't fail
          # immediatelyit will raise an IO::WaitWritable (Errno::EINPROGRESS)
          # indicating the connection is in progress.
          socket.connect_nonblock(sockaddr)

        rescue IO::WaitWritable
          # IO.select will block until the socket is writable or the timeout
          # is exceeded - whichever comes first.
          if IO.select(nil, [socket], nil, timeout)
            begin
              # Verify there is now a good connection
              socket.connect_nonblock(sockaddr)
            rescue Errno::EISCONN
              # Good news everybody, the socket is connected!
            rescue
              # An unexpected exception was raised - the connection is no good.
              socket.close
              raise
            end
          else
            # IO.select returns nil when the socket is not ready before timeout
            # seconds have elapsed
            socket.close
            raise "Connection timeout"
          end
        end
      end
    end

    def cmd_check(cmd_str)
        stdout, stderr, rc = Open3.capture3(cmd_str)

        return stdout, stderr, rc
    end

    # trivial tcp check
    def tcp_check(host, port, timeout)
        result = -1
        begin
            socket = tcp_connect(host, port, timeout)
            result = 0
            socket.close
        rescue
            result = -1
        end

        return result
    end

    # TODO: create a better version...
    # trivial udp check (it will just ping...)
    def udp_check(host, port, timeout)
        return ping_check(host, timeout)
    end

    # trivial ping check (using fping)
    def ping_check(host, timeout)
        _, _, rc = cmd_check("fping -c 1 -t #{timeout * 1000} #{host}")
        return rc.exitstatus
    end
end
# rubocop:enable Style/Next
# rubocop:enable Style/RedundantReturn
