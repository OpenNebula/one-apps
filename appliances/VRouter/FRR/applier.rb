# frozen_string_literal: true

require 'fileutils'
require 'json'
require_relative '../vrouter.rb'
require_relative 'config'
require_relative 'sections'
require_relative 'renderer'
require_relative 'reloader'
require_relative 'scrub'
require_relative 'secure_file'

module Service
module FRR
# parse -> render -> frr-reload --test -> frr-reload --reload -> last-good,
# with rollback and the boot-only pin for the local ASN and router-id.
class Applier
    Result = Data.define(:status, :message, :config)

    LOCK_TIMEOUT   = 60 # seconds; never wait forever behind a wedged apply
    LOCK_RETRY     = 0.1
    BOOT_ONLY_HINT = 'boot-only: set in the VM context, then re-context or reboot'

    def self.write_pin(dir, config)
        values = Sections.active(config).map { |mod, cfg| mod.pin_values(cfg) }.reduce({}, :merge)
        atomic_write File.join(dir, 'boot.json'), JSON.generate(values)
    end

    # Atomic and private (0600 in a 0700 directory): the files hold passwords.
    def self.atomic_write(path, content)
        SecureFile.write path, content
    end

    # `conf_writer` (optional) receives the config after every successful apply, so that /etc/frr/frr.conf
    # (what FRR loads when a daemon restarts) keeps the live changes.
    def initialize(reloader:, dir:, hostname:, default_router_id:, lock_path:, lock_timeout: LOCK_TIMEOUT, conf_writer: nil)
        @conf_writer       = conf_writer
        @reloader          = reloader
        @dir               = dir
        @hostname          = hostname
        @default_router_id = default_router_id
        @lock_path         = lock_path
        @lock_timeout      = lock_timeout
    end

    # `attrs` are the module's attributes only, as Attributes.merge/pick returns them: a section looks
    # at the keys under its own prefix and does not reject keys that belong to other modules.
    def call(attrs, ha_state: :master)
        with_lock { apply(attrs, ha_state) }
    end

    private

    def apply(attrs, ha_state)
        config, warnings = pin_boot_only(Config.parse_frr(attrs, default_router_id: @default_router_id))
        content, refused = render(config, ha_state)
        return refused if refused

        persisted = persist_candidate(config, content)
        return persisted if persisted

        checked = @reloader.test(candidate_path)
        return result(:rejected, "frr-reload --test failed: #{checked.output}", config) unless checked.ok

        applied = @reloader.reload(candidate_path)
        return rollback(applied, config) unless applied.ok

        keep_last_good(config) || begin
            warnings << conf_warning(File.read(candidate_path)) if @conf_writer
            commands = Sections.active(config).flat_map { |mod, cfg| mod.soft_refresh_commands(cfg) }
            @reloader.soft_refresh(commands) unless commands.empty?
            result(:applied, warnings.compact.join('; '), config)
        end
    rescue ConfigError => e
        result(:rejected, e.message, nil) # scrubbed like every message that leaves the router
    end

    # The renderer refuses an unsafe hostname or HA state; report it, never raise.
    def render(config, ha_state)
        [Renderer.render(config, hostname: @hostname, ha_state: ha_state), nil]
    rescue ArgumentError => e
        [nil, result(:failed, "could not render the config: #{e.message}", config)]
    end

    def persist_candidate(config, content)
        self.class.atomic_write candidate_path, content
        nil
    rescue SystemCallError => e
        result(:failed, "could not write candidate config: #{e.message}", config)
    end

    # The reload already succeeded: record last-good, and pin boot-only values if not yet pinned.
    def keep_last_good(config)
        self.class.atomic_write last_good_path, File.read(candidate_path)
        pin_boot_values(config) if Sections.pinned?(config)
        nil
    rescue SystemCallError => e
        result(:failed, "could not write last-good config: #{e.message}", config)
    end

    # The running config is right either way: a frr.conf that could not be written is reported, not failed.
    def conf_warning(content)
        @conf_writer.call(content)
        nil
    rescue StandardError => e
        "could not update frr.conf (#{e.class}): a restart of FRR would load the previous config"
    end

    # Pins what is not pinned yet: all of it on the first apply, only the missing keys after that (a pin file
    # from a boot that did not run a section that runs now). A value that is pinned stays.
    def pin_boot_values(config)
        wanted = Sections.active(config).map { |mod, cfg| mod.pin_values(cfg) }.reduce({}, :merge)
        pin    = load_pin
        return self.class.write_pin(@dir, config) if pin.nil?
        return if (wanted.keys - pin.keys).empty?

        self.class.atomic_write File.join(@dir, 'boot.json'), JSON.generate(wanted.merge(pin))
    end

    def rollback(failed, config)
        note = if !File.exist?(last_good_path)
                   'no last-good config to restore'
               elsif @reloader.reload(last_good_path).ok
                   'last-good config restored'
               else
                   'restore of last-good ALSO failed, router may be running an inconsistent config'
               end

        result(:failed, "frr-reload failed (#{note}): #{failed.output}", config)
    end

    # Messages leave the router (FRR_APPLY) and reach the poller log. frr-reload
    # output can carry the previous passwords too (e.g. `no neighbor X password
    # OLD`), so scrub any password value plus the secrets of the new config and
    # of last-good.
    def result(status, message, config)
        secrets = config.nil? ? [] : Sections.active(config).flat_map { |mod, cfg| mod.secrets(cfg) }

        Result.new(status: status, message: Scrub.text(message, secrets + last_good_secrets), config: config)
    end

    def last_good_secrets
        Scrub.secrets_in(File.read(last_good_path))
    rescue SystemCallError
        []
    end

    # Pure: later changes of the boot-only values are ignored once a pin exists.
    # `configure` writes the pin at boot, from the boot config; the poller completes it after a successful reload
    # (all of it when there is none, the missing keys otherwise).
    def pin_boot_only(config)
        sections = Sections.active(config).select { |mod, cfg| mod.pin_values(cfg).any? }
        pin      = sections.empty? ? nil : load_pin
        return [config, []] if pin.nil?

        sections.reduce([config, []]) do |(current, notes), (mod, cfg)|
            # Only the keys the pin file has count: a key it lacks was not pinned.
            ignored = mod.pin_values(cfg).select { |key, value| pin.key?(key) && pin[key] != value }.keys
            next [current, notes] if ignored.empty?

            [mod.pinned(current, pin), notes + ["ignored runtime change of #{ignored.join(', ')} (#{BOOT_ONLY_HINT})"]]
        end
    end

    def load_pin
        pin = JSON.parse(File.read(File.join(@dir, 'boot.json')))
        return pin if pin.is_a?(Hash)

        msg :warn, 'Applier: ignoring boot.json that is not an object'
        nil
    rescue Errno::ENOENT
        nil
    rescue JSON::ParserError => e
        msg :warn, "Applier: ignoring corrupt boot.json: #{e.message}"
        nil
    end

    def with_lock
        FileUtils.mkdir_p File.dirname(@lock_path)
        File.open(@lock_path, File::CREAT | File::RDWR) do |lock|
            next yield if acquire(lock)

            result(:failed, "could not acquire the apply lock within #{@lock_timeout} s", nil)
        end
    end

    def acquire(lock)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @lock_timeout
        loop do
            return true if lock.flock(File::LOCK_EX | File::LOCK_NB)
            return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

            sleep LOCK_RETRY
        end
    end

    def candidate_path = File.join(@dir, 'candidate.conf')

    def last_good_path = File.join(@dir, 'last-good.conf')
end
end
end
