# frozen_string_literal: true

require 'ipaddr'

module Service
module FRR
# Strict parsing of the addresses and prefixes of the attributes, for both address families.
module Addresses
    extend self

    DOTTED_QUAD   = /\A\d{1,3}(?:\.\d{1,3}){3}\z/
    IPV6_CHARS    = /\A[0-9A-Fa-f:.]+\z/
    PREFIX_FORMAT = %r{\A(\S+?)/(\d{1,3})(?: ge (\d{1,3}))?(?: le (\d{1,3}))?\z}

    # IPAddr of a bare address (no prefix length, no zone id like %eth0, no brackets, no spaces), else nil.
    def parse(raw)
        text = raw.to_s
        return nil unless text.match?(DOTTED_QUAD) || (text.include?(':') && text.match?(IPV6_CHARS))

        ip = IPAddr.new(text)
        # IPv4-mapped/compatible forms would dodge the family and duplicate checks: reject them.
        ip.ipv6? && (ip.ipv4_mapped? || ip.ipv4_compat?) ? nil : ip
    rescue IPAddr::Error
        nil
    end

    def family(raw)
        ip = parse(raw)
        ip && (ip.ipv4? ? :ipv4 : :ipv6)
    end

    def ipv4?(raw) = family(raw) == :ipv4

    def ipv6?(raw) = family(raw) == :ipv6

    # The form FRR prints back (IPv6 compressed, lower case); two spellings of one address compare equal.
    def canonical(raw) = parse(raw)&.to_s

    def link_local?(raw)
        ip = parse(raw)
        !ip.nil? && ip.ipv6? && ip.link_local?
    end

    # Why an address cannot be a BGP peer, update source or gateway (nil when usable). FRR loads such a line,
    # but no session or route can ever work, so the user gets the reason here. Not for prefixes: ::/0 is valid.
    def unusable_peer?(raw)
        ip = parse(raw)
        return nil if ip.nil?

        ip.ipv6? ? unusable_v6(ip.to_i) : unusable_v4(ip.to_i)
    end

    def unusable_v6(number)
        if number.zero? then 'the unspecified address'
        elsif number == 1 then 'a loopback address'
        elsif (number >> 120) == 0xff then 'a multicast address'
        end
    end

    def unusable_v4(number)
        if number.zero? then 'the unspecified address'
        elsif (number >> 24) == 127 then 'a loopback address'
        elsif (number >> 28) == 0xe then 'a multicast address'
        elsif number == 0xffffffff then 'the broadcast address'
        end
    end

    # The family of a prefix entry such as "10.0.0.0/8 le 24" or "2001:db8::/32".
    def entry_family(entry) = entry.include?(':') ? :ipv6 : :ipv4

    def max_length(family) = family == :ipv6 ? 128 : 32

    # [canonical "addr/len", ge, le] for a valid entry (no host bits, lengths within the family), else nil.
    # ranges: false rejects "ge"/"le".
    def prefix_parts(entry, ranges:)
        match = entry.to_s.match(PREFIX_FORMAT) or return nil
        addr  = parse(match[1]) or return nil
        len, ge, le = match[2].to_i, match[3]&.to_i, match[4]&.to_i
        max = max_length(family(match[1]))
        return nil if len > max || (!ranges && (ge || le))
        return nil unless IPAddr.new("#{addr}/#{len}").to_s == addr.to_s # no host bits

        floor = ge || len
        return nil unless (ge.nil? || ge.between?(len, max)) && (le.nil? || le.between?(floor, max))

        ["#{addr}/#{len}", ge, le]
    end
end
end
end
