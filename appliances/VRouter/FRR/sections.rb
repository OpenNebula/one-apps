# frozen_string_literal: true

require_relative 'sections/bgp'
require_relative 'sections/static'
require_relative 'sections/ospf'

module Service
module FRR
# The routing protocols (and static routes) the module configures. Each section module answers the same
# small set of questions; the core (Applier, Reloader, Reporter, main) only loops over them.
module Sections
    extend self

    # The parse order.
    ALL = [Bgp, Static, Ospf].freeze

    # The order of the parts in frr.conf: static routes first, then the protocols (OSPF before BGP).
    RENDER_ORDER = [Static, Ospf, Bgp].freeze

    # [[section module, its part of the config], ...] for the sections the config has, in ALL order.
    def active(config)
        ALL.filter_map do |mod|
            part = mod.config_of(config)
            [mod, part] unless part.nil?
        end
    end

    def pinned?(config)
        active(config).any? { |mod, cfg| mod.pin_values(cfg).any? }
    end
end
end
end
