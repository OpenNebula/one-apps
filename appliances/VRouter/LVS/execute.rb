# frozen_string_literal: true

require 'erb'
require_relative '../vrouter.rb'

module Service
module LVS
    extend self

    VROUTER_ID = env :VROUTER_ID, nil

    def extract_backends(objects = {})
        static = backends.from_env(prefix: 'ONEAPP_VNF_LB')

        dynamic = VROUTER_ID.nil? ? backends.from_vms(objects, prefix: 'ONEGATE_LB')
                                  : backends.from_vnets(objects, prefix: 'ONEGATE_LB')

        # NOTE: This ensures that backends can be added dynamically only to statically defined LBs.
        merged = hashmap.combine static, backends.intersect(static, dynamic)

        # Replace all "<ONEAPP_VROUTER_ETHx_VIPy>" placeholders where possible.
        backends.resolve_vips merged
    end

    def render_lvs_conf(lvs_vars, basedir: '/etc/keepalived')
        @interfaces ||= parse_interfaces ONEAPP_VNF_LB_INTERFACES
        @mgmt       ||= detect_mgmt_interfaces
        @addrs      ||= addrs_to_nics(@interfaces.keys - @mgmt, family: %[inet]).keys

        file "#{basedir}/conf.d/lvs.conf", ERB.new(<<~LVS, trim_mode: '-').result(binding), mode: 'u=rw,g=r,o=', overwrite: true
            <%- lvs_vars[:by_endpoint]&.each do |(lb_idx, ip, port), servers| -%>
            <%- if @addrs.include?(ip) -%>
            virtual_server <%= ip %> <%= port %> {
                <%- unless lvs_vars[:options][lb_idx][:scheduler].nil? -%>
                lb_algo <%= lvs_vars[:options][lb_idx][:scheduler] %>
                <%- end -%>
                <%- unless lvs_vars[:options][lb_idx][:method].nil? -%>
                lb_kind <%= lvs_vars[:options][lb_idx][:method] %>
                <%- end -%>
                <%- unless lvs_vars[:options][lb_idx][:protocol].nil? -%>
                protocol <%= lvs_vars[:options][lb_idx][:protocol] %>
                <%- end -%>

            <%- servers&.values&.each do |s| -%>
                real_server <%= s[:host] %> <%= s[:port] %> {
                    <%- unless s[:weight].nil? -%>
                    weight <%= s[:weight] %>
                    <%- end -%>
                    <%- unless s[:ulimit].nil? -%>
                    uthreshold <%= s[:ulimit] %>
                    <%- end -%>
                    <%- unless s[:llimit].nil? -%>
                    lthreshold <%= s[:llimit] %>
                    <%- end -%>
                    PING_CHECK {
                        retry 4
                    }
                }
            <%- end -%>
            }
            <%- end -%>
            <%- end -%>
        LVS
    end

    def execute(basedir: '/etc/keepalived')
        msg :info, 'LVS::execute'

        # Handle "static" load-balancers.
        render_lvs_conf extract_backends, basedir: basedir
        toggle [:reload]

        if ONEAPP_VNF_LB_ONEGATE_ENABLED
            prev = []

            get_objects = VROUTER_ID.nil? ? :get_service_vms : :get_vrouter_vnets

            loop do
                unless (objects = method(get_objects).call).empty?
                    if prev != (this = extract_backends(objects))
                        msg :debug, this

                        render_lvs_conf this, basedir: basedir

                        toggle [:reload]
                    end

                    prev = this
                end

                sleep ONEAPP_VNF_LB_REFRESH_RATE.to_i
            end
        else
            sleep
        end
    end

    def cleanup(basedir: '/etc/keepalived')
        msg :info, 'LVS::cleanup'

        file "#{basedir}/conf.d/lvs.conf", '', mode: 'u=rw,g=r,o=', overwrite: true

        toggle [:reload]
    end
end
end
