# frozen_string_literal: true

require 'erb'
require_relative '../vrouter.rb'

module Service
module HAProxy
    extend self

    VROUTER_ID = env :VROUTER_ID, nil

    def extract_backends(objects = {})
        @ave ||= [detect_addrs, detect_vips].then do |a, v|
            [a, v, detect_endpoints(a, v)]
        end

        static = backends.from_env(prefix: 'ONEAPP_VNF_HAPROXY_LB')

        dynamic = VROUTER_ID.nil? ? backends.from_vms(objects, prefix: 'ONEGATE_HAPROXY_LB')
                                  : backends.from_vnets(objects, prefix: 'ONEGATE_HAPROXY_LB')

        # Replace all "<ETHx_IPy>", "<ETHx_VIPy>" and "<ETHx_EPy>" placeholders where possible.
        static  = backends.resolve  static, *@ave
        dynamic = backends.resolve dynamic, *@ave

        # NOTE: This ensures that backends can be added dynamically only to statically defined LBs.
        backends.combine static, dynamic
    end

    def render_servers_cfg(haproxy_vars, basedir: '/etc/haproxy')
        @interfaces ||= parse_interfaces ONEAPP_VNF_HAPROXY_INTERFACES
        @mgmt       ||= detect_mgmt_nics

        @allowed ||= addrs_to_nics(@interfaces.keys - @mgmt).keys +
                     detect_vips.values.map(&:values).flatten.map { |v| v.split(%[/])[0] }

        file "#{basedir}/servers.cfg", ERB.new(<<~SERVERS, trim_mode: '-').result(binding), mode: 'u=rw,g=r,o=', overwrite: true
            <%- haproxy_vars[:by_endpoint]&.each do |(lb_idx, ip, port), servers| -%>
            <%- if @allowed.include?(ip) -%>
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
