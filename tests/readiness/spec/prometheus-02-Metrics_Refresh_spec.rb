require 'init'

require 'net/http'
require 'uri'

def opennebula_vm_state(vm_id, host = '127.0.0.1', port = 9925)
    uri = URI "http://#{host}:#{port}/metrics"
    rsp = Net::HTTP.get_response uri
    metrics = rsp.body.lines.reject { |line| line.start_with?("#") }
    metrics.find { |line| line.start_with? %[opennebula_vm_state{one_vm_id="#{vm_id}"}] }
rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ETIMEDOUT, Net::OpenTimeout
    nil
end

RSpec.describe 'Prometheus metrics refresh (regression test)' do
    before(:all) do
        @template = RSpec.configuration.defaults[:template]
    end

    vm_id = nil

    it 'Metrics present after creating a VM' do
        vm_id = cli_create "onetemplate instantiate #{@template}"

        wait_loop success: true, break: nil, timeout: 120, resource_ref: nil do
            !opennebula_vm_state(vm_id).nil?
        end
    end

    it 'Metrics absent after terminating a VM' do
        cli_action "onevm recover --delete #{vm_id}"

        wait_loop success: true, break: nil, timeout: 120, resource_ref: nil do
            opennebula_vm_state(vm_id).nil?
        end
    end
end
