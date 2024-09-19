require 'init'

require 'json'
require 'net/http'
require 'uri'

def detect_ha(zone_id = 0)
    onezone_show = JSON.parse %x(onezone show #{zone_id} --json)

    servers = onezone_show&.dig 'ZONE', 'SERVER_POOL', 'SERVER'

    return servers.nil? ? 1 : servers.size
end

def prometheus_ready?(host = '127.0.0.1', port = 9090)
    uri = URI "http://#{host}:#{port}/-/ready"
    rsp = Net::HTTP.get_response uri
    rsp.is_a? Net::HTTPSuccess
rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ETIMEDOUT, Net::OpenTimeout
    false
end

def prometheus_healthy?(host = '127.0.0.1', port = 9090)
    uri = URI "http://#{host}:#{port}/-/healthy"
    rsp = Net::HTTP.get_response uri
    rsp.is_a? Net::HTTPSuccess
rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ETIMEDOUT, Net::OpenTimeout
    false
end

def prometheus_targets_up?(host = '127.0.0.1', port = 9090,
                           frontend_count: 1,
                           exporter_count: 2)
    uri = URI "http://#{host}:#{port}/api/v1/targets?state=active"
    rsp = Net::HTTP.get_response uri

    return false unless rsp.is_a?(Net::HTTPSuccess)

    expected = {
        'libvirt_exporter'    => { up: exporter_count },
        'node_exporter'       => { up: frontend_count + exporter_count },
        'opennebula_exporter' => { up: 1 },
        'prometheus'          => { up: 1 }
    }
    gathered = {
        'libvirt_exporter'    => { up: 0 },
        'node_exporter'       => { up: 0 },
        'opennebula_exporter' => { up: 0 },
        'prometheus'          => { up: 0 }
    }

    JSON.parse(rsp.body)&.dig('data', 'activeTargets')&.each do |item|
        gathered[item['labels']['job']][:up] += item['health'] == 'up' ? 1 : 0
    end

    gathered == expected
rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ETIMEDOUT, Net::OpenTimeout
    false
end

def alertmanager_ready?(host = '127.0.0.1', port = 9093)
    uri = URI "http://#{host}:#{port}/-/ready"
    rsp = Net::HTTP.get_response uri
    rsp.is_a? Net::HTTPSuccess
rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ETIMEDOUT, Net::OpenTimeout
    false
end

def alertmanager_healthy?(host = '127.0.0.1', port = 9093)
    uri = URI "http://#{host}:#{port}/-/healthy"
    rsp = Net::HTTP.get_response uri
    rsp.is_a? Net::HTTPSuccess
rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ETIMEDOUT, Net::OpenTimeout
    false
end

def grafana_healthy?(host = '127.0.0.1', port = 3000)
    uri = URI "http://#{host}:#{port}/api/health"
    rsp = Net::HTTP.get_response uri
    rsp.is_a? Net::HTTPSuccess
rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ETIMEDOUT, Net::OpenTimeout
    false
end

RSpec.describe 'Prometheus Health Checks' do
    before(:all) do
        @defaults = RSpec.configuration.defaults
    end
    it 'Prometheus is ready' do
        wait_loop(success: true, break: nil, timeout: 60, resource_ref: nil) do
            prometheus_ready?
        end
    end
    it 'Prometheus is healthy' do
        wait_loop(success: true, break: nil, timeout: 60, resource_ref: nil) do
            prometheus_healthy?
        end
    end
    it 'Prometheus targets are up' do
        wait_loop(success: true, break: nil, timeout: 180, resource_ref: nil) do
            prometheus_targets_up? frontend_count: detect_ha,
                                   exporter_count: @defaults[:hosts].size
        end
    end
end

RSpec.describe 'Alertmanager Health Checks' do
    it 'Alertmanager is ready' do
        wait_loop(success: true, break: nil, timeout: 60, resource_ref: nil) do
            alertmanager_ready?
        end
    end
    it 'Alertmanager is healthy' do
        wait_loop(success: true, break: nil, timeout: 60, resource_ref: nil) do
            alertmanager_healthy?
        end
    end
end

RSpec.describe 'Grafana Health Checks' do
    it 'Grafana is healthy' do
        wait_loop(success: true, break: nil, timeout: 60, resource_ref: nil) do
            grafana_healthy?
        end
    end
end
