# frozen_string_literal: true

require 'erb'
require_relative '../vrouter.rb'

module Service
module HAProxy
    extend self

    VROUTER_ID = env :VROUTER_ID, nil

    def extract_backends(objects = {})
        static = backends.from_env(prefix: 'ONEAPP_VNF_HAPROXY_LB')

        dynamic = VROUTER_ID.nil? ? backends.from_vms(objects, prefix: 'ONEGATE_HAPROXY_LB')
                                  : backends.from_vnets(objects, prefix: 'ONEGATE_HAPROXY_LB')

        # NOTE: This ensures that backends can be added dynamically only to statically defined LBs.
        merged = hashmap.combine static, backends.intersect(static, dynamic)

        # Replace all "<ONEAPP_VROUTER_ETHx_VIPy>" placeholders where possible.
        backends.resolve_vips merged
    end

    def render_servers_cfg(haproxy_vars, basedir: '/etc/haproxy')
        @interfaces ||= parse_interfaces ONEAPP_VNF_HAPROXY_INTERFACES
        @mgmt       ||= detect_mgmt_interfaces
        @addrs      ||= addrs_to_nics(@interfaces.keys - @mgmt, family: %[inet]).keys

        file "#{basedir}/servers.cfg", ERB.new(<<~SERVERS, trim_mode: '-').result(binding), mode: 'u=rw,g=r,o=', overwrite: true
            <%- haproxy_vars[:by_endpoint]&.each do |(lb_idx, ip, port), servers| -%>
            <%- if @addrs.include?(ip) -%>
            frontend lb<%= lb_idx %>_<%= port %>
                mode tcp
                bind <%= ip %>:<%= port %>
                default_backend lb<%= lb_idx %>_<%= port %>

            backend lb<%= lb_idx %>_<%= port %>
                mode tcp
                balance roundrobin
                option tcp-check
            <%- servers&.values&.each do |s| -%>
                server lb<%= lb_idx %>_<%= s[:host] %>_<%= s[:port] %> <%= s[:host] %>:<%= s[:port] %> check observe layer4 error-limit 50 on-error mark-down
            <% end %>
            <%- end -%>
            <%- end -%>
        SERVERS
    end

    def execute(basedir: '/etc/haproxy')
        msg :info, 'HAProxy::execute'

        # Handle "static" load-balancers.
        render_servers_cfg extract_backends, basedir: basedir
        toggle [:reload]

        if ONEAPP_VNF_HAPROXY_ONEGATE_ENABLED
            prev = []

            get_objects = VROUTER_ID.nil? ? :get_service_vms : :get_vrouter_vnets

            loop do
                unless (objects = method(get_objects).call).empty?
                    if prev != (this = extract_backends(objects))
                        msg :debug, this

                        render_servers_cfg this, basedir: basedir

                        toggle [:reload]
                    end

                    prev = this
                end

                sleep ONEAPP_VNF_HAPROXY_REFRESH_RATE.to_i
            end
        else
            sleep
        end
    end
end
end
