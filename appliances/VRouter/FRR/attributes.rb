# frozen_string_literal: true

require_relative 'sections'

module Service
module FRR
module Attributes
    extend self

    # Kept for the callers and specs that name them.
    PREFIX        = Sections::Bgp::PREFIX
    STATIC_ROUTES = Sections::Static::ATTRIBUTE
    ENABLED       = "#{PREFIX}ENABLED"

    # Settings of the whole module (not of one protocol); boot-only.
    CORE_KEYS = ['ONEAPP_VNF_FRR_ROUTER_ID'].freeze

    # Keep only the module's attributes (those a section owns) that have a non-empty value.
    # Anything but a hash (e.g. a JSON string read from disk) counts as empty.
    def pick(source)
        return {}.freeze unless source.is_a?(Hash)

        source.each_with_object({}) do |(key, value), acc|
            name  = key.to_s
            value = value.to_s.strip
            acc[name] = value if mine?(name) && !value.empty?
        end.freeze
    end

    # Read from the context only: which sections run, the local ASN and the router-ids.
    def boot_only_keys
        (Sections::ALL.flat_map { |section| section.enabled_keys + section.boot_only_keys } + CORE_KEYS).uniq
    end

    # The VM user template (overrides) wins over the context (baseline), except for the boot-only keys.
    def merge(context, overrides)
        pick(context).merge(pick(overrides).except(*boot_only_keys)).freeze
    end

    def mine?(name)
        CORE_KEYS.include?(name) || Sections::ALL.any? { |section| section.owns?(name) }
    end
end
end
end
