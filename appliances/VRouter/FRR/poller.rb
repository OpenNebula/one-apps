# frozen_string_literal: true

require 'digest'
require 'json'
require_relative '../vrouter.rb'
require_relative 'attributes'
require_relative 'applier'
require_relative 'scrub'

module Service
module FRR
# Reads the routing overrides (BGP and static routes) from the VM user template (OneGate), merges them
# with the context and hands changes to the Applier.
class Poller
    DEFAULT_INTERVAL = 30
    INTERVAL_RANGE   = (5..3600)
    MAX_BACKOFF      = 600 # seconds between polls while OneGate does not answer
    MAX_WAIT_TICKS   = 19  # ticks skipped between retries of a failed apply (10 minutes at the default interval)
    MAX_TEST_RETRIES = 3   # retries of an apply that `frr-reload.py --test` rejected (it may have been transient)

    def initialize(applier:, onegate:, store:, context:, ha_state:, reporter:, sleeper: ->(seconds) { sleep seconds })
        @applier     = applier
        @onegate     = onegate
        @store       = store
        @context     = Attributes.pick(context)
        @ha_state    = ha_state
        @reporter    = reporter
        @sleeper     = sleeper
        @known       = @store.load
        @interval    = context_interval
        @last_digest = nil
        @retry       = nil # { digest:, attempts:, wait: } of an apply that is tried again later
        @warned      = false
        @failure     = nil
        @offline     = 0 # consecutive ticks without an answer from OneGate
    end

    def run
        loop do
            begin
                tick
            rescue StandardError => e
                msg :error, "Poller::tick failed: #{e.full_message}"
            end
            @sleeper.call sleep_interval
        end
    end

    # The stock OneGate client logs a backtrace per failed request, so back off
    # (doubling up to MAX_BACKOFF, never below the interval) while it fails.
    def sleep_interval
        return @interval if @offline.zero?

        [[@interval * (2**(@offline - 1)), MAX_BACKOFF].min, @interval].max
    end

    def tick
        picked  = overrides
        attrs   = Attributes.merge(@context, picked)
        ignored = (picked.keys & Attributes.boot_only_keys).sort
        ha      = @ha_state.call
        digest  = Digest::SHA256.hexdigest(JSON.generate([attrs.sort, ha, ignored]))

        status = if digest == @last_digest then :unchanged
                 elsif waiting?(digest) then :waiting
                 else apply(attrs, ha, digest, ignored)
                 end
        @reporter.publish if @offline.zero? # one failing OneGate request per tick is enough
        status
    end

    private

    def apply(attrs, ha, digest, ignored)
        result = note_ignored(call_applier(attrs, ha), ignored)
        @interval = result.config.poll_interval if usable_config?(result)
        settle(digest, result)
        @reporter.apply_result(result)
        msg :info, "Poller: #{result.status} #{result.message}".strip

        result.status
    end

    # FRR_APPLY names the boot-only keys of the user template that were dropped (never their values).
    def note_ignored(result, ignored)
        return result if ignored.empty?

        note = "ignored boot-only #{ignored.join(', ')} in the user template (set it in the VM context)"
        Applier::Result.new(status: result.status, message: [result.message, note].reject(&:empty?).join('; '), config: result.config)
    end

    # A failed apply, and a config that frr-reload --test rejected (not one that failed validation, which
    # cannot change by itself), are tried again after a growing number of ticks; a changed digest starts afresh.
    def settle(digest, result)
        attempts = @retry && @retry[:digest] == digest ? @retry[:attempts] + 1 : 1
        retry_it = result.status == :failed || (result.status == :rejected && !result.config.nil? && attempts <= MAX_TEST_RETRIES)

        if retry_it
            @retry = { digest: digest, attempts: attempts, wait: [2**attempts - 1, MAX_WAIT_TICKS].min }
        else
            @retry       = nil
            @last_digest = digest
        end
    end

    def waiting?(digest)
        return false unless @retry && @retry[:digest] == digest && @retry[:wait].positive?

        @retry = @retry.merge(wait: @retry[:wait] - 1)
        true
    end

    # A rejected or failed apply keeps the interval in use.
    def usable_config?(result)
        !result.config.nil? && !%i[failed rejected].include?(result.status)
    end

    # The baseline from the context, read tolerantly: the Config parser reports a bad value when it applies.
    def context_interval
        Integer(@context["#{Attributes::PREFIX}POLL_INTERVAL"], 10).then do |value|
            INTERVAL_RANGE.cover?(value) ? value : DEFAULT_INTERVAL
        end
    rescue ArgumentError, TypeError
        DEFAULT_INTERVAL
    end

    # An apply must never escape the tick unreported: it becomes a failed result.
    def call_applier(attrs, ha)
        @applier.call(attrs, ha_state: ha)
    rescue StandardError => e
        Applier::Result.new(status: :failed, message: Scrub.text("apply raised #{e.class}: #{e.message}"), config: nil)
    end

    # User-template overrides; the last known ones when OneGate does not answer.
    def overrides
        template = fetch_template
        return fall_back if template.nil?

        @warned  = false
        @offline = 0
        picked   = Attributes.pick(template)
        unless picked == @known
            warn_boot_only picked
            remember picked
        end
        @known = picked
    end

    # The user template cannot change them (Attributes.merge drops them): say so once per change, names only.
    def warn_boot_only(picked)
        ignored = picked.keys & Attributes.boot_only_keys
        msg :warn, "Poller: ignoring boot-only #{ignored.join(', ')} in the user template (set it in the VM context)" unless ignored.empty?
    end

    # The stock client may raise (IOError when the connection could not be opened): same as no answer.
    def fetch_template
        @failure = nil
        @onegate&.vm_show&.dig('VM', 'USER_TEMPLATE')
    rescue StandardError => e
        @failure = e.class
        nil
    end

    # Losing the copy on disk only matters after a reboot; keep applying.
    def remember(picked)
        @store.save(picked)
    rescue SystemCallError => e
        msg :warn, "Poller: cannot remember the overrides on disk: #{e.class}"
    end

    def fall_back
        return @known if @onegate.nil?

        @offline = [@offline + 1, 32].min # enough to reach any cap, keeps the number small
        unless @warned
            cause = @failure ? " (#{@failure})" : ''
            msg :warn, "Poller: OneGate did not answer#{cause}, using the last known overrides"
            @warned = true
        end

        @known
    end
end
end
end
