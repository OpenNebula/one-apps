# frozen_string_literal: true

require 'ipaddr'
require 'json'
require_relative '../addresses'
require_relative '../parsing'

module Service
module FRR
module Sections
module Ospf
    extend self

    NAME   = :ospf
    PREFIX = 'ONEAPP_VNF_OSPF_'

    Settings  = Data.define(:router_id, :default_originate, :redistribute, :backup_cost, :interfaces)
    Interface = Data.define(:index, :name, :area, :cost, :passive, :network_type, :hello_interval, :dead_interval,
                            :password, :bfd)

    GLOBAL_KEYS    = %w[ENABLED ROUTER_ID DEFAULT_ORIGINATE REDISTRIBUTE BACKUP_COST].freeze
    INTERFACE_KEYS = %w[NAME AREA COST PASSIVE NETWORK_TYPE HELLO_INTERVAL DEAD_INTERVAL PASSWORD BFD].freeze
    INTERFACE_KEY  = /\A#{PREFIX}INTERFACE(0|[1-9]\d*)_(.+)\z/
    REDISTRIBUTE   = %w[connected static].freeze # also FRR's printing order
    NETWORK_TYPES  = %w[broadcast point-to-point].freeze
    ORIGINATE      = { 'no' => :no, 'yes' => :yes, 'always' => :always }.freeze
    MD5_FORMAT     = /\A[^\s"'\\]{1,16}\z/
    AREA_RANGE     = (0..4_294_967_295).freeze
    INTERFACE_NAME = /\Aeth\d+\z/

    def owns?(name) = name.start_with?(PREFIX)

    # Enabled for YES and 1, like every stock boolean attribute.
    def enabled?(attrs)
        %w[YES 1].include?(attrs["#{PREFIX}ENABLED"].to_s.strip.upcase)
    end

    def in_context?(env) = enabled?(env)

    def enabled_keys = ["#{PREFIX}ENABLED"]

    def boot_only_keys = ["#{PREFIX}ROUTER_ID"]

    def daemons = ['ospfd']

    # nil when OSPF is not enabled (the other OSPF attributes are then not looked at).
    def parse(attrs, errors, default_router_id: nil)
        return nil unless enabled?(attrs)

        reader    = Parsing::Reader.new(attrs, PREFIX)
        errors.concat(unknown_keys(attrs))
        router_id = reader.ipv4('ROUTER_ID', errors) || default_router_id
        errors << "#{reader.key('ROUTER_ID')} is required (no IPv4 address found on a routed NIC)" if router_id.nil?

        interfaces = interface_indices(attrs).map { |index| interface(reader, attrs, index, errors) }
        duplicates = interfaces.map(&:name).compact.tally.select { |_, count| count > 1 }.keys
        errors << "duplicate OSPF interface: #{duplicates.join(', ')}" unless duplicates.empty?

        Settings.new(
            router_id: router_id,
            default_originate: default_originate(reader, errors),
            redistribute: redistribute(reader, errors),
            backup_cost: reader.integer('BACKUP_COST', 0..65_535, errors, default: 100),
            interfaces: interfaces.freeze
        )
    end

    def config_of(frr_config) = frr_config.section(NAME)

    # Boot-only value: pinned like BGP's, under a name that cannot collide with BGP's router_id.
    def pin_values(cfg)
        { 'ospf_router_id' => cfg.router_id }
    end

    def pinned(frr_config, pin)
        settings = frr_config.section(NAME)
        frr_config.with_section(NAME, settings.with(router_id: pin.fetch('ospf_router_id', settings.router_id)))
    end

    def secrets(cfg)
        cfg.interfaces.filter_map(&:password)
    end

    def partial = 'ospf'

    # What FRR does not print back when it is the default (so it must not be sent either, or every apply re-plans).
    FRR_DEFAULTS = { hello: 10, dead: 40, network_type: 'broadcast' }.freeze

    # FRR's external (type 2) metrics when none is given. A peer chooses between two routers that advertise the same
    # external route by this metric (not by the interface costs), so the VRRP backup adds BACKUP_COST to it.
    DEFAULT_ORIGINATE_METRIC = 1
    REDISTRIBUTE_METRIC      = 20

    # The ERB locals of templates/ospf.erb. The VRRP backup adds BACKUP_COST to every interface cost and to the external
    # metric of the routes it originates or redistributes, so that peers prefer the master for both. The master (and a
    # backup cost of 0) sends no metric: FRR's defaults apply.
    def render_context(settings, ha_state: :master)
        extra     = ha_state == :backup ? settings.backup_cost : 0
        originate = settings.default_originate == :no ? nil : settings.default_originate

        {
            router_id: settings.router_id,
            default_originate: originate,
            default_metric: originate && extra.positive? ? DEFAULT_ORIGINATE_METRIC + extra : nil,
            redistribute: settings.redistribute.map do |source|
                { source: source, metric: extra.positive? ? REDISTRIBUTE_METRIC + extra : nil }
            end,
            interfaces: settings.interfaces.map { |interface| view(interface, extra) }
        }
    end

    # OSPF needs no refresh after an apply.
    def soft_refresh_commands(_cfg) = []

    def status
        {
            key: 'OSPF_STATE',
            command: ['vtysh', '-c', 'show ip ospf neighbor json'],
            text: ->(output) { neighbors_text(output) }
        }
    end

    private

    # "router-id: state interface; ..." from `show ip ospf neighbor json`; tolerant of any other shape.
    def neighbors_text(output)
        parsed = JSON.parse(output.to_s)
        list   = parsed.is_a?(Hash) ? parsed['neighbors'] : nil
        return 'no neighbors' unless list.is_a?(Hash)

        entries = list.flat_map do |router_id, adjacencies|
            Array(adjacencies).filter_map do |neighbor|
                next unless neighbor.is_a?(Hash)

                "#{router_id}: #{neighbor['nbrState']} #{neighbor['ifaceName'].to_s.split(':').first}".strip
            end
        end
        entries.empty? ? 'no neighbors' : entries.sort.join('; ')
    rescue JSON::ParserError, TypeError
        'no neighbors'
    end

    def view(interface, extra)
        {
            name: interface.name,
            area: interface.area,
            cost: [interface.cost + extra, 65_535].min,
            passive: interface.passive,
            network_type: interface.network_type == FRR_DEFAULTS[:network_type] ? nil : interface.network_type,
            hello: interface.hello_interval == FRR_DEFAULTS[:hello] ? nil : interface.hello_interval,
            dead: interface.dead_interval == FRR_DEFAULTS[:dead] ? nil : interface.dead_interval,
            password: interface.password,
            bfd: interface.bfd
        }
    end

    # Only the keys under this section's prefix are looked at (the others belong to other sections).
    def unknown_keys(attrs)
        attrs.keys.filter_map do |name|
            next unless name.start_with?(PREFIX)

            short = name.delete_prefix(PREFIX)
            next if GLOBAL_KEYS.include?(short)
            next if (m = short.match(/\AINTERFACE(?:0|[1-9]\d*)_(.+)\z/)) && INTERFACE_KEYS.include?(m[1])

            "unknown attribute #{name}"
        end
    end

    # Values that do nothing: a slot with only these (what a template with defaults sends for an unused slot) is not one.
    NEUTRAL_VALUES = { 'PASSIVE' => %w[no 0], 'BFD' => %w[no 0] }.freeze

    def interface_indices(attrs)
        attrs.keys.filter_map { |name| name[INTERFACE_KEY, 1]&.to_i }.uniq.sort.reject { |index| unused_slot?(attrs, index) }
    end

    def unused_slot?(attrs, index)
        prefix = "#{PREFIX}INTERFACE#{index}_"
        slot   = attrs.select { |name, value| name.start_with?(prefix) && !value.to_s.strip.empty? }
        return false if slot.key?("#{prefix}NAME")

        slot.all? { |name, value| NEUTRAL_VALUES.fetch(name.delete_prefix(prefix), []).include?(value.to_s.strip.downcase) }
    end

    def interface(reader, attrs, index, errors)
        n        = "INTERFACE#{index}_"
        complete = !reader.value("#{n}NAME").nil?
        errors << incomplete_message(reader, attrs, n) unless complete

        hello = reader.integer("#{n}HELLO_INTERVAL", 1..65_535, errors, default: 10)
        dead  = reader.integer("#{n}DEAD_INTERVAL", 1..65_535, errors, default: 40)
        if hello && dead && dead <= hello
            set = reader.value("#{n}DEAD_INTERVAL").nil? ? ' (not set: the default is 40)' : ''
            errors << "#{reader.key("#{n}DEAD_INTERVAL")} must be greater than #{reader.key("#{n}HELLO_INTERVAL")} (#{dead}#{set} <= #{hello})"
        end

        Interface.new(
            index: index,
            name: interface_name(reader, "#{n}NAME", errors),
            area: area(reader, "#{n}AREA", errors),
            cost: reader.integer("#{n}COST", 1..65_535, errors, default: 10),
            passive: reader.boolean("#{n}PASSIVE", errors),
            network_type: network_type(reader, "#{n}NETWORK_TYPE", errors),
            hello_interval: hello,
            dead_interval: dead,
            password: reader.text("#{n}PASSWORD", MD5_FORMAT, 'at most 16 characters, no whitespace, quotes or backslash', errors),
            bfd: reader.boolean("#{n}BFD", errors)
        )
    end

    def incomplete_message(reader, attrs, prefix)
        keys = attrs.keys.select do |name|
            name.start_with?(reader.key(prefix)) && !reader.value(name.delete_prefix(PREFIX)).nil?
        end
        "interface slot #{prefix.delete_suffix('_').delete_prefix('INTERFACE')} is incomplete: it has " \
            "#{keys.join(', ')} but no #{reader.key("#{prefix}NAME")} (leave unused interface slots empty)"
    end

    def interface_name(reader, name, errors)
        raw = reader.value(name)
        return nil if raw.nil?
        return raw if raw.match?(INTERFACE_NAME)

        errors << "#{reader.key(name)} must be an interface like eth1, got #{raw.inspect}"
        nil
    end

    # A number or a dotted quad; stored as the number so that 0 and 0.0.0.0 are the same area.
    def area(reader, name, errors)
        raw = reader.value(name)
        return 0 if raw.nil?

        value  = raw.strip
        number = if value.match?(/\A\d+\z/)
                     Integer(value, 10)
                 elsif Addresses.ipv4?(value)
                     IPAddr.new(value).to_i
                 end
        return number if number && AREA_RANGE.cover?(number)

        errors << "#{reader.key(name)} must be a number between 0 and 4294967295 or a dotted quad, got #{raw.inspect}"
        0
    end

    def network_type(reader, name, errors)
        raw = reader.value(name)
        return 'broadcast' if raw.nil?
        return raw.strip.downcase if NETWORK_TYPES.include?(raw.strip.downcase)

        errors << "#{reader.key(name)} must be #{NETWORK_TYPES.join(' or ')}, got #{raw.inspect}"
        'broadcast'
    end

    def default_originate(reader, errors)
        raw = reader.value('DEFAULT_ORIGINATE')
        return :no if raw.nil?
        return ORIGINATE[raw.strip.downcase] if ORIGINATE.key?(raw.strip.downcase)

        errors << "#{reader.key('DEFAULT_ORIGINATE')} must be NO, YES or ALWAYS, got #{raw.inspect}"
        :no
    end

    def redistribute(reader, errors)
        raw = reader.value('REDISTRIBUTE')
        return [].freeze if raw.nil?

        items = raw.split(/[ ,]+/).reject(&:empty?).map(&:downcase)
        bad   = items - REDISTRIBUTE
        errors << "#{reader.key('REDISTRIBUTE')} allows only #{REDISTRIBUTE.join(', ')}, got #{bad.join(', ')}" unless bad.empty?

        (REDISTRIBUTE & items).freeze
    end
end
end
end
end
