# -------------------------------------------------------------------------- #
# Copyright 2002-2020, OpenNebula Project, OpenNebula Systems                #
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

# SNAT/DNAT IPv4 VNF plugin
class SDNAT4 < Appliance::Plugin

    CHAINS = {
        'PREROUTING'  => 'one-dnat4',
        'POSTROUTING' => 'one-snat4'
    }

    #
    # plugin interface
    #

    def initialize(app_config, logger)
        super('sdnat4', app_config, logger)
    end

    def configure(app_config)
        super

        # list of NATed interfaces (and by extension their vnets via NIC ids)
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

        # TODO: should not more logic from run to be moved here?
    end

    def run
        # TODO: one enabled interface makes little sense - only if VNF itself
        # is doing SNAT/DNAT on itself...should this be ifaces.count > 1 ?
        unless @ifaces.is_a?(Array) && (@ifaces.count > 0)
            logger.debug 'VNF SNAT/DNAT IPv4: no NATed interfaces provided'
            return 0
        end

        # Query OneGate to discover which networks are attached to the vrouter
        output, rc = execute_cmd('onegate vrouter show --json --extended')
        if rc.exitstatus != 0
            return -1
        end

        vrouter = JSON.parse(output)

        # filter vnets based on the NATed interfaces *AND* store the real NIC
        # name
        nics = vrouter['VROUTER']['TEMPLATE']['NIC']
        allowed_nics = []
        nics.each do |nic|
            if @nic_ids.key?(nic['NIC_ID'])
                nic['REAL_NIC_NAME'] = @nic_ids[nic['NIC_ID']]
                allowed_nics.append(nic)
            end
        end

        # inspect all vnets attached to our NICs in search for external aliases
        network_ids = traverse_networks(allowed_nics)
        mapping = []
        network_ids.each do |network_id|
            output, rc = execute_cmd('onegate vnet show --json --extended'\
                                     " #{network_id}")
            if rc.exitstatus != 0
                return -1
            end

            vnet = JSON.parse(output)

            ars = vnet['VNET']['AR_POOL']['AR']

            ars.each do |ar|
                leases = []
                if ar['LEASES'].key?('LEASE')
                    leases = ar['LEASES']['LEASE']
                end

                leases.each do |lease|
                    new_map = {}
                    if lease.key?('EXTERNAL') && lease['EXTERNAL']
                        new_map['EXTERNAL_ALIAS_VM'] = lease['VM']
                        new_map['EXTERNAL_ALIAS_IP'] = lease['IP']
                        new_map['EXTERNAL_ALIAS_PARENT_NIC'] = lease['PARENT']
                        new_map['EXTERNAL_ALIAS_PARENT_NETWORK'] = \
                            lease['PARENT_NETWORK_ID']
                        mapping.append(new_map)
                    end
                end
            end
        end

        # the second part of the pair + filtering (its network_id must match
        # vrouter's allowed interface)
        nic_map = []
        mapping.each do |alias_map|
            network_id = alias_map['EXTERNAL_ALIAS_PARENT_NETWORK']

            # filter interface
            unless (nic = contains_network?(allowed_nics, network_id))
                next
            end

            new_map = alias_map.dup
            new_map['REAL_NIC_NAME'] = nic['REAL_NIC_NAME']
            new_map['NETWORK_ID'] = nic['NETWORK_ID']
            new_map['NIC_ID'] = nic['NIC_ID']

            output, rc = execute_cmd('onegate vnet show --json --extended'\
                                     " #{network_id}")
            if rc.exitstatus != 0
                return -1
            end

            vnet = JSON.parse(output)

            ars = vnet['VNET']['AR_POOL']['AR']

            ars.each do |ar|
                leases = []
                if ar['LEASES'].key?('LEASE')
                    leases = ar['LEASES']['LEASE']
                end

                leases.each do |lease|
                    if (lease['NIC_NAME'] == \
                       alias_map['EXTERNAL_ALIAS_PARENT_NIC']) && \
                       (lease['VM'] == alias_map['EXTERNAL_ALIAS_VM'])
                        new_map['EXTERNAL_ALIAS_DEST_IP'] = lease['IP']
                        nic_map.append(new_map)
                    end
                end
            end
        end

        # refresh iptables rules

        # Get initial iptables rules required as if there no NIC_ALIAS/NIC
        # mappings
        rules_pre  = iptables_tnat_apply_init
        # Modify initial iptables rules with NIC_ALIAS/NIC mappings
        rules_post = iptables_tnat_apply_merge(rules_pre, nic_map)

        # Apply the inferred iptables rules
        rules_post.each_line do |rule|
            _, rc = execute_cmd("iptables -tnat #{rule}")
            if rc.exitstatus != 0
                return -1
            end
        end

        # add/remove aliased IPs from the vrouter

        current_ips = assigned_loopback_ips

        # filter through current ips (mark stale and prepare new)
        new_ips = []
        nic_map.each do |alias_map|
            if current_ips.include?(alias_map['EXTERNAL_ALIAS_IP'])
                current_ips.delete(alias_map['EXTERNAL_ALIAS_IP'])
            else
                new_ips.append(alias_map['EXTERNAL_ALIAS_IP'])
            end
        end

        # delete extraneous IPs
        current_ips.each do |ip|
            _, rc = execute_cmd("ip address del #{ip}/32 dev lo")
            if rc.exitstatus != 0
                return -1
            end
        end

        # add new IPs
        new_ips.each do |ip|
            _, rc = execute_cmd("ip address add #{ip}/32 dev lo")
            if rc.exitstatus != 0
                return -1
            end
        end
    end

    def cleanup
        # remove all our iptables rules
        CHAINS.each do |nat_chain, custom_chain|
            _, rc = execute_cmd("iptables -tnat -S #{custom_chain}", false)

            if rc.exitstatus == 0
                # chain exists

                # flush rules in the chain
                execute_cmd("iptables -tnat -F #{custom_chain}")

                # remove reference from the parent chain
                execute_cmd("iptables -tnat -D #{nat_chain}"\
                            " -j #{custom_chain}")

                # delete the chain
                execute_cmd("iptables -tnat -X #{custom_chain}")
            end
        end

        # remove all our ips from the loopback interface
        current_ips = assigned_loopback_ips
        current_ips.each do |ip|
            execute_cmd("ip address del #{ip}/32 dev lo")
        end
    end

    private

    #
    # other internal methods
    #

    def execute_cmd(cmd_str, logme = true)
        stdout, stderr, rc = Open3.capture3(cmd_str)
        if (rc.exitstatus != 0) && logme
            logger.error "VNF SNAT/DNAT IPv4 ERROR: #{stdout + stderr}"
        end

        return stdout, rc
    end

    def assigned_loopback_ips
        current_ips = []
        addrs = Socket.getifaddrs
        addrs.each do |addr|
            if addr && (addr.name == 'lo') && addr.addr.ipv4?
                ip = addr.addr.ip_address
                if ip !~ /^127/
                    current_ips.append(ip)
                end
            end
        end

        return current_ips
    end

    # get iptables rules to apply for NAT table if no NIC/NIC_ALIAS detected
    def iptables_tnat_apply_init
        rules = ''

        CHAINS.each do |nat_chain, custom_chain|
            output, rc = execute_cmd("iptables -tnat -S #{custom_chain}", false)

            if rc.exitstatus != 0
                # The chain does not exist, add rules to create it
                rules += "-N #{custom_chain}\n"
            else
                output.each_line do |r|
                    next if r.include?("-N #{custom_chain}")

                    # The chain does exist, add all rules belonging to the
                    # chain and mark them to be deleted initially
                    rules += r.gsub(/-A (.*)/, '-D \1')
                end
            end

            # ensure that our chain is entered first
            output, = execute_cmd("iptables -tnat -S #{nat_chain} 1")
            if output.strip != "-A #{nat_chain} -j #{custom_chain}".strip
                rules += "-I #{nat_chain} 1 -j #{custom_chain}\n"
            end

            # TODO: wipe out redundant rules
        end

        rules
    end

    # merge intial iptables rules to apply for NAT with the ones needed by
    # NIC/NIC_ALIAS mapping
    def iptables_tnat_apply_merge(rules, nics_maps)
        nics_maps.each do |nat|
            # DNAT rule
            # TODO: should we create some list of allowed interfaces?
            # jdnat = "#{CHAINS['PREROUTING']} -i #{nat['REAL_NIC_NAME']}"\
            jdnat = "#{CHAINS['PREROUTING']}"\
                    " -d #{nat['EXTERNAL_ALIAS_IP']}/32"\
                    ' -j DNAT'\
                    " --to-destination #{nat['EXTERNAL_ALIAS_DEST_IP']}"
            # Try to delete -D DNAT rule which means previously NIC_ALIAS still
            # attached
            if !rules.gsub!(/-D #{jdnat}\n/, '')
                # Add -A rule if not DNAT rule found which means new NIC_ALIAS
                # has been attached
                rules += "-A #{jdnat}\n"
            end

            # SNAT rule
            # TODO: should we create some list of allowed interfaces?
            # jsnat = "#{CHAINS['POSTROUTING']} -o #{nat['REAL_NIC_NAME']}"\
            jsnat = "#{CHAINS['POSTROUTING']}"\
                    " -s #{nat['EXTERNAL_ALIAS_DEST_IP']}/32"\
                    ' -j SNAT'\
                    " --to-source #{nat['EXTERNAL_ALIAS_IP']}"
            # Try to delete -D SNAT rule which means previously NIC_ALIAS still
            # attached
            if !rules.gsub!(/-D #{jsnat}\n/, '')
                # Add -A rule if not SNAT rule found which means new NIC_ALIAS
                # has been attached
                rules += "-A #{jsnat}\n"
            end
        end

        rules
    end

    def contains_network?(nics, network_id)
        nics.each do |nic|
            if nic['NETWORK_ID'] == network_id
                return nic
            end
        end

        return false
    end

    def recursive_network_traversing(initial_network_ids, searched_id)
        output, rc = execute_cmd('onegate vnet show'\
                                 " --json --extended #{searched_id}")
        if rc.exitstatus != 0
            # TODO: maybe exception and handle by caller?
            return initial_network_ids
        end

        vnet = JSON.parse(output)
        network_ids = initial_network_ids.dup
        new_found_network_ids = []

        # check if the current vnet has a parent
        if (parent_network_id = Integer(vnet['VNET']['PARENT_NETWORK_ID']) \
           rescue false) && !network_ids.include?(parent_network_id)
            network_ids.append(parent_network_id)
            new_found_network_ids.append(parent_network_id)
        end

        # check VNETs under LEASE section
        ars = vnet['VNET']['AR_POOL']['AR']

        ars.each do |ar|
            leases = []
            if ar['LEASES'].key?('LEASE')
                leases = ar['LEASES']['LEASE']
            end

            leases.each do |lease|
                if lease.key?('VNET') && !network_ids.include?(lease['VNET'])
                    network_ids.append(lease['VNET'])
                    new_found_network_ids.append(lease['VNET'])
                end
            end
        end

        # we recurse the new found ids and this also serves as a termination
        # condition when there is no new found network id
        new_found_network_ids.each do |network_id|
            network_ids = recursive_network_traversing(network_ids, network_id)
        end

        return network_ids
    end

    def traverse_networks(nics)
        network_ids = []

        nics.each do |nic|
            # TODO: error checking
            network_ids.append(nic['NETWORK_ID'])
        end

        new_found_network_ids = network_ids.dup
        new_found_network_ids.each do |network_id|
            network_ids = recursive_network_traversing(network_ids, network_id)
        end

        return network_ids
    end

end
# rubocop:enable Style/Next
# rubocop:enable Style/RedundantReturn
