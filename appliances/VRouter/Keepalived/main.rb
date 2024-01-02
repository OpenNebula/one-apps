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

    VROUTER_KEEPALIVED_ID      = env :VROUTER_KEEPALIVED_ID, nil
    ONEAPP_VNF_KEEPALIVED_VRID = env :ONEAPP_VNF_KEEPALIVED_VRID, VROUTER_KEEPALIVED_ID

    ONEAPP_VNF_KEEPALIVED_INTERFACES = env :ONEAPP_VNF_KEEPALIVED_INTERFACES, '' # nil -> none, empty -> all

    def parse_env
        @interfaces ||= parse_interfaces ONEAPP_VNF_KEEPALIVED_INTERFACES
        @mgmt       ||= detect_mgmt_interfaces
        @nics       ||= addrs_to_nics(@interfaces.keys - @mgmt, family: %[inet]).values.flatten.uniq
        @vips       ||= detect_vips

        (@interfaces.keys - @mgmt).each_with_object({}) do |nic, vars|
            vars[:by_nic] ||= {}
            vars[:by_nic][nic] = {
                password: env("ONEAPP_VNF_KEEPALIVED_#{nic.upcase}_PASSWORD", ONEAPP_VNF_KEEPALIVED_PASSWORD),
                interval: env("ONEAPP_VNF_KEEPALIVED_#{nic.upcase}_INTERVAL", ONEAPP_VNF_KEEPALIVED_INTERVAL),
                priority: env("ONEAPP_VNF_KEEPALIVED_#{nic.upcase}_PRIORITY", ONEAPP_VNF_KEEPALIVED_PRIORITY),
                vrid:     env("ONEAPP_VNF_KEEPALIVED_#{nic.upcase}_VRID",     ONEAPP_VNF_KEEPALIVED_VRID),
                vips:     @vips[nic]&.values || [],
                noip:     !@nics.include?(nic)
            }
            vars[:by_vrid] ||= {}
            vars[:by_vrid][vars[:by_nic][nic][:vrid]] ||= {}
            vars[:by_vrid][vars[:by_nic][nic][:vrid]][nic] = vars[:by_nic][nic]
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

        keepalived_vars = parse_env

        file "#{basedir}/conf.d/vrrp.conf", ERB.new(<<~VRRP, trim_mode: '-').result(binding), mode: 'u=rw,g=r,o=', overwrite: true
            <%- unless keepalived_vars[:by_vrid].nil? || keepalived_vars[:by_vrid].empty? -%>
            vrrp_sync_group VRouter {
                group {
            <%- keepalived_vars[:by_vrid].each do |_, nics| -%>
            <%- unless (kv = nics.find { |_, opt| !opt[:noip] }).nil? -%>
                    <%= kv[0].upcase %>
            <%- end -%>
            <%- end -%>
                }
            }
            <%- keepalived_vars[:by_vrid].each do |vrid, nics| -%>
            <%- unless (kv = nics.find { |_, opt| !opt[:noip] }).nil? -%>
            vrrp_instance <%= kv[0].upcase %> {
                state             BACKUP
                interface         <%= kv[0].downcase %>
                virtual_router_id <%= vrid %>
                priority          <%= kv[1][:priority] %>
                advert_int        <%= kv[1][:interval] %>
                virtual_ipaddress {
            <%- nics.each do |nic, opt| -%>
            <%- opt[:vips].compact.reject(&:empty?).each do |vip| -%>
                    <%= vip %> dev <%= nic.downcase %>
            <%- end -%>
            <%- end -%>
                }
            <%- unless kv[1][:password].nil? -%>
                authentication {
                    auth_type PASS
                    auth_pass <%= kv[1][:password] %>
                }
            <%- end -%>
            }
            <%- end -%>
            <%- end -%>
            <%- end -%>
        VRRP

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
