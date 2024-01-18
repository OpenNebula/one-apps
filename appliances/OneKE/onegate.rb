# frozen_string_literal: true

require 'json'

require_relative 'config.rb'
require_relative 'helpers.rb'

def onegate_service_show
    JSON.parse bash 'onegate --json service show'
end

def onegate_vm_show(vmid = '')
    JSON.parse bash "onegate --json vm show #{vmid}"
end

def onegate_vm_update(data, vmid = '')
    bash "onegate vm update #{vmid} --data \"#{data.join('\n')}\""
end

def ip_addr_show(ifname = '')
    JSON.parse bash "ip --json addr show #{ifname}"
end

def all_vms_show
    onegate_service = onegate_service_show

    if (roles = onegate_service.dig 'SERVICE', 'roles').empty?
        msg :error, 'No roles found in Onegate'
        exit 1
    end

    vmids = roles.each_with_object [] do |role, acc|
        next if (nodes = role.dig 'nodes').nil?

        nodes.each do |node|
            acc << node.dig('vm_info', 'VM', 'ID')
        end
    end

    vmids.each_with_object [] do |vmid, acc|
        acc << onegate_vm_show(vmid)
    end
end

def role_vms_show(name)
    onegate_service = onegate_service_show

    if (roles = onegate_service.dig 'SERVICE', 'roles').empty?
        msg :error, 'No roles found in Onegate'
        exit 1
    end

    if (role = roles.find { |item| item['name'] == name }).nil?
        msg :error, "No '#{name}' role found in Onegate"
        exit 1
    end

    if (nodes = role.dig 'nodes').empty?
        msg :error, "No '#{name}' nodes found in Onegate"
        exit 1
    end

    vmids = nodes.map { |node| node.dig 'vm_info', 'VM', 'ID' }

    vmids.each_with_object [] do |vmid, acc|
        acc << onegate_vm_show(vmid)
    end
end

def master_vms_show
    role_vms_show 'master'
end

def role_vm_show(name) # Shows the first one..
    onegate_service = onegate_service_show

    if (roles = onegate_service.dig 'SERVICE', 'roles').empty?
        msg :error, 'No roles found in Onegate'
        exit 1
    end

    if (role = roles.find { |item| item['name'] == name }).nil?
        msg :error, "No '#{name}' role found in Onegate"
        exit 1
    end

    if (nodes = role.dig 'nodes').empty?
        msg :error, 'No nodes found in Onegate'
        exit 1
    end

    vmid = nodes.first.dig 'vm_info', 'VM', 'ID'

    onegate_vm_show vmid
end

def vnf_vm_show
    role_vm_show 'vnf'
end

def master_vm_show
    role_vm_show 'master'
end

def external_ipv4s
    onegate_vm = onegate_vm_show

    if (nics = onegate_vm.dig 'VM', 'TEMPLATE', 'NIC').empty?
        msg :error, 'No nics found in Onegate'
        exit 1
    end

    if (ip_addr = ip_addr_show).empty?
        msg :error, 'No local addresses found'
        exit 1
    end

    ipv4s = nics.each_with_object [] do |nic, acc|
        addr = ip_addr.find do |item|
            next unless item['address'].downcase == nic['MAC'].downcase

            item['addr_info'].find do |info|
                info['family'] == 'inet' && info['local'] == nic['IP']
            end
        end
        acc << nic['IP'] unless addr.nil?
    end

    if ipv4s.empty?
        msg :error, 'No IPv4 addresses found'
        exit 1
    end

    ipv4s
end
