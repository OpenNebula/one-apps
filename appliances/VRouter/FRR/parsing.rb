# frozen_string_literal: true

require_relative 'addresses'

module Service
module FRR
module Parsing
    UINT32 = (0..4_294_967_295).freeze
    ASN    = (1..4_294_967_295).freeze

    TEXT_FORMAT   = /\A[A-Za-z0-9 ._-]{1,64}\z/
    SECRET_FORMAT = /\A[^\s"'\\]{1,80}\z/

    # Reads and validates the attributes that share a prefix (ONEAPP_VNF_BGP_ for the BGP section).
    # Problems are appended to the `errors` array the caller passes in, so that all of them are reported at once.
    class Reader
        def initialize(attrs, prefix)
            @attrs  = attrs
            @prefix = prefix
        end

        def key(name) = "#{@prefix}#{name}"

        # A blank (empty or whitespace-only) value is treated exactly like a missing attribute.
        def value(name)
            raw = @attrs[key(name)]
            raw.nil? || raw.to_s.strip.empty? ? nil : raw
        end

        def integer(name, range, errors, required: false, default: nil)
            raw = value(name)
            return missing(name, required, errors, default) if raw.nil?

            number = Integer(raw, 10)
            return number if range.cover?(number)

            errors << "#{key(name)} must be between #{range.min} and #{range.max}, got #{number}"
            default
        rescue ArgumentError
            errors << "#{key(name)} must be an integer, got #{raw.inspect}"
            default
        end

        def ipv4(name, errors, required: false)
            raw = value(name)
            return missing(name, required, errors, nil) if raw.nil?
            return raw if Addresses.ipv4?(raw)

            errors << "#{key(name)} must be an IPv4 address, got #{raw.inspect} (the router-id is 32 bits, also for IPv6 neighbors)"
            nil
        end

        # NOTE: the offending value is deliberately not echoed (it may be a password).
        def text(name, format, hint, errors)
            raw = value(name)
            return nil if raw.nil?
            return raw if raw.match?(format)

            errors << "#{key(name)} must match: #{hint}"
            nil
        end

        def boolean(name, errors)
            raw = value(name)
            return false if raw.nil?

            case raw.upcase
            when 'YES', '1' then true
            when 'NO', '0' then false
            else
                errors << "#{key(name)} must be YES or NO, got #{raw.inspect}"
                false
            end
        end

        def integers(name, count, errors, default: nil)
            raw = value(name) || default
            return nil if raw.nil?

            parts = raw.split
            return parts.join(' ') if parts.size == count && parts.all? { |part| part.match?(/\A\d{1,5}\z/) }

            errors << "#{key(name)} must be #{count} integers separated by spaces, got #{raw.inspect}"
            nil
        end

        def prefixes(name, errors, ranges: true)
            raw = value(name)
            return [].freeze if raw.nil?

            raw.split(',').map(&:strip).reject(&:empty?)
               .filter_map { |entry| prefix(entry, name, errors, ranges) }.uniq.freeze
        end

        private

        def missing(name, required, errors, default)
            errors << "#{key(name)} is required" if required
            default
        end

        def prefix(entry, name, errors, ranges)
            parts = Addresses.prefix_parts(entry, ranges: ranges)
            if parts.nil?
                errors << "#{key(name)} has an invalid prefix #{entry.inspect} (IPv4 or IPv6, no host bits, lengths within the family)"
                return nil
            end

            text, ge, le = parts
            [text, ge && "ge #{ge}", le && "le #{le}"].compact.join(' ')
        end
    end
end
end
end
