# frozen_string_literal: true

module Service
module FRR
module Forwarding
    extend self

    PATHS = %w[
        /proc/sys/net/ipv4/ip_forward
        /proc/sys/net/ipv4/conf/*/forwarding
        /proc/sys/net/ipv6/conf/*/forwarding
    ].freeze

    # zebra turns IPv4 and IPv6 forwarding on whenever it starts, and frr-reload can turn IPv6 forwarding on.
    # The stock Failover keeps forwarding off on the standby (Router4 and Router6 write zeros for every NIC),
    # but it skips the stop of a service that is not running, so nothing switches it off again. A standby that
    # forwards sends traffic out without the NAT rules of the master during a failover.
    # Returns the paths it could not write.
    def off(paths: PATHS)
        paths.flat_map { |path| Dir.glob(path) }.each_with_object([]) do |path, failed|
            File.write(path, "0\n")
        rescue SystemCallError
            failed << path
        end
    end
end
end
end
