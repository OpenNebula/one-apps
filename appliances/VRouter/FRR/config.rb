# frozen_string_literal: true

require_relative 'addresses'
require_relative 'attributes'
require_relative 'parsing'
require_relative 'sections'

module Service
module FRR
    class ConfigError < StandardError
        attr_reader :errors

        def initialize(errors)
            @errors = errors.dup.freeze
            super "invalid FRR configuration: #{@errors.join('; ')}"
        end
    end

    # The whole FRR configuration: the core settings plus the settings of every configured section
    # (a section that is not configured is absent).
    FrrConfig = Data.define(:poll_interval, :sections) do
        def section(name) = sections[name]

        def with_section(name, settings)
            with(sections: sections.merge(name => settings).freeze)
        end
    end

    # Parses the flat attributes into immutable values.
    # NOTE: `errors` is a locally scoped accumulator so that all problems are
    #       reported at once; the returned values are frozen.
    module Config
        extend self

        DEFAULT_POLL = 30

        # The sections in parse order, then the core settings. A section that is not enabled is not looked at
        # (without BGP the other BGP attributes are ignored).
        def parse_frr(attrs, default_router_id: nil)
            errors   = []
            # The router-id shared by the protocols: between a protocol's own attribute and the NIC default.
            # Only looked at when a protocol runs (a section that has `enabled?`); static routes do not use it.
            shared   = nil
            if Sections::ALL.any? { |mod| mod.respond_to?(:enabled?) && mod.enabled?(attrs) }
                shared = Parsing::Reader.new(attrs, 'ONEAPP_VNF_FRR_').ipv4('ROUTER_ID', errors)
            end
            sections = Sections::ALL.each_with_object({}) do |mod, acc|
                settings = mod.parse(attrs, errors, default_router_id: shared || default_router_id)
                acc[mod::NAME] = settings unless settings.nil?
            end
            poll = Parsing::Reader.new(attrs, Attributes::PREFIX)
                                  .integer('POLL_INTERVAL', 5..3600, errors, default: DEFAULT_POLL)

            raise ConfigError.new(errors) unless errors.empty?

            FrrConfig.new(poll_interval: poll, sections: sections.freeze)
        end

        def default_router_id(env)
            numbers = env.keys.filter_map { |name| name[/\AETH(\d+)_IP\z/, 1]&.to_i }.sort
            mgmt    = env.keys.filter_map do |name|
                number = name[/\AETH(\d+)_VROUTER_MANAGEMENT\z/, 1]
                number.to_i if number && %w[YES 1].include?(env[name].to_s.upcase)
            end

            (numbers - mgmt).map { |n| env["ETH#{n}_IP"] }.find { |ip| Addresses.ipv4?(ip.to_s) }
        end
    end
end
end
