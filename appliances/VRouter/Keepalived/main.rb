# frozen_string_literal: true

require 'erb'
require_relative '../vrouter.rb'

module Service
module Keepalived
    extend self

    DEPENDS_ON = %w[]

    VROUTER_KEEPALIVED_PASSWORD    = env :VROUTER_KEEPALIVED_PASSWORD, nil
    ONEAPP_VNF_KEEPALIVED_PASSWORD = env :ONEAPP_VNF_KEEPALIVED_PASSWORD, VROUTER_KEEPALIVED_PASSWORD # must be under 8 characters

    ONEAPP_VNF_KEEPALIVED_INTERVAL = env :ONEAPP_VNF_KEEPALIVED_INTERVAL, '1'
    ONEAPP_VNF_KEEPALIVED_PRIORITY = env :ONEAPP_VNF_KEEPALIVED_PRIORITY, '100'

    SERVICE_ID                 = env :SERVICE_ID, nil
    VROUTER_KEEPALIVED_ID      = env :VROUTER_KEEPALIVED_ID, nil
    ONEAPP_VNF_KEEPALIVED_VRID = env :ONEAPP_VNF_KEEPALIVED_VRID, VROUTER_KEEPALIVED_ID

    ONEAPP_VNF_KEEPALIVED_INTERFACES = env :ONEAPP_VNF_KEEPALIVED_INTERFACES, '' # nil -> none, empty -> all

    def parse_env(default_vrid = ONEAPP_VNF_KEEPALIVED_VRID)
        @interfaces ||= parse_interfaces ONEAPP_VNF_KEEPALIVED_INTERFACES
        @mgmt       ||= detect_mgmt_nics
        @nics       ||= addrs_to_nics(@interfaces.keys - @mgmt).values.flatten.uniq
        @vips       ||= detect_vips

        (@interfaces.keys - @mgmt).each_with_object({by_nic: {}, by_vrid: {}}) do |nic, vars|
            vars[:by_nic][nic] = {
                password:   env("ONEAPP_VNF_KEEPALIVED_#{nic.upcase}_PASSWORD", ONEAPP_VNF_KEEPALIVED_PASSWORD),
                interval:   env("ONEAPP_VNF_KEEPALIVED_#{nic.upcase}_INTERVAL", ONEAPP_VNF_KEEPALIVED_INTERVAL),
                priority:   env("ONEAPP_VNF_KEEPALIVED_#{nic.upcase}_PRIORITY", ONEAPP_VNF_KEEPALIVED_PRIORITY),
                vrid:       env("ONEAPP_VNF_KEEPALIVED_#{nic.upcase}_VRID", default_vrid),
                skip:       env("ONEAPP_VNF_KEEPALIVED_#{nic.upcase}_SKIP", 'NO'),
                vips:       @vips[nic]&.values || [],
                noip:       !@nics.include?(nic),
                gw:         env("#{nic.upcase}_GATEWAY", ''),
                gw_default: false
            }
        end.then do |vars|
            vars[:by_nic].each do |nic, opt|
                vars[:by_vrid][opt[:vrid]] ||= {}
                vars[:by_vrid][opt[:vrid]][nic] = opt
            end
            unless ((nic, _) = vars[:by_nic].find { |_, opt| opt[:noip] && !opt[:gw].empty? }).nil?
                vars[:by_nic][nic][:gw_default] = true
            end
            vars
        end
    end

    def install
        msg :info, 'Keepalived::install'

        puts bash 'apk --no-cache add keepalived'
    end

    def configure(basedir: '/etc/keepalived')
        msg :info, 'Keepalived::configure'

        file "#{basedir}/keepalived.conf", <<~MAIN, mode: 'u=rw,g=r,o=', overwrite: true
            include #{basedir}/conf.d/*.conf
        MAIN

        file "#{basedir}/conf.d/global.conf", <<~GLOBAL, mode: 'u=rw,g=r,o=', overwrite: true
            global_defs {
                vrrp_notify_fifo /run/keepalived/vrrp_notify_fifo.sock
                fifo_write_vrrp_states_on_reload
            }
        GLOBAL

        # NOTE: When running inside OneFlow we construct VRID out of the service's ID.
        #       To *completely* avoid possible conflicts, deploy each OneFlow service in an *isolated* VNET.
        default_vrid = if ONEAPP_VNF_KEEPALIVED_VRID.nil?
            unless (svcid = SERVICE_ID || OneGate.instance.service_show&.dig('SERVICE', 'id')).nil?
                svcid.to_i % 255 + 1
            else
                # Please don't rely on this.. If you must, deploy just a single VM per an *isolated* VNET.
                unless (vmid = env(:VMID, nil)).nil?
                    vmid.to_i % 255 + 1
                else
                    1
                end
            end
        else
            ONEAPP_VNF_KEEPALIVED_VRID
        end

        keepalived_vars = parse_env default_vrid

        file "#{basedir}/conf.d/vrrp.conf", ERB.new(<<~VRRP, trim_mode: '-').result(binding), mode: 'u=rw,g=r,o=', overwrite: true
            <%- unless keepalived_vars[:by_vrid].nil? || keepalived_vars[:by_vrid].empty? -%>
            vrrp_sync_group VRouter {
                group {
            <%- keepalived_vars[:by_vrid].each do |_, nics| -%>
            <%- unless ((k, _) = nics.find { |_, opt| !opt[:skip] && !opt[:noip] }).nil? -%>
                    <%= k.upcase %>
            <%- end -%>
            <%- end -%>
                }
            }<%- -%>

            <%- keepalived_vars[:by_vrid].each do |vrid, nics| -%>
            <%- unless ((k, v) = nics.find { |_, opt| !opt[:skip] && !opt[:noip] }).nil? -%>
            vrrp_instance <%= k.upcase %> {
                state             BACKUP
                interface         <%= k.downcase %>
                virtual_router_id <%= vrid %>
                priority          <%= v[:priority] %>
                advert_int        <%= v[:interval] -%>

                virtual_ipaddress {
            <%- nics.each do |nic, opt| -%>
            <%- opt[:vips].compact.reject(&:empty?).each do |vip| -%>
                    <%= vip %> dev <%= nic.downcase %>
            <%- end -%>
            <%- end -%>
                }<%- -%>

                virtual_routes {
            <%- nics.each do |_, opt| -%>
            <%- if opt[:gw_default] -%>
                    0.0.0.0/0 via <%= opt[:gw] %>
            <%- end -%>
            <%- end -%>
                }<%- -%>

            <%- unless v[:password].nil? -%>
                authentication {
                    auth_type PASS
                    auth_pass <%= v[:password] %>
                }
            <%- end -%>
            }
            <%- end -%>
            <%- end -%>
            <%- end -%>
        VRRP

        # NOTE: Unfortunately one-context does not bring up NICs without IP
        #       addresses assigned, this is exactly what happens with
        #       "floating only" VIPs. We make sure here below, all such NICs
        #       are up before we restart Keepalived.
        keepalived_vars[:by_nic].each do |nic, opt|
            ip_link_set_up(nic) if opt[:noip]
        end

        # NOTE: It is important to restart keepalived at this point
        #       to properly re-send vrrp fifo updates to one-failover.
        #       Re-configure can be triggered by direct context changes
        #       or for example a NIC hotplug.
        toggle [:enable, :restart]
    end

    def toggle(operations)
        operations.each do |op|
            msg :info, "Keepalived::toggle([:#{op}])"
            case op
            when :enable
                puts bash 'rc-update add keepalived default'
            when :disable
                puts bash 'rc-update del keepalived default ||:'
            when :update
                puts bash 'rc-update -u'
            else
                puts bash "rc-service keepalived #{op.to_s}"
            end
        end
    end

    def bootstrap
        msg :info, 'Keepalived::bootstrap'
    end
end
end
