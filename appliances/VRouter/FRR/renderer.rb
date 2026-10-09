# frozen_string_literal: true

require 'erb'
require_relative 'config'
require_relative 'ha_state'

module Service
module FRR
module Renderer
    extend self

    TEMPLATES = File.join(__dir__, 'templates')

    HA_STATES = HaState::STATES

    # What FRR accepts as a hostname (HOST_NAME_MAX is 64); anything else, a
    # newline above all, could inject configuration lines.
    HOSTNAME_FORMAT = /\A[A-Za-z0-9._-]{1,64}\z/

    # The header, then the partial of every configured section in Sections::RENDER_ORDER.
    def render(config, hostname:, ha_state: :master)
        raise ArgumentError, "ha_state must be one of #{HA_STATES.inspect}" unless HA_STATES.include?(ha_state)
        raise ArgumentError, 'hostname contains unsafe characters' unless hostname.to_s.match?(HOSTNAME_FORMAT)

        parts = [header(hostname: hostname)]
        Sections::RENDER_ORDER.each do |mod|
            settings = config.section(mod::NAME)
            parts << partial(mod.partial, mod.render_context(settings, ha_state: ha_state)) unless settings.nil?
        end

        parts.join
    end

    # The first lines of every config, also the whole fallback config (no sections). The hostname line is left
    # out when there is no usable hostname.
    def header(hostname:)
        partial('header', { hostname: hostname })
    end

    private

    def partial(name, locals)
        ERB.new(File.read(File.join(TEMPLATES, "#{name}.erb")), trim_mode: '-').result_with_hash(locals)
    end
end
end
end
