# frozen_string_literal: true

require_relative '../vrouter.rb'
require_relative 'status'
require_relative 'reloader'
require_relative 'sections'

module Service
module FRR
# Publishes the section states (BGP_STATE) and FRR_APPLY to the VM user template over OneGate,
# only when the text changed (a changing value on every tick would be noise).
class Reporter
    Applied = Data.define(:status, :message, :config)

    RETRY_DELAY = 60

    # `sections` are the ones whose status is published (the router's configured protocols).
    def initialize(onegate:, reloader:, clock: -> { Time.now }, retry_delay: RETRY_DELAY, sections: Sections::ALL)
        @sections  = sections
        @onegate   = onegate
        @reloader  = reloader
        @clock     = clock
        @apply     = 'none'
        @last_sent = nil
        @retry_delay = retry_delay
        @retry_at    = nil
        @last_error  = nil
        @down        = [] # status keys whose command failed on the last publish (warned about once)
    end

    def apply_result(result)
        @apply = Status.apply_line(result.status, result.message, @clock.call)
    end

    def publish
        return if @onegate.nil?

        data = Status.to_template(states: status_texts, apply: @apply)
        return if data == @last_sent

        return if @retry_at && @clock.call < @retry_at

        send_data data
    end

    private

    UNAVAILABLE = 'unavailable'

    # { 'BGP_STATE' => 'text', ... }. A status command that fails (its daemon is down) must not hide the other
    # states or FRR_APPLY, which explains why: that state reads `unavailable` instead of going stale.
    def status_texts
        down = []
        texts = @sections.each_with_object({}) do |mod, states|
            status = mod.status
            next if status.nil?

            summary = @reloader.summary(status[:command])
            unless summary.ok
                down << status[:key]
                msg :warn, "FRR: #{status[:key]} unavailable due to failed summary: #{summary.output}" unless @down.include?(status[:key])
            end

            states[status[:key]] = summary.ok ? status[:text].call(summary.output) : UNAVAILABLE
        end
        @down = down
        texts
    end

    # OneGate answers a good PUT with 200 and an empty body; any body is an error.
    # The stock client returns nil (or raises) when the request itself failed: that is no success either.
    def send_data(data)
        response = request(data)

        if response.is_a?(String) && response.strip.empty?
            @last_sent = data
            @retry_at  = nil
            @last_error = nil
        else
            @retry_at = @clock.call + @retry_delay
            warn_once failure_text(response)
        end
    end

    def request(data)
        @onegate.vm_update(data)
    rescue StandardError => e
        e
    end

    def failure_text(response)
        case response
        when nil then 'no answer'
        when StandardError then response.class.to_s
        else response.to_s.strip[0, 200]
        end
    end

    def warn_once(body)
        return if body == @last_error

        @last_error = body
        msg :warn, "FRR: OneGate rejected the status update (#{body}); retrying in #{@retry_delay}s"
    end
end
end
end
