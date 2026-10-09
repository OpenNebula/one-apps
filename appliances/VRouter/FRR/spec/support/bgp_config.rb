# frozen_string_literal: true

require_relative '../../config'

# Parses the attributes of a BGP router with BGP switched on, so the specs do not repeat ENABLED=YES everywhere.
module BgpConfigHelper
    def parse_bgp(attrs, default_router_id: nil)
        Service::FRR::Config.parse_frr(attrs.merge(Service::FRR::Attributes::ENABLED => 'YES'),
                                       default_router_id: default_router_id)
    end
end

RSpec.configure { |config| config.include BgpConfigHelper }
