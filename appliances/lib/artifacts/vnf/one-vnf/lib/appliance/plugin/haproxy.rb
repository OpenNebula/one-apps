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

HAPROXY_YML = '/etc/haproxy/haproxy.yml'
HAPROXY_CFG = '/etc/haproxy/haproxy.cfg'

# Haproxy VNF plugin
class Haproxy < Appliance::Plugin

    #
    # plugin interface
    #

    def initialize(app_config, logger)
        super('haproxy', app_config, logger)
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

        #
        # prepare loadbalancer variables
        #

        # TODO: do sanity checks

        # TODO: this will erase the old on reconfigure
        # the following uses lb hash (ip:port:proto;) as keys
        @lbs = {}
        @static_backend_servers = {}
        @dynamic_backend_servers = {}

        # each lb must have unique index
        @lb_indices = {}

        @lb_configs = nil
        if @config.key?('lbs')
            @lb_configs = @config['lbs']
            unless @lb_configs.is_a?(Array)
                logger.error "VNF HAPROXY: List of LBs must be an array - ABORT..."
                return -1
            end
        end

        @haproxy_onegate_enabled = nil
        if @config.key?('onegate') && (!!@config['onegate'] == @config['onegate'])
            @haproxy_onegate_enabled = @config['onegate']
        end

        #
        # check that this plugin is actually enabled...
        #

        # possibly skip rest of the configure section
        if @config.key?('enabled') && (!!@config['enabled'] == @config['enabled'])
            unless @config['enabled']
                logger.debug 'VNF HAPROXY: HAProxy plugin is disabled - no LB will be configured...'
                return 0
            end
        else
            logger.debug "VNF HAPROXY: HAProxy plugin is not enabled or value is not boolean (#{@config['enabled']}) - no LB will be configured..."
            return 0
        end

        #
        # loop through config and create all validated lbs
        #

        # TODO: improve sanity checks

        @lb_configs.each do |lb_config|
            lb_hash, lb = configure_loadbalancer(@lb_indices, lb_config)
            next unless lb

            lb = deploy_loadbalancer(lb, :add)
            unless lb && lb['status'] == :deploy_success
                logger.debug "VNF HAPROXY: Failed to setup LoadBalancer: #{lb_hash} - skipping..."
                next
            end

            #
            # prepare global variables
            #

            # store validated lb

            if @lbs.key?(lb_hash)
                logger.debug "VNF HAPROXY: Duplicit LoadBalancer (#{lb_hash}) - skipping..."
                next
            else
                @lbs[lb_hash] = lb
            end

            unless @static_backend_servers.key?(lb_hash)
                @static_backend_servers[lb_hash] = {}
            end

            unless @dynamic_backend_servers.key?(lb_hash)
                @dynamic_backend_servers[lb_hash] = {}
            end

            #
            # add static backend servers
            #

            if lb_config.key?('backend-servers')
                backend_servers = lb_config['backend-servers']
            else
                next
            end

            unless backend_servers.is_a?(Array) && (backend_servers.count > 0)
                logger.debug 'VNF HAPROXY: No static backend servers to configure for this LB'
                next
            end

            backend_servers.each do |server_config|
                server_hash, backend_server = create_backend_server(server_config, lb)

                unless backend_server
                    logger.debug "VNF HAPROXY: Backend server config is incomplete - skipping..."
                    next
                end

                backend_server = deploy_backend_server(backend_server, :add)
                unless backend_server && backend_server['status'] == :deploy_success
                    logger.debug "VNF HAPROXY: Failed to setup backend server: #{server_hash} - skipping..."
                    next
                end

                # save the static backend server to track changes for refresh
                @static_backend_servers[lb_hash][server_hash] = backend_server

                # TODO: signal that backend server was successfully deployed
            end
        end
    end

    def run
        #
        # Dynamic backend servers (OneGate)
        #

        # no need to poll OneGate or monitor if we don't have any LB
        return 0 unless @lbs.count > 0

        #
        # search for dynamic backend servers if OneGate is enabled
        #

        if @haproxy_onegate_enabled
            @dynamic_backend_servers, rc = refresh_dynamic_backend_servers(
                                            @lbs,
                                            @static_backend_servers,
                                            @dynamic_backend_servers)

            unless rc == 0
                logger.debug 'VNF HAPROXY: Failed to refresh dynamic backend servers - check OneGate setup...'
            end
        end

        #
        # Refresh / monitoring of backend servers section
        #

        # parse current LVS config
        @active_backend_servers = get_active_backend_servers(@lbs)

        # walk through all LBs and re-add backend servers or remove dead ones
        refresh_active_backend_servers(
            @lbs,
            @active_backend_servers,
            @static_backend_servers,
            @dynamic_backend_servers)
    end

    private

    #
    # other internal methods
    #

    def execute_cmd(cmd_str, logme = true)
        stdout, stderr, rc = Open3.capture3(cmd_str)
        if (rc.exitstatus != 0) && logme
            logger.error "VNF HAPROXY ERROR: #{stdout + stderr}"
        end
        return stdout, rc
    end

    def read_haproxy_yml
        if File.exist?(HAPROXY_YML)
            return YAML.safe_load File.read(HAPROXY_YML)
        else
            # default "empty" config
            return {
                'global' => [
                    'log /dev/log local0',
                    'log /dev/log local1 notice',
                    'stats socket /var/run/haproxy.sock mode 666 level admin',
                    'stats timeout 120s',
                    'user haproxy',
                    'group haproxy',
                    'daemon'
                ],
                'defaults' => [
                    'log global',
                    'retries 3',
                    'maxconn 2000',
                    'timeout connect 5s',
                    'timeout client 120s',
                    'timeout server 120s'
                ],
                'frontend' => {},
                'backend' => {}
            }
        end
    end

    def write_haproxy_yml(config)
        File.write HAPROXY_YML, YAML.dump(config)
    end

    def write_haproxy_cfg(config = nil, indent = 4)
        indent, output = ' ' * indent, ''

        if config.nil? or config.empty?
            config = YAML.safe_load File.read(HAPROXY_YML)
        end

        config
            .reject {|section| %w[frontend backend].include? section}
            .each do |section, options|
                output << section << "\n"
                options.each {|option| output << indent << option << "\n"}
            end
        config
            .select {|section| %w[frontend].include? section}
            .each do |section, names|
                names.each do |name, value|
                    output << "#{section} #{name}" << "\n"
                    value['options'].each {|option| output << indent << option << "\n"}
                end
            end
        config
            .select {|section| %w[backend].include? section}
            .each do |section, names|
                names.each do |name, value|
                    output << "#{section} #{name}" << "\n"
                    value['options'].each {|option| output << indent << option << "\n"}
                    value['server'].each do |server, command|
                        output << indent << "server #{server} #{command}" << "\n"
                    end
                end
            end

        File.write HAPROXY_CFG, output
    end

    def reload_haproxy
        write_haproxy_cfg
        _, rc = execute_cmd('rc-service haproxy start && rc-service haproxy reload')
        return rc.exitstatus
    end

    # https://www.haproxy.com/documentation/hapee/latest/onepage/management/#9.3
    def haproxy_show_servers_state
        sock = UNIXSocket.new '/var/run/haproxy.sock'
        sock.puts 'show servers state'

        version = sock.readline.rstrip!
        raise 'haproxy runtime api :show servers state: unsupported version' unless version == '1'

        headers = sock.readline.rstrip!.split[1..]

        backends = {}
        while row = sock.readline.rstrip!
            next if row.empty?
            map = headers.zip(row.split).to_h
            (backends[map['be_name']] ||= {})[map['srv_name']] = map
        end
    rescue EOFError # Haproxy closes the connection unless 'prompt' is sent
        backends
    ensure
        sock.close
    end

    def gen_lb_hash(lb)
        return "#{lb['address']}:#{lb['port']}".unpack('H*')[0]
    end

    def gen_bs_hash(server)
        return "#{server['server-host']}:#{server['server-port']}".unpack('H*')[0]
    end

    def configure_loadbalancer(lb_indices, lb_config)
        # gather lb info
        lb = {}
        lb['address'] = nil
        lb['port'] = nil

        # unique index
        if lb_config.key?('index') && lb_config['index'].is_a?(Integer)
            if lb_indices.key?(lb_config['index'].to_i)
                logger.debug "VNF HAPROXY: Duplicit LoadBalancer index (#{lb_config['index']}) - skipping..."
                return nil, nil
            else
                lb_indices[lb_config['index'].to_i] = true
            end
        else
            logger.debug "VNF HAPROXY: LoadBalancer is missing integer index - skipping..."
            return nil, nil
        end

        if lb_config.key?('lb-address') && !lb_config['lb-address'].to_s.strip.empty?
            lb['address'] = lb_config['lb-address'].to_s.strip
        else
            logger.debug "VNF HAPROXY: LoadBalancer is missing address - skipping..."
            return nil, nil
        end

        if lb_config.key?('lb-port') && !lb_config['lb-port'].to_s.strip.empty?
            lb['port'] = lb_config['lb-port'].to_i
        end

        # port sanity check
        unless lb['port']
            logger.debug "VNF HAPROXY: Port ('#{lb['port']}') must be set - skipping..."
            return nil, nil
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
        lb['port'] = nil

        if lb_config.key?('lb-address') && !lb_config['lb-address'].to_s.strip.empty?
            lb['address'] = lb_config['lb-address'].to_s.strip
        else
            return nil, nil
        end

        if lb_config.key?('lb-port') && !lb_config['lb-port'].to_s.strip.empty?
            lb['port'] = lb_config['lb-port'].to_i
        end

        # port v protocol sanity check
        unless lb['port']
            return nil, nil
        end

        #
        # return loadbalancer with hash/index
        #

        lb_hash = gen_lb_hash(lb)

        return lb_hash, lb
    end

    # sanitize a server config and return validated backend server
    def create_backend_server(server_config, lb)
        server = {}
        server['lb'] = lb
        server['server-host'] = nil
        server['server-port'] = nil

        # TODO: sanity checks - eg. port must be integer ('x'.to_i makes zero...)
        if server_config.key?('server-host') && !server_config['server-host'].to_s.strip.empty?
          server['server-host'] = server_config['server-host'].to_s.strip
        else
            logger.debug 'VNF HAPROXY: Missing mandatory backend server host - skipping...'
            return nil, nil
        end

        if server_config.key?('server-port') && !server_config['server-port'].to_s.strip.empty?
            unless server_config['server-port'].to_i >= 0
                logger.debug 'VNF HAPROXY: Backend server port must be an integer - skipping...'
                return nil, nil
            end
            server['server-port'] = server_config['server-port'].to_i
        end

        #
        # return backend server with hash/index
        #

        bs_hash = gen_bs_hash(server)

        return bs_hash, server
    end

    def deploy_loadbalancer(lb, status = :add)
        lb['status'] = status

        unless [:add, :update].include? lb['status']
            logger.error "VNF HAPROXY: This is a bug: wrong internal state for deploy of LoadBalancer (status: #{lb['status']})..."
            return nil
        end

        lb_hash = gen_lb_hash(lb)

        config = read_haproxy_yml
        config['frontend'][lb_hash] = {
            'options' => [
                'mode tcp',
                "bind 0.0.0.0:#{lb['port']}",
                "default_backend #{lb_hash}"
            ]
        }
        config['backend'][lb_hash] = {
            'options' => [
                'mode tcp',
                'balance roundrobin',
                'option tcp-check'
            ],
            'server' => {}
        }

        write_haproxy_yml config
        write_haproxy_cfg config

        rc = reload_haproxy
        if rc == 0
            lb['status'] = :deploy_success
        else
            lb['status'] = :deploy_fail
        end

        return lb
    end

    def deploy_backend_server(server, status = :add)
        server['status'] = status

        unless [:add, :update].include? server['status']
            logger.error "VNF HAPROXY: This is a bug: wrong internal state for deploy of backend server (status: #{server['status']})..."
            return nil
        end

        lb_hash, bs_hash = gen_lb_hash(server['lb']), gen_bs_hash(server)

        config = read_haproxy_yml

        current = config.dig 'backend', lb_hash, 'server', bs_hash
        update = "#{server['server-host']}:#{server['server-port']} check observe layer4 error-limit 50 on-error mark-down"

        if current != update
            config['backend'][lb_hash]['server'][bs_hash] = update

            write_haproxy_yml config
            write_haproxy_cfg config

            rc = reload_haproxy
            if rc == 0
                server['status'] = :deploy_success
            else
                server['status'] = :deploy_fail
            end
        else
            server['status'] = :deploy_success
        end

        return server
    end

    def remove_backend_server(server)
        server['status'] = :delete

        lb_hash, bs_hash = gen_lb_hash(server['lb']), gen_bs_hash(server)

        config = read_haproxy_yml
        config['backend'][lb_hash]['server'].delete(bs_hash)

        write_haproxy_yml config
        write_haproxy_cfg config

        rc = reload_haproxy
        if rc == 0
            server['status'] = :undeploy_success
        else
            server['status'] = :undeploy_fail
        end

        return server
    end

    def refresh_dynamic_backend_servers(lbs, static_backend_servers, dynamic_backend_servers)
        # query OneGate
        output, rc = execute_cmd('onegate service show --json')
        if rc.exitstatus != 0
            return dynamic_backend_servers, -1
        end

        oneflow_service = JSON.parse(output)

        # collect all VM IDs inside this OneGate/OneFlow service
        # TODO: verify that those keys are really there
        found_vms = []
        found_roles = oneflow_service['SERVICE']['roles']
        found_roles.each do |role|
            role['nodes'].each do |node|
                vmid = begin
                    node['vm_info']['VM']['ID']
                rescue StandardError
                    ''
                end

                found_vms.append(vmid.to_i) unless vmid.to_s.strip.empty?
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
                if m = /^ONEGATE_HAPROXY_LB(?<lbindex>[0-9]+)_(?<lbkey>.*)$/.match(context_var)
                    lb_index = m['lbindex'].to_i
                    lb_key = m['lbkey'].to_s.downcase

                    unless onegate_lbs[vmid].key?(lb_index)
                        onegate_lbs[vmid][lb_index] = {}
                    end

                    onegate_lbs[vmid][lb_index][lb_key] = context_value
                end
            end
        end

        # create an empty copy of dynamic backend servers
        active_backend_servers = {} # to track active setup
        dynamic_backend_servers.each do |lb_hash, _|
            active_backend_servers[lb_hash] = {}
        end

        # walk through all found dynamic lb configs and add backend servers in the
        # case that such lb was configured otherwise skip it
        onegate_lbs.each do |vmid, dyn_lbs|
            dyn_lbs.each do |_, dyn_lb|
                lb_config = {}
                lb_config['lb-address'] = (dyn_lb['ip'] if dyn_lb.key?('ip')) || ""
                lb_config['lb-port'] = (dyn_lb['port'] if dyn_lb.key?('port')) || ""

                # if lb is incomplete then hash is incomplete and no such lb will
                # be found
                lb_hash, lb = create_loadbalancer(lb_config)

                unless lb
                    logger.debug "VNF HAPROXY: Dynamic backend servers - LoadBalancer designation is incomplete: #{dyn_lb} - skipping..."
                    next
                end

                # skip lb which is not configured
                unless lbs.key?(lb_hash)
                    logger.debug "VNF HAPROXY: Dynamic backend servers - LoadBalancer does not exist: #{lb_hash} - skipping..."
                    next
                end

                server_config = {}
                server_config['server-host'] = (dyn_lb['server_host'] if dyn_lb.key?('server_host')) || ""
                server_config['server-port'] = (dyn_lb['server_port'] if dyn_lb.key?('server_port')) || ""

                # skip server which does not have at least a host
                if server_config['server-host'].to_s.strip.empty?
                    logger.debug "VNF HAPROXY: Dynamic backend servers - missing host part: #{dyn_lb} - skipping..."
                    next
                end

                #
                # configure dynamic backend servers
                #

                server_hash, backend_server = create_backend_server(server_config, lbs[lb_hash])

                unless backend_server
                    logger.debug "VNF HAPROXY: Dynamic backend servers - config is incomplete: #{dyn_lb} - skipping..."
                    next
                end

                if static_backend_servers[lb_hash].key?(server_hash)
                    # TODO: skip or overwrite...
                    logger.debug "VNF HAPROXY: Dynamic backend servers - conflict with existing static backend server (#{server_hash}) - skipping..."
                    next
                end

                if dynamic_backend_servers[lb_hash].key?(server_hash)
                    # update old one but do not deploy - let refresh do that
                    #backend_server = deploy_backend_server(backend_server, :update)
                    true
                else
                    backend_server = deploy_backend_server(backend_server, :add)

                    unless backend_server && backend_server['status'] == :deploy_success
                        logger.debug "VNF HAPROXY: Dynamic backend servers - failed to setup: #{server_hash} - skipping..."
                        next
                    end
                end

                # save the dynamic backend server to track changes for refresh
                dynamic_backend_servers[lb_hash][server_hash] = backend_server
                active_backend_servers[lb_hash][server_hash] = backend_server

                # TODO: signal that backend server was successfully deployed
            end
        end

        #
        # delete old backend servers configured via OneGate
        #

        dynamic_backend_servers.each do |lb_hash, backend_servers|
            backend_servers.each do |server_hash, backend_server|
                if !active_backend_servers[lb_hash].key?(server_hash)
                    backend_server = remove_backend_server(backend_server)

                    unless backend_server['status'] == :undeploy_success
                        logger.debug "VNF HAPROXY: Dynamic backend servers - failed to properly remove: #{server_hash}"
                    end
                end
            end
        end
        dynamic_backend_servers = active_backend_servers

        return dynamic_backend_servers, 0
    end

    def refresh_active_backend_servers(lbs, active_bs, static_bs, dynamic_bs)
        servers_state = haproxy_show_servers_state

        # record and test all known backend servers
        all_bs = {}
        results = {}
        lbs.each do |lb_hash, lb|
            all_bs[lb_hash] = {}
            results[lb_hash] = {}

            # add all static backend servers
            static_bs.each do |_, backend_servers|
                backend_servers.each do |server_hash, backend_server|
                    all_bs[lb_hash][server_hash] = backend_server
                    if servers_state.dig lb_hash, server_hash, 'srv_op_state'
                        results[lb_hash][server_hash] = servers_state[lb_hash][server_hash]['srv_op_state'].to_i
                    else
                        results[lb_hash][server_hash] = -1
                    end
                end
            end

            # add all dynamic backend servers
            dynamic_bs.each do |_, backend_servers|
                backend_servers.each do |server_hash, backend_server|
                    all_bs[lb_hash][server_hash] = backend_server
                    if servers_state.dig lb_hash, server_hash, 'srv_op_state'
                        results[lb_hash][server_hash] = servers_state[lb_hash][server_hash]['srv_op_state'].to_i
                    else
                        results[lb_hash][server_hash] = -1
                    end
                end
            end
        end

        # now we can gather the results (one by one)
        all_bs.each do |lb_hash, backend_servers|
            backend_servers.each do |server_hash, backend_server|
                test_result = results[lb_hash][server_hash]

                if test_result == 2
                    # backend server is alive

                    if active_bs[lb_hash].key?(server_hash)
                        # update it
                        backend_server = deploy_backend_server(backend_server, :update)
                    else
                        # re-add it
                        backend_server = deploy_backend_server(backend_server, :add)
                    end

                    unless backend_server && backend_server['status'] == :deploy_success
                        logger.debug "VNF HAPROXY: Failed to refresh backend server: #{server_hash} - skipping..."
                        next
                    end
                else
                    # backend server is dead

                    # skip it if already is removed
                    next unless active_bs[lb_hash].key?(server_hash)

                    srv_time_since_last_change = servers_state.dig lb_hash, server_hash, 'srv_time_since_last_change'
                    # prevent one-vnf from removing the server at once
                    if !srv_time_since_last_change.nil? and srv_time_since_last_change.to_i > 600
                        backend_server = remove_backend_server(backend_server)
                        unless backend_server['status'] == :undeploy_success
                            logger.debug "VNF HAPROXY: Failed to remove dead backend server: #{server_hash}"
                        end
                    end
                end
            end
        end
    end

    def get_active_backend_servers(lbs)
        # initialize active backend servers
        active_backend_servers = {}
        lbs.each do |lb_hash, _|
            active_backend_servers[lb_hash] = {}
        end

        bs_tuples = []
        haproxy_show_servers_state.each do |be_name, servers|
            servers.each do |srv_name, state|
                bs_tuples << {
                    'host' => state['srv_addr'],
                    'port' => state['srv_port'].to_i
                }
            end
        end

        # for each tuple find lb and create backend server
        bs_tuples.each do |bs_tuple|
            lbs.each do |lb_hash, lb|
                server_config = {}
                server_config['server-host'] = bs_tuple['host']

                # to be in sync with the usage in the rest of the plugin:
                #   no port ==> nil
                #
                # therefore ignore port 0 (zero)
                if bs_tuple['port'] > 0
                    server_config['server-port'] = bs_tuple['port']
                end

                server_hash, backend_server = create_backend_server(server_config, lb)

                unless backend_server
                    logger.debug "VNF HAPROXY: This is a bug in parsing active backend servers (#{bs_tuple}) - skipping..."
                    break
                end

                active_backend_servers[lb_hash][server_hash] = backend_server
                break
            end
        end

        return active_backend_servers
    end
end
# rubocop:enable Style/Next
# rubocop:enable Style/RedundantReturn
