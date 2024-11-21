require_relative '../vrouter.rb'

module Service
    module DHCP4v2
        extend self

        DEPENDS_ON = %w[Service::Failover]

        def install(initdir: '/etc/init.d')
            msg :info, 'DHCP4::install'
            
            file "#{initdir}/one-dhcp4v2", <<~SERVICE, mode: 'u=rwx,g=rx,o='
            #!/sbin/openrc-run

            source /run/one-context/one_env

            command="/etc/one-appliance/service.d/VRouter/DHCP4v2/dhcpcore-onelease/dhcpcore-onelease"
            #TODO: command_args

            output_log="/var/log/one-appliance/one-dhcp4v2.log"
            error_log="/var/log/one-appliance/one-dhcp4v2.log"

            depend() {
                after net firewall keepalived
            }
        SERVICE
            toggle [:update]
        end

        def toggle(operations)
            operations.each do |op|
                msg :debug, "DHCP4::toggle([:#{op}])"
                case op
                when :disable
                    puts bash 'rc-update del one-dhcp4v2 default ||:'
                when :update
                    puts bash 'rc-update -u'
                else
                    puts bash "rc-service one-dhcp4v2 #{op.to_s}"
                end
            end
        end
    
        def bootstrap
            msg :info, 'DHCP4::bootstrap'
        end
    end
end