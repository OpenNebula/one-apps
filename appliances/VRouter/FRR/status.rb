# frozen_string_literal: true

require 'json'
require 'time'

module Service
module FRR
module Status
    extend self

    MAX_MESSAGE = 300

    PEER_FAMILIES = %w[ipv4Unicast ipv6Unicast].freeze

    def neighbors(summary_json)
        parsed = JSON.parse(summary_json)
        return {} unless parsed.is_a?(Hash)

        peers = PEER_FAMILIES.flat_map do |family|
            families = parsed.dig(family, 'peers') || {}
            families.is_a?(Hash) ? families.to_a : []
        end

        peers.sort_by(&:first).filter_map do |address, peer|
            next unless peer.is_a?(Hash)
            [address, { state: peer['state'], received: peer['pfxRcd'], advertised: peer['pfxSnt'] }]
        end.to_h
    rescue JSON::ParserError, TypeError
        {}
    end

    def format_neighbors(neighbors)
        return 'no neighbors' if neighbors.empty?

        neighbors.map { |address, n| "#{address}: #{n[:state]} rcv #{n[:received]} snt #{n[:advertised]}" }.join('; ')
    end

    def apply_line(status, message, time)
        [status, time.utc.iso8601, message.to_s.strip].reject(&:empty?).join(' ')
    end

    # OpenNebula template values are double quoted: strip what would break them.
    # OneGate also answers 500 to a quoted value holding = , [ or ], so those
    # are replaced (: ; ( )) before the value is cut.
    ONEGATE_UNSAFE = { '=' => ':', ',' => ';', '[' => '(', ']' => ')' }.freeze

    def sanitize(text)
        text.to_s.gsub(/["\\\r\n]+/, ' ').gsub(/[=,\[\]]/, ONEGATE_UNSAFE).strip[0, MAX_MESSAGE]
    end

    # One KEY="text" line per section status, then the result of the last apply of the whole configuration.
    def to_template(states:, apply:)
        lines = states.map { |key, text| %(#{key}="#{sanitize(text)}") }
        lines << %(FRR_APPLY="#{sanitize(apply)}")
        "#{lines.join("\n")}\n"
    end
end
end
end
