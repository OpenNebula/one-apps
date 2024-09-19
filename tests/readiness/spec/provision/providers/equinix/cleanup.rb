require 'json'

# Equinix
class Equinix

    # API endpoint
    URL = 'https://api.equinix.com/metal/v1'

    def initialize(token, project)
        @url     = "-H 'X-Auth-Token: #{token}' #{URL}"
        @project = project
    end

    def delete_devices
        devices = SafeExec.run(
            "curl -s #{@url}/projects/#{@project}/devices"
        ).stdout

        begin
            devices = JSON.parse(devices)
        rescue StandardError
            return true
        end

        devices['devices'].each do |device|
            SafeExec.run("curl -s -X DELETE #{@url}/devices/#{device['id']}")
        end

        !devices['devices'] || devices['devices'].empty?
    end

    def delete_net
        nets = SafeExec.run("curl -s #{@url}/projects/#{@project}/ips").stdout

        begin
            nets = JSON.parse(nets)
        rescue StandardError
            return true
        end

        # Remove management IPs as they cannot be deleted
        nets['ip_addresses'].select! {|n| n['bill'] }

        nets['ip_addresses'].each do |net|
            SafeExec.run("curl -s -X DELETE #{@url}/ips/#{net['id']}")
        end

        !nets['ip_addresses'] || nets['ip_addresses'].empty?
    end

end
