# frozen_string_literal: true

module Service
module FRR
# Removes secrets from text that leaves the router (FRR_APPLY) or reaches a log:
# the value after any `password` keyword or after `md5` in a message-digest-key line (OSPF),
# plus every known secret anywhere.
module Scrub
    extend self

    MASK           = '***'
    PASSWORD_VALUE = /(\bpassword[ \t]+(?:\d[ \t]+)?)(\S+)/i # never across a line
    MD5_VALUE      = /(\bmessage-digest-key[ \t]+\d+[ \t]+md5[ \t]+)(\S+)/i # never across a line

    def text(message, secrets = [])
        known = secrets.compact.map(&:to_s).reject(&:empty?).uniq.sort_by { |secret| -secret.length }
        masked = message.to_s.gsub(PASSWORD_VALUE, "\\1#{MASK}").gsub(MD5_VALUE, "\\1#{MASK}")
        known.reduce(masked) { |out, secret| out.gsub(secret, MASK) }
    end

    # The password and md5 key values written in an frr.conf.
    def secrets_in(config_text)
        config_text.to_s.scan(PASSWORD_VALUE).map(&:last) + config_text.to_s.scan(MD5_VALUE).map(&:last)
    end
end
end
end
