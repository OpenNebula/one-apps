# frozen_string_literal: true

require_relative '../addresses'
require_relative '../parsing'
require_relative '../status'

module Service
module FRR
    Neighbor = Data.define(
        :index, :address, :asn, :description, :password, :bfd, :bfd_timers, :timers,
        :update_source, :max_prefix, :local_pref, :med, :prepend, :import_prefixes, :export_prefixes
    ) do
        def family = Addresses.family(address)
    end

module Sections
module Bgp
    extend self

    NAME   = :bgp
    PREFIX = 'ONEAPP_VNF_BGP_'

    Settings = Data.define(:asn, :router_id, :networks, :redistribute, :backup_prepend, :backup_med, :neighbors)

    GLOBAL_KEYS   = %w[ENABLED ASN ROUTER_ID NETWORKS REDISTRIBUTE POLL_INTERVAL BACKUP_PREPEND BACKUP_MED].freeze
    NEIGHBOR_KEYS = %w[ADDRESS ASN DESCRIPTION PASSWORD BFD BFD_TIMERS TIMERS UPDATE_SOURCE MAX_PREFIX
                       LOCAL_PREF MED PREPEND IMPORT_PREFIXES EXPORT_PREFIXES].freeze
    REDISTRIBUTE  = %w[connected static kernel].freeze

    DEFAULT_BFD_TIMERS = '3 300 300'
    NEIGHBOR_KEY  = /\A#{PREFIX}NEIGHBOR(0|[1-9]\d*)_(.+)\z/

    def owns?(name) = name.start_with?(PREFIX)

    # Enabled for YES and 1, like every stock boolean attribute (the rule of the environment helper).
    def enabled?(attrs)
        %w[YES 1].include?(attrs["#{PREFIX}ENABLED"].to_s.strip.upcase)
    end

    # The same rule, asked of the container environment.
    def in_context?(env) = enabled?(env)

    def enabled_keys = ["#{PREFIX}ENABLED"]

    def boot_only_keys = %w[ASN ROUTER_ID].map { |key| "#{PREFIX}#{key}" }

    def daemons = ['bgpd']

    # nil when BGP is not enabled (the other BGP attributes are then not looked at).
    def parse(attrs, errors, default_router_id: nil)
        return nil unless enabled?(attrs)

        reader    = Parsing::Reader.new(attrs, PREFIX)
        errors.concat(unknown_keys(attrs))
        asn       = reader.integer('ASN', Parsing::ASN, errors, required: true)
        router_id = reader.ipv4('ROUTER_ID', errors) || default_router_id
        errors << "#{reader.key('ROUTER_ID')} is required (no IPv4 address found on a routed NIC)" if router_id.nil?

        neighbors  = neighbor_indices(attrs).map { |index| neighbor(reader, attrs, index, errors) }
        duplicates = neighbors.map(&:address).compact.tally.select { |_, count| count > 1 }.keys
        errors << "duplicate neighbor address: #{duplicates.join(', ')}" unless duplicates.empty?

        Settings.new(
            asn: asn, router_id: router_id,
            networks: reader.prefixes('NETWORKS', errors, ranges: false),
            redistribute: redistribute(reader, errors),
            backup_prepend: reader.integer('BACKUP_PREPEND', 0..10, errors, default: 3),
            backup_med: reader.integer('BACKUP_MED', Parsing::UINT32, errors, default: 200),
            neighbors: neighbors.freeze
        )
    end

    # The settings of this section in a FrrConfig, or nil when BGP is not configured.
    def config_of(frr_config) = frr_config.section(NAME)

    # Boot-only values: only the first successful apply pins them (boot.json), later changes are ignored.
    def pin_values(cfg)
        { 'asn' => cfg.asn, 'router_id' => cfg.router_id }
    end

    def pinned(frr_config, pin)
        settings = frr_config.section(NAME)
        frr_config.with_section(
            NAME, settings.with(asn: pin.fetch('asn', settings.asn), router_id: pin.fetch('router_id', settings.router_id))
        )
    end

    def secrets(cfg)
        cfg.neighbors.filter_map(&:password)
    end

    # The result is informational only, so both families are asked for even when one has no neighbor.
    def soft_refresh_commands(_cfg)
        %w[ipv4 ipv6].map { |family| ['vtysh', '-c', "clear bgp #{family} unicast * soft"] }
    end

    def status
        {
            key: 'BGP_STATE',
            command: ['vtysh', '-c', 'show bgp summary json'],
            text: ->(output) { Status.format_neighbors(Status.neighbors(output)) }
        }
    end

    def partial = 'bgp'

    # The ERB locals of templates/bgp.erb, with the HA profile already applied.
    def render_context(settings, ha_state: :master)
        neighbors   = settings.neighbors.map { |neighbor| view(neighbor, settings, ha_state) }
        networks_v6 = family_entries(settings.networks, :ipv6)
        networks_v4 = family_entries(settings.networks, :ipv4)
        v6 = neighbors.any? { |n| n[:family] == :ipv6 } || networks_v6.any?
        # FRR does not print an empty ipv4 block back, so an IPv6-only config must not render one
        v4 = !v6 || networks_v4.any? || settings.redistribute.any? || neighbors.any? { |n| n[:family] == :ipv4 }

        {
            asn: settings.asn, router_id: settings.router_id, networks_v4: networks_v4, networks_v6: networks_v6,
            redistribute: settings.redistribute, neighbors: neighbors, v4: v4, v6: v6
        }
    end

    private

    def family_entries(entries, family)
        entries.select { |entry| Addresses.entry_family(entry) == family }
    end

    # :all (empty list), :list (entries of the neighbor's family), :none (a list without any of its family).
    def filter_mode(entries, own)
        return :all if entries.empty?

        own.empty? ? :none : :list
    end

    # FRR 10.2 prints plain `neighbor X bfd` whatever the timers are (a `bfd 5 200 200`
    # line is applied but never printed back), so a candidate with timers on that line
    # never equals the running config and every apply would delete and re-create the BFD
    # session, which drops BGP. Non-default timers therefore go in a bfd profile, which
    # FRR does print back.
    def bfd_profile(neighbor, name)
        timers = neighbor.bfd_timers.split.map(&:to_i) # FRR prints 03 as 3
        return nil if !neighbor.bfd || timers.join(' ') == DEFAULT_BFD_TIMERS

        { name: name, multiplier: timers[0], receive: timers[1], transmit: timers[2] }
    end

    # What the template needs, with the HA profile already applied.
    def view(neighbor, bgp, ha_state)
        backup = ha_state == :backup
        family = neighbor.family
        imports = family_entries(neighbor.import_prefixes, family)
        exports = family_entries(neighbor.export_prefixes, family)

        {
            name: "BGP-N#{neighbor.index}",
            address: neighbor.address,
            asn: neighbor.asn,
            description: neighbor.description,
            password: neighbor.password,
            bfd: neighbor.bfd,
            bfd_profile: bfd_profile(neighbor, "BGP-N#{neighbor.index}"),
            timers: neighbor.timers,
            update_source: neighbor.update_source,
            max_prefix: neighbor.max_prefix,
            local_pref: neighbor.local_pref,
            family: family,
            prefix_list: family == :ipv6 ? 'ipv6 prefix-list' : 'ip prefix-list',
            match: family == :ipv6 ? 'ipv6' : 'ip',
            import_mode: filter_mode(neighbor.import_prefixes, imports),
            export_mode: filter_mode(neighbor.export_prefixes, exports),
            import_prefixes: imports,
            export_prefixes: exports,
            med: med(neighbor, bgp, backup),
            prepend: [bgp.asn.to_s] * (neighbor.prepend + (backup ? bgp.backup_prepend : 0))
        }
    end

    # The backup adds BACKUP_MED to the neighbor's own MED, so that it is never preferred over the master.
    def med(neighbor, bgp, backup)
        return neighbor.med unless backup

        total = [(neighbor.med || 0) + bgp.backup_med, Parsing::UINT32.last].min
        total.zero? && neighbor.med.nil? ? nil : total
    end

    # Only the keys under this section's prefix are looked at (the others belong to other sections).
    def unknown_keys(attrs)
        attrs.keys.filter_map do |name|
            next unless name.start_with?(PREFIX)

            short = name.delete_prefix(PREFIX)
            next if GLOBAL_KEYS.include?(short)
            next if (m = short.match(/\ANEIGHBOR(?:0|[1-9]\d*)_(.+)\z/)) && NEIGHBOR_KEYS.include?(m[1])

            "unknown attribute #{name}"
        end
    end

    # Values that do nothing: a slot with only these (what a template with defaults sends for an unused slot) is not one.
    NEUTRAL_VALUES = { 'BFD' => %w[no 0], 'PREPEND' => %w[0] }.freeze

    def neighbor_indices(attrs)
        attrs.keys.filter_map { |name| name[NEIGHBOR_KEY, 1]&.to_i }.uniq.sort.reject { |index| unused_slot?(attrs, index) }
    end

    def unused_slot?(attrs, index)
        prefix = "#{PREFIX}NEIGHBOR#{index}_"
        slot   = attrs.select { |name, value| name.start_with?(prefix) && !value.to_s.strip.empty? }
        return false if slot.key?("#{prefix}ADDRESS") || slot.key?("#{prefix}ASN")

        slot.all? { |name, value| NEUTRAL_VALUES.fetch(name.delete_prefix(prefix), []).include?(value.to_s.strip.downcase) }
    end

    def neighbor(reader, attrs, index, errors)
        n = "NEIGHBOR#{index}_"
        complete = !(reader.value("#{n}ADDRESS").nil? && reader.value("#{n}ASN").nil?)
        errors << incomplete_message(reader, attrs, n) unless complete

        address = neighbor_address(reader, "#{n}ADDRESS", errors, required: complete)

        Neighbor.new(
            index: index,
            address: address,
            asn: reader.integer("#{n}ASN", Parsing::ASN, errors, required: complete),
            description: reader.text("#{n}DESCRIPTION", Parsing::TEXT_FORMAT, 'letters, digits, space, dot, dash, underscore', errors),
            password: reader.text("#{n}PASSWORD", Parsing::SECRET_FORMAT, 'no whitespace, quotes or backslash', errors),
            bfd: reader.boolean("#{n}BFD", errors),
            bfd_timers: bfd_timers(reader, "#{n}BFD_TIMERS", errors),
            timers: timers(reader, "#{n}TIMERS", errors),
            update_source: update_source(reader, "#{n}UPDATE_SOURCE", errors, Addresses.family(address)),
            max_prefix: reader.integer("#{n}MAX_PREFIX", 1..Parsing::UINT32.last, errors),
            local_pref: reader.integer("#{n}LOCAL_PREF", Parsing::UINT32, errors),
            med: reader.integer("#{n}MED", Parsing::UINT32, errors),
            prepend: reader.integer("#{n}PREPEND", 0..10, errors, default: 0),
            import_prefixes: reader.prefixes("#{n}IMPORT_PREFIXES", errors),
            export_prefixes: reader.prefixes("#{n}EXPORT_PREFIXES", errors)
        )
    end

    # "keepalive hold", each 0..65535; FRR refuses a hold time of 1 or 2.
    def timers(reader, name, errors)
        raw = reader.integers(name, 2, errors) or return nil
        keepalive, hold = raw.split.map(&:to_i)
        return raw if keepalive <= 65_535 && hold <= 65_535 && (hold.zero? || hold >= 3)

        errors << "#{reader.key(name)} must be keepalive and hold time in 0..65535 seconds, the hold time 0 or at least 3, got #{raw.inspect}"
        nil
    end

    # "multiplier receive transmit": FRR takes a multiplier of 2..255 and intervals of 10..60000 ms.
    def bfd_timers(reader, name, errors)
        raw = reader.integers(name, 3, errors, default: DEFAULT_BFD_TIMERS) or return nil
        multiplier, receive, transmit = raw.split.map(&:to_i)
        return raw if multiplier.between?(2, 255) && [receive, transmit].all? { |ms| ms.between?(10, 60_000) }

        errors << "#{reader.key(name)} must be multiplier (2..255), receive and transmit interval (10..60000 ms), got #{raw.inspect}"
        nil
    end

    def incomplete_message(reader, attrs, prefix)
        keys = attrs.keys.select do |name|
            name.start_with?(reader.key(prefix)) && !reader.value(name.delete_prefix(PREFIX)).nil?
        end
        "neighbor slot #{prefix.delete_suffix('_').delete_prefix('NEIGHBOR')} is incomplete: it has " \
            "#{keys.join(', ')} but no #{reader.key("#{prefix}ADDRESS")} and #{reader.key("#{prefix}ASN")} " \
            '(leave unused neighbor slots empty, including defaults such as BFD=NO)'
    end

    def neighbor_address(reader, name, errors, required: false)
        raw = reader.value(name)
        if raw.nil?
            errors << "#{reader.key(name)} is required" if required
            return nil
        end

        canonical = Addresses.canonical(raw)
        if canonical.nil?
            errors << "#{reader.key(name)} must be an IPv4 or IPv6 address, got #{raw.inspect}"
        elsif (reason = Addresses.unusable_peer?(canonical))
            errors << "#{reader.key(name)} must be an IPv4 or IPv6 address, got #{raw.inspect} (not usable: #{reason})"
        elsif Addresses.link_local?(canonical)
            errors << "#{reader.key(name)} is a link-local IPv6 address, which is not supported yet (use a global or ULA address)"
        else
            return canonical
        end
        nil
    end

    def update_source(reader, name, errors, family)
        raw = reader.value(name)
        return nil if raw.nil?
        return raw if raw.match?(/\Aeth\d+\z/)

        canonical = Addresses.canonical(raw)
        canonical = nil if canonical && Addresses.unusable_peer?(canonical)
        return canonical if canonical && !Addresses.link_local?(canonical) && (family.nil? || Addresses.family(canonical) == family)

        errors << "#{reader.key(name)} must be an address of the neighbor's family or an interface like eth1, got #{raw.inspect}"
        nil
    end

    def redistribute(reader, errors)
        raw = reader.value('REDISTRIBUTE')
        return [].freeze if raw.nil?

        items = raw.split(/[ ,]+/).reject(&:empty?)
        bad   = items - REDISTRIBUTE
        errors << "#{reader.key('REDISTRIBUTE')} allows only #{REDISTRIBUTE.join(', ')}, got #{bad.join(', ')}" unless bad.empty?

        (items & REDISTRIBUTE).uniq.freeze
    end
end
end
end
end
