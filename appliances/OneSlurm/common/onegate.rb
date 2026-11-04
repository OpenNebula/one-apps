# frozen_string_literal: true

require 'json'
require 'shellwords'

# OneGate service / role discovery shared by both Slurm roles.

def with_retries(attempts: 10, delay: 15, msg: 'Retrying operation...')
    attempts.times do |i|
        begin
            return yield
        rescue StandardError => e
            if i + 1 < attempts
                msg(:warn, "#{msg} (#{i + 1}/#{attempts}). Error: #{e.message}. Retrying in #{delay}s.")
                sleep delay
            else
                msg(:error, "Operation failed after #{attempts} attempts.")
                raise e
            end
        end
    end
end

def onegate_service_show
    JSON.parse bash 'onegate --json service show'
end

def onegate_vm_show(vmid = '')
    JSON.parse bash "onegate --json vm show #{vmid}"
end

def onegate_vm_update(data, vmid = '')
    args = ['onegate', 'vm', 'update']
    args << vmid.to_s unless vmid.to_s.empty?
    # OneGate's attribute escaping needs explicit quotes for empty values at EOF.
    payload = Array(data).map { |item| item.to_s.sub(/\A([A-Za-z_][A-Za-z0-9_]*)=\z/, '\1=""') }
    args.concat ['--data', payload.join('\n')]
    bash args.shelljoin
end

def vm_nic_ipv4(vm)
    nics = vm.dig('VM', 'TEMPLATE', 'NIC')
    nics = [nics] if nics.is_a?(Hash)
    Array(nics).each do |nic|
        ip = nic['IP'].to_s
        return ip unless ip.empty?
    end
    ''
end

def role_vms_show(name)
    onegate_service = onegate_service_show

    if (roles = onegate_service.dig 'SERVICE', 'roles').nil? || roles.empty?
        msg :error, 'No roles found in OneGate'
        exit 1
    end

    if (role = roles.find { |item| item['name'] == name }).nil?
        msg :error, "No '#{name}' role found in OneGate"
        exit 1
    end

    if (nodes = role.dig 'nodes').nil? || nodes.empty?
        msg :error, "No '#{name}' nodes found in OneGate"
        exit 1
    end

    vmids = nodes.map { |node| node.dig 'vm_info', 'VM', 'ID' }

    vmids.each_with_object [] do |vmid, acc|
        acc << onegate_vm_show(vmid)
    end
end

def role_vm_show(name) # Shows the first one..
    onegate_service = onegate_service_show

    if (roles = onegate_service.dig 'SERVICE', 'roles').nil? || roles.empty?
        raise 'No roles found in OneGate'
    end

    if (role = roles.find { |item| item['name'] == name }).nil?
        raise "No '#{name}' role found in OneGate"
    end

    if (nodes = role.dig 'nodes').nil? || nodes.empty?
        raise "No '#{name}' nodes found in OneGate"
    end

    vmid = nodes.first.dig 'vm_info', 'VM', 'ID'
    raise "Missing '#{name}' VM membership in OneGate" if vmid.to_s.empty?

    onegate_vm_show vmid
end
