# frozen_string_literal: true

require 'ipaddr'
require_relative '../addresses'

module Service
module FRR
    StaticRoute = Data.define(:prefix, :gateway) do
        def family = Addresses.family(prefix.split('/').first)
    end

module Sections
module Static
    extend self

    NAME      = :static
    ATTRIBUTE = 'ONEAPP_VNF_STATIC_ROUTES'

    Settings = Data.define(:routes)

    # Words of `ip route` (and of the kernel's route syntax) that are valid but not supported yet.
    ROUTE_WORDS  = %w[dev blackhole reject unreachable prohibit metric distance tag table src onlink nexthop
                      vrf label bfd].freeze
    ROUTE_FORMAT = %r{\A(\S+)\s+via\s+(\S+)\z}i
    NO_ROUTES    = 'none'

    def owns?(name) = name == ATTRIBUTE

    # Whether the attribute is set in the container environment.
    def in_context?(env) = configured?(env)

    def enabled_keys = []

    def boot_only_keys = []

    def daemons = []

    # nil when the attribute is blank; the routes are [] for NONE.
    def parse(attrs, errors, default_router_id: nil)
        return nil unless configured?(attrs)

        Settings.new(routes: routes(attrs, errors))
    end

    def config_of(frr_config) = frr_config.section(NAME)

    def partial = 'static'

    def render_context(settings, ha_state: :master)
        {
            static_v4: settings.routes.select { |route| route.family == :ipv4 },
            static_v6: settings.routes.select { |route| route.family == :ipv6 }
        }
    end

    def pin_values(_cfg) = {}

    def pinned(frr_config, _pin) = frr_config

    def secrets(_cfg) = []

    def soft_refresh_commands(_cfg) = []

    def status = nil

    private

    # The attribute is set, from the context or from an override. NONE counts: it is the way to
    # start with no routes and add them live.
    def configured?(attrs)
        !attrs[ATTRIBUTE].to_s.strip.empty?
    end

    # `<prefix> via <gateway>, ...`, or NONE for no routes. Sorted the way FRR prints
    # them (IPv4 first, then length, then address), so the order of the attribute never changes the config.
    def routes(attrs, errors)
        raw = attrs[ATTRIBUTE].to_s.strip
        return [].freeze if raw.empty? || raw.casecmp?(NO_ROUTES)

        found = raw.split(',', -1).filter_map { |entry| route(entry.strip, errors) }
        duplicates = found.map(&:prefix).tally.select { |_, count| count > 1 }.keys
        errors << "#{ATTRIBUTE} has duplicate prefix #{duplicates.join(', ')}" unless duplicates.empty?

        found.sort_by { |item| route_order(item.prefix) }.freeze
    end

    def route_order(prefix)
        address, length = prefix.split('/')
        ip = IPAddr.new(address)
        [ip.ipv6? ? 1 : 0, length.to_i, ip.to_i]
    end

    def route(entry, errors)
        name = ATTRIBUTE
        if (match = entry.match(ROUTE_FORMAT)) && !route_option?(entry)
            return route_from(match[1], match[2], name, errors)
        end

        errors << if entry.empty?
                      "#{name} has an empty entry (stray comma?)"
                  elsif route_option?(entry)
                      "#{name} entry #{entry.inspect} uses a route option that is not supported yet " \
                          "(only '<prefix> via <gateway>' is supported)"
                  else
                      "#{name} entry #{entry.inspect} must look like '<prefix>/<length> via <gateway>'"
                  end
        nil
    end

    def route_option?(entry)
        entry.downcase.split.intersect?(ROUTE_WORDS)
    end

    def route_from(prefix, gateway, name, errors)
        ip, length = prefix.split('/', 2)
        parts      = length&.match?(/\A\d{1,3}\z/) ? Addresses.prefix_parts("#{ip}/#{length}", ranges: false) : nil
        errors << "#{name} has an invalid prefix #{prefix.inspect} (IPv4 or IPv6, no host bits)" if parts.nil?

        gw = Addresses.canonical(gateway)
        if gw && (reason = Addresses.unusable_peer?(gw))
            errors << "#{name} has an invalid gateway #{gateway.inspect} (not usable: #{reason})"
            gw = nil
        elsif gw.nil? || Addresses.link_local?(gw)
            errors << "#{name} has an invalid gateway #{gateway.inspect} (a global IPv4 or IPv6 address; link-local is not supported yet)"
            gw = nil
        end
        if parts && gw && Addresses.family(parts.first.split('/').first) != Addresses.family(gw)
            errors << "#{name} entry #{prefix} via #{gateway} mixes IPv4 and IPv6"
            gw = nil
        end

        StaticRoute.new(prefix: parts.first, gateway: gw) if parts && gw
    end
end
end
end
end
