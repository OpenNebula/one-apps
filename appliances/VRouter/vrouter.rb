# frozen_string_literal: true

require 'ipaddr'
require 'json'
require 'net/https'
require 'singleton'
require 'uri'

begin
    require '/etc/one-appliance/lib/helpers.rb'
rescue LoadError
    require_relative '../lib/helpers.rb'
end

class OneGate
    include Singleton

    def initialize
        @uri   = URI.parse(ENV['ONEGATE_ENDPOINT'])
        @vmid  = ENV['VMID']
        @token = ENV['TOKENTXT']
        @req_content_type = 'application/json'

        @http             = Net::HTTP.new(@uri.host, @uri.port)
        @http.use_ssl     = @uri.scheme == 'https'
        @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    def vrouter_show(keep_alive: false)
        path     = '/vrouter'
        req      = Net::HTTP::Get.new(path)
        req.body = URI.encode_www_form('extended' => true)
        do_request req, keep_alive
    end

    def vnet_show(vnid, keep_alive: false)
        path     = "/vnet/#{vnid}"
        req      = Net::HTTP::Get.new(path)
        req.body = URI.encode_www_form('extended' => true)
        do_request req, keep_alive
    end

    def service_show(keep_alive: false)
        path = '/service'
        req  = Net::HTTP::Get.new(path)
        do_request req, keep_alive
    end

    def vm_show(vmid = nil, keep_alive: false)
        path = vmid.nil? ? '/vm' : "/vms/#{vmid}"
        req  = Net::HTTP::Get.new(path)
        do_request req, keep_alive
    end

    def vm_update(data, vmid = nil, erase: false, keep_alive: false)
        path     = vmid.nil? ? '/vm' : "/vms/#{vmid}"
        req      = Net::HTTP::Put.new(path)
        req.body = erase ? URI.encode_www_form('type' => 2, 'data' => data) : data
        do_request req, keep_alive, expect_json: false
    end

    private

    def do_request(req, keep_alive, expect_json: true)
        @http.start unless @http.started?

        req['X-ONEGATE-VMID']  = @vmid
        req['X-ONEGATE-TOKEN'] = @token
        req['Content-Type'] = @req_content_type

        expect_json ? JSON.parse(@http.request(req).body) : @http.request(req).body
    rescue StandardError => e
        msg :error, e.full_message
        nil
    ensure
        @http.finish unless keep_alive
    end
end

def ip_link_set_up(nic)
    stdout = bash "ip link set '#{nic}' up", terminate: false
end

def ip_link_show(nic)
    stdout = bash "ip --json link show '#{nic}'", terminate: false
    JSON.parse(stdout).first
end

def ip_addr_show(nic)
    stdout = bash "ip --json addr show '#{nic}'", terminate: false
    JSON.parse(stdout).first
end

def detect_nics
    ENV.keys.each_with_object([]) do |name, acc|
        case name
        when /^ETH(\d+)_IP$/
            acc << "eth#{$1}"
        end
    end.uniq
end

def detect_mgmt_nics
    ENV.keys.each_with_object([]) do |name, acc|
        case name
        when /^ETH(\d+)_VROUTER_MANAGEMENT$/
            acc << "eth#{$1}" if env(name, 'NO')
        end
    end
end

def infer_pfxlen(eth_index, ip)
    pfxlen = ip.then do |ip|
        unless (pfxlen = ip.split(%[/])[1]).nil?
            next pfxlen.to_i
        end

        unless (mask = env("ETH#{eth_index}_MASK", nil)).nil?
            next IPAddr.new("#{ip}/#{mask}").prefix.to_i
        end

        unless (network = env("ETH#{eth_index}_NETWORK", nil)).nil?
            next 32 - 8 * network.split(%[.]).map(&:to_i).reverse.take_while(&:zero?).count
        end

        case (ip = IPAddr.new(ip)).family
        when Socket::AF_INET
            next  8 if ip.to_i & 0xff00_0000 == 0x0a00_0000 # A 10.x.y.z/8
            next 16 if ip.to_i & 0xfff0_0000 == 0xac10_0000 # B 172.16.x.y/16
            next 24 if ip.to_i & 0xffff_0000 == 0xc0a8_0000 # C 192.168.x.y/24
        end

        next 24 # guess/fallback
    end
    return pfxlen.zero? ? 32 : pfxlen
end

def append_pfxlen(eth_index, ip)
    return "#{ip.split(%[/])[0]}/#{infer_pfxlen(eth_index, ip)}"
end

def detect_addrs
    ENV.each_with_object({}) do |(name, v), acc|
        next if v.empty?
        case name
        when /^ETH(\d+)_IP$/
            acc["eth#{$1}"] ||= {}
            acc["eth#{$1}"]["ETH#{$1}_IP0"] = append_pfxlen($1, v)
        end
    end
end

def detect_vips
    ENV.each_with_object({}) do |(name, v), acc|
        next if v.empty?
        case name
        when /^ETH(\d+)_VROUTER_IP$/
            acc["eth#{$1}"] ||= {}
            acc["eth#{$1}"]["ETH#{$1}_VIP0"] ||= append_pfxlen($1, v)
        when /^ONEAPP_VROUTER_ETH(\d+)_VIP(\d+)$/
            acc["eth#{$1}"] ||= {}
            acc["eth#{$1}"]["ETH#{$1}_VIP#{$2}"] = append_pfxlen($1, v)
        end
    end
end

def detect_endpoints(addrs = detect_addrs, vips = detect_vips)
    addrs = addrs.to_h do |nic, h|
        [nic, h.to_h { |k, v| [k.sub('_IP', '_EP'), v] }]
    end
    vips = vips.to_h do |nic, h|
        [nic, h.to_h { |k, v| [k.sub('_VIP', '_EP'), v] }]
    end
    hashmap.combine addrs, vips
end

def parse_interfaces(interfaces, pattern: /^[!]?eth\d+$/)
    return {} if interfaces.nil?

    vips, addrs = nil, nil

    excluded, included = [], []

    interfaces.split(%r{[ ,;]}).map(&:strip).compact.each do |interface|
        if interface.start_with?(%[!])
            excluded << interface.delete_prefix(%[!]) if interface.size > 1
        else
            included << interface if interface.size > 0
        end
    end

    included = detect_nics if included.empty?

    # Sort NICs to make the resulting data structure predictable..
    sortkeys.as_version! included, pattern: /^eth(\d+)$/

    excluded, included = [excluded, included].map do |collection|
        collection.each_with_object({}) do |interface, acc|
            parts = { name: nil, addr: nil, port: nil }

            interface.split(%r{(?=#{pattern.source}|[/@])}).each do |p|
                case p
                when pattern then parts[:name] = p
                when %r{^/}  then parts[:addr] = p.delete_prefix(%[/]) if p.size > 1
                when %r{^@}  then parts[:port] = p.delete_prefix(%[@]) if p.size > 1
                else              parts[:addr] = p
                end
            end

            # Check if the NIC has been defined explicitly.
            unless (nic = parts[:name]).nil?
                acc[nic] ||= []
                acc[nic] << parts
                next
            end

            next if parts[:addr].nil?

            # Try to find any IPs in context vars (and infer NIC names).
            addrs ||= addrs_to_nics
            unless (nics = addrs[parts[:addr].downcase]).nil?
                nics.each do |nic|
                    parts[:name] = nic
                    acc[nic] ||= []
                    acc[nic] << parts.dup
                end
                next
            end

            # Try to find any VIPs in context vars (and infer NIC names).
            vips ||= detect_vips.each_with_object({}) do |(nic, h), acc|
                h.each do |_, vip|
                    vip = vip.split(%[/])[0] # remove the CIDR "prefixlen" if present
                    acc[vip] ||= []
                    acc[vip] << nic
                end
            end

            unless (nics = vips[parts[:addr].downcase]).nil?
                nics.each do |nic|
                    parts[:name] = nic
                    acc[nic] ||= []
                    acc[nic] << parts.dup
                end
                next
            end
        end
    end

    included.select { |name, _| !name.nil? && !excluded.include?(name) }
end

def render_interface(parts, name: false, addr: true, port: true)
    tmp = []

    tmp << parts[:name] if name || parts[:addr].nil?

    if addr && !parts[:addr].nil?
        tmp << %[/] if name
        tmp << parts[:addr]
    end

    if port && !parts[:port].nil?
        tmp << %[@]
        tmp << parts[:port]
    end

    tmp.join
end

def nics_to_addrs(nics = detect_nics)
    ENV.each_with_object({}) do |(name, v), acc|
        next if v.empty?
        case name
        when /^ETH(\d+)_IP$/
            next unless nics.include?(nic = "eth#{$1}")
            acc[nic] ||= []
            acc[nic] << v
        end
    end
end

def nics_to_subnets(nics = detect_nics)
    ENV.each_with_object({}) do |(name, v), acc|
        next if v.empty?
        case name
        when /^ETH(\d+)_IP$/
            next unless nics.include?(nic = "eth#{$1}")
            ip       = v.split(%[/])[0]
            subnet   = IPAddr.new("#{ip}/#{infer_pfxlen($1.to_i, v)}")

            acc[nic] ||= []
            acc[nic] << "#{subnet}/#{subnet.prefix}"
        end
    end
end

def addrs_to_nics(nics = detect_nics)
    ENV.each_with_object({}) do |(name, v), acc|
        next if v.empty?
        case name
        when /^ETH(\d+)_IP$/
            next unless nics.include?(nic = "eth#{$1}")
            acc[v] ||= []
            acc[v] << nic
        end
    end
end

def addrs_to_subnets(nics = detect_nics)
    ENV.each_with_object({}) do |(name, v), acc|
        next if v.empty?
        case name
        when /^ETH(\d+)_IP$/
            next unless nics.include?("eth#{$1}")
            ip       = v.split(%[/])[0]
            subnet   = IPAddr.new("#{ip}/#{infer_pfxlen($1.to_i, v)}")
            key      = "#{ip}/#{subnet.prefix}"
            acc[key] = "#{subnet}/#{subnet.prefix}"
        end
    end
end

def vips_to_subnets(nics = detect_nics, vips = detect_vips)
    vips.each_with_object({}) do |(nic, h), acc|
        next unless nics.include?(nic)
        h.each do |_, vip|
            eth_index = nic.delete_prefix('eth')
            key       = append_pfxlen(eth_index, vip)
            subnet    = IPAddr.new(key)
            acc[key]  = %[#{subnet}/#{subnet.prefix}]
        end
    end
end

def subnets_to_ranges(subnets = addrs_to_subnets.values)
    subnets.each_with_object({}) do |subnet, acc|
        addr  = IPAddr.new(subnet)
        range = addr.to_range

        first, last = range.first.to_i, range.last.to_i
        next unless last - first > 3

        acc[subnet] = [
            # Skip the network and the first usable address.
            IPAddr.new(first + 2, addr.family).to_s,
            # Skip the last address (broadcast).
            IPAddr.new(last - 1, addr.family).to_s
        ].join('-')
    end
end

def get_vrouter_vnets
    return [] if (document = OneGate.instance.vrouter_show).nil?
    return [] if (nics = document.dig('VROUTER', 'TEMPLATE', 'NIC')).nil?

    initial_network_ids = nics.map { |nic| nic['NETWORK_ID'] }
                              .compact
                              .uniq

    return [] if initial_network_ids.empty?

    def recurse(network_ids)
        network_ids.each_with_object([]) do |network_id, vnets|
            next if (vnet = OneGate.instance.vnet_show(network_id)).nil?

            vnets << vnet

            parent_network_id = vnet['PARENT_NETWORK_ID']

            vnets << recurse([parent_network_id]) unless parent_network_id.nil?

            next if (ars = vnet.dig('VNET', 'AR_POOL', 'AR')).nil?

            ars.each do |ar|
                next if (leases = ar.dig('LEASES', 'LEASE')).nil?

                parent_network_ids = leases.map { |lease| lease['VNET'] }
                                           .compact
                                           .uniq

                next if parent_network_ids.empty?

                vnets << recurse(parent_network_ids)
            end
        end.flatten.uniq
    end

    recurse(initial_network_ids)
end

def get_service_vms # OneFlow
    return [] if (document = OneGate.instance.service_show).nil?
    return [] if (roles = document.dig('SERVICE', 'roles')).nil?

    roles.each_with_object([]) do |role, acc|
        next if (nodes = role.dig('nodes')).nil?

        nodes.each do |node|
            next if (vm_id = node.dig('vm_info', 'VM', 'ID')).nil?

            acc << vm_id
        end
    end.uniq.each_with_object([]) do |vm_id, acc|
        next if (vm = OneGate.instance.vm_show(vm_id)).nil?

        acc << vm
    end
end

def backends
    def parse_static(names, prefix, allow_nil_ports: false)
        names.each_with_object({}) do |name, acc|
            case name
            when /^#{prefix}(\d+)_(IP|PORT|PROTOCOL|METHOD|SCHEDULER)$/
                lb_idx, opt = $1.to_i, $2
                key = lb_idx
                acc[:options] ||= {}
                acc[:options][key] ||= {}
                acc[:options][key][opt.downcase.to_sym] = env(name, '')
            when /^#{prefix}(\d+)_SERVER(\d+)_(HOST|PORT|WEIGHT|ULIMIT|LLIMIT)$/
                lb_idx, vm_idx, opt = $1.to_i, $2.to_i, $3
                key = [lb_idx, vm_idx]
                acc[:by_indices] ||= {}
                acc[:by_indices][key] ||= {}
                acc[:by_indices][key][opt.downcase.to_sym] = env(name, '')
            end
        end.then do |doc|
            doc[:by_indices]&.each do |(lb_idx, _), v|
                key1 = [lb_idx, doc[:options][lb_idx][:ip], doc[:options][lb_idx][:port]]

                next if key1[0].nil?
                next if key1[1].nil?
                next if key1[2].nil? && !allow_nil_ports

                key2 = [v[:host], v[:port]]

                next if key2[0].nil?
                next if key2[1].nil? && !allow_nil_ports

                doc[:by_endpoint] ||= {}
                doc[:by_endpoint][key1] ||= {}
                doc[:by_endpoint][key1][key2] = v
            end
            doc.delete(:by_indices)
            doc
        end
    end

    def parse_dynamic(objects, prefix, id: nil)
        objects.each_with_object({}) do |(name, v), acc|
            case name
            when /^#{prefix}(\d+)_(ID|IP|PORT)$/
                lb_idx, opt = $1.to_i, $2
                key = lb_idx
                acc[:options] ||= {}
                acc[:options][key] ||= {}
                acc[:options][key][opt.downcase.to_sym] = v
            when /^#{prefix}(\d+)_SERVER_(HOST|PORT|WEIGHT|ULIMIT|LLIMIT)$/
                lb_idx, opt = $1.to_i, $2
                key = lb_idx
                acc[:by_index] ||= {}
                acc[:by_index][key] ||= {}
                acc[:by_index][key][opt.downcase.to_sym] = v
            end
        end.then do |doc|
            if !id.to_s.empty?
                included = doc[:options].each_with_object(Set.new) do |(lb_idx, v), acc|
                    acc << lb_idx if v[:id].to_s.empty? || v[:id] == id
                end
                doc[:options] = doc[:options].slice *included
                doc[:by_index] = doc[:by_index].slice *included
            end
            doc
        end.then do |doc|
            doc[:by_index]&.each do |lb_idx, v|
                key1 = [lb_idx, doc[:options][lb_idx][:ip], doc[:options][lb_idx][:port]]
                next unless key1.all?

                key2 = [v[:host], v[:port]]
                next unless key2.all?

                doc[:by_endpoint] ||= {}
                doc[:by_endpoint][key1] ||= {}
                doc[:by_endpoint][key1][key2] = v
            end
            doc.delete(:by_index)
            doc
        end
    end

    def from_env(prefix: 'ONEAPP_VNF_LB', allow_nil_ports: false) # also 'ONEAPP_HAPROXY_VNF_LB'
        # NOTE: When enabled, "allow_nil_ports" can be used in LVS to load-balance *all* ports to
        #       *all* backends (real servers). This cannot be the case for HAProxy however..
        parse_static(ENV.keys, prefix, allow_nil_ports: allow_nil_ports)
    end

    def from_vnets(vnets, prefix: 'ONEGATE_LB', id: nil) # also 'ONEGATE_HAPROXY_LB'
        vnets.each_with_object({}) do |vnet, acc|
            next if (ars = vnet.dig('VNET', 'AR_POOL', 'AR')).nil?

            ars.each do |ar|
                next if (leases = ar.dig('LEASES', 'LEASE')).nil?

                leases.each do |lease|
                    next if lease['BACKEND'] != 'YES'

                    hashmap.combine! acc, parse_dynamic(lease, prefix, id: id)
                end
            end
        end
    end

    def from_vms(vms, prefix: 'ONEGATE_LB', id: nil) # also 'ONEGATE_HAPROXY_LB'
        vms.each_with_object({}) do |vm, acc|
            next if (user_template = vm.dig('VM', 'USER_TEMPLATE')).nil?

            hashmap.combine! acc, parse_dynamic(user_template, prefix, id: id)
        end
    end

    def combine(static, dynamic)
        keys = static[:options].to_h.map { |lb_idx, opt| [lb_idx, opt[:ip], opt[:port]] }

        { by_endpoint: hashmap.combine(static[:by_endpoint].to_h, dynamic[:by_endpoint].to_h.slice(*keys)),
          options:     static[:options].to_h }
    end

    def interpolate(ip, ave)
        case ip
        when /^<(.+)>$/
            ave[$1] || ip
        else
            ip
        end.split(%[/])[0]
    end

    def resolve(b, addrs = detect_addrs, vips = detect_vips, endpoints = detect_endpoints)
        ave = [addrs, vips, endpoints].map(&:values).flatten.each_with_object({}) do |h, acc|
            hashmap.combine! acc, h
        end

        {
            by_endpoint: b[:by_endpoint].to_h.each_with_object({}) do |((lb_idx, ip, port), v), acc|
                k = [lb_idx, interpolate(ip, ave), port]
                hashmap.combine! acc, { k => v }
            end,

            options: b[:options].to_h do |lb_idx, v|
                v[:ip] = interpolate(v[:ip], ave)
                [ lb_idx, v ]
            end
        }
    end
end
