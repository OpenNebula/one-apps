# frozen_string_literal: true

require 'socket'
require_relative '../vrouter.rb'
require_relative 'attributes'
require_relative 'config'
require_relative 'renderer'
require_relative 'reloader'
require_relative 'reporter'
require_relative 'override_store'
require_relative 'applier'
require_relative 'poller'
require_relative 'ha_state'
require_relative 'secure_file'
require_relative 'sections'

module Service
module FRR
    extend self

    # FRR has to keep its BGP sessions on the standby node, so it neither
    # depends on Failover nor is listed in Failover::SERVICES.
    DEPENDS_ON = %w[]

    STATE_DIR = '/var/lib/one-frr'
    LOCK_PATH = '/run/one-frr/apply.lock'
    RC_LOG    = '/var/log/one-appliance/frr-rc.log'

    # Boot-only keys come from the context alone, never from stored overrides.
    BOOT_ONLY_KEYS = Attributes.boot_only_keys.freeze

    # FRR runs when a section is configured in the context: BGP enabled, or ONEAPP_VNF_STATIC_ROUTES
    # set (NONE counts: it is the way to start with no routes and add them live).
    def active?
        Sections::ALL.any? { |section| section.in_context?(ENV) }
    end

    def install(initdir: '/etc/init.d', hooks_dir: '/etc/one-appliance/ha-hooks.d', daemons: '/etc/frr/daemons')
        msg :info, 'FRR::install'

        puts bash 'apk --no-cache add frr frr-pythontools ruby'

        enable_daemons daemons
        file "#{initdir}/one-frr-poller", poller_service, mode: 'u=rwx,go=rx', overwrite: true
        file "#{hooks_dir}/10-frr", hook_script, mode: 'u=rwx,go=rx', overwrite: true

        toggle_poller [:disable, :update]
    end

    def configure(conf_dir: '/etc/frr', state_dir: STATE_DIR, owner: 'frr', group: 'frr')
        msg :info, 'FRR::configure'

        unless active?
            toggle %i[stop disable]
            toggle_poller %i[stop disable]
            return
        end

        write_conf = ->(content) { file "#{conf_dir}/frr.conf", content, mode: 'u=rw,g=r,o=', owner: owner, group: group, overwrite: true }

        configure_frr write_conf, state_dir
    end

    def bootstrap
        msg :info, 'FRR::bootstrap'

        return unless active?

        if ENV['ONEGATE_ENDPOINT'].to_s.empty?
            msg :warn, 'FRR::bootstrap: no ONEGATE_ENDPOINT, routing changes at runtime are disabled (context only)'
            return
        end

        start_poller
    end

    # Like configure, bootstrap must not raise: service.rb stops at the first error, and the modules after FRR
    # (Keepalived, Failover, NAT4, Router4, ...) would never be bootstrapped. The router then still runs with
    # the config from the context; only the changes through OneGate wait until the poller runs.
    def start_poller
        toggle_poller %i[enable restart]
    rescue StandardError => e
        msg :error, "FRR::bootstrap: the poller did not start (#{e.class}); runtime changes are disabled until it runs, " \
                    "see #{RC_LOG} and the one-frr-poller logs in #{File.dirname(RC_LOG)}"
    end

    # Entry point of the one-frr-poller OpenRC service.
    def poll
        load_env if File.exist?('/run/one-context/one_env')

        build_poller.run
    end

    # Called by /etc/one-appliance/ha-hooks.d/10-frr with "up" or "down".
    def ha_transition(direction)
        state = { 'up' => :master, 'down' => :backup }.fetch(direction) do
            raise ArgumentError, "unknown HA direction #{direction.inspect}"
        end

        HaState.write state
        return unless active?

        begin
            load_env if File.exist?('/run/one-context/one_env')
            # Offline: the hook must stay fast, so no OneGate fetch or publish.
            # The poller service converges and publishes on its next tick, as
            # its digest includes the HA state.
            build_poller(online: false).tick
        rescue StandardError => e
            # The failover hook must not fail; the poller converges on its next tick.
            msg :error, "FRR::ha_transition: apply after #{direction} failed: #{e.message}"
        end
    end

    # bfdd belongs to the core (more than one protocol can use BFD); the sections add their own daemons.
    def enable_daemons(path)
        names   = (['bfdd'] + Sections::ALL.flat_map(&:daemons)).uniq
        content = File.read(path).gsub(/^(#{names.join('|')})=no$/, '\1=yes')
        file path, content, mode: 'u=rw,go=r', overwrite: true
    end

    def poller_service
        <<~SERVICE
            #!/sbin/openrc-run
            source /run/one-context/one_env

            command="/usr/bin/ruby"
            command_args="-r /etc/one-appliance/lib/helpers.rb -r #{__FILE__} -e Service::FRR.poll"

            command_background="YES"
            pidfile="/run/$RC_SVCNAME.pid"

            # The poller keeps no state a kill could damage (an interrupted reload is planned again by the next apply).
            retry="TERM/10/KILL/5"

            output_log="/var/log/one-appliance/one-frr-poller.log"
            error_log="/var/log/one-appliance/one-frr-poller.err"

            depend() {
                need frr
                after net
            }
        SERVICE
    end

    def hook_script
        <<~HOOK
            #!/bin/sh
            # Called by one-failover with "up" (MASTER) or "down" (BACKUP).
            [ -r /run/one-context/one_env ] && . /run/one-context/one_env
            exec /usr/bin/ruby -r /etc/one-appliance/lib/helpers.rb -r #{__FILE__} -e 'Service::FRR.ha_transition(ARGV[0])' "$1"
        HOOK
    end

    def toggle(operations)
        toggle_service 'frr', operations, 'FRR::toggle'
    end

    def toggle_poller(operations)
        toggle_service 'one-frr-poller', operations, 'FRR::toggle_poller'
    end

    private

    def toggle_service(name, operations, label)
        operations.each do |op|
            msg :info, "#{label}([:#{op}])"
            case op
            when :enable  then puts bash "rc-update add #{name} default"
            when :disable then puts bash "rc-update del #{name} default ||:"
            when :update  then puts bash 'rc-update -u'
            when :stop    then puts bash "#{rc_service name, op} ||:"
            else puts bash rc_service(name, op)
            end
        end
    end

    # The only place that runs rc-service. Daemons it starts (watchfrr) inherit
    # the std streams, and the bash helper waits for EOF on its capture pipes,
    # so all three streams are redirected away from them.
    def rc_service(name, op)
        "mkdir -p #{File.dirname RC_LOG}; rc-service #{name} #{op} #{rc_redirect}"
    end

    def rc_redirect
        "</dev/null >>#{RC_LOG} 2>&1"
    end

    # FRR is configured first of all modules and service.rb re-raises any error,
    # so nothing may escape from here: an exception would leave the appliance
    # without VRRP, forwarding and NAT. Only error classes and validation
    # messages are logged, never attribute values.
    def configure_frr(write_conf, state_dir)
        secure_state_dir state_dir
        rendered = write_boot_config write_conf, state_dir
        enable_frr
        record_last_good state_dir, rendered if start_frr(write_conf) && rendered
    rescue StandardError => e
        msg :error, "FRR::configure: unexpected #{e.class}: #{e.message}"
        write_minimal write_conf
    end

    # The state files hold passwords: the directory must be private.
    def secure_state_dir(state_dir)
        SecureFile.secure_dir state_dir
    rescue SystemCallError => e
        msg :error, "FRR::configure: cannot make #{state_dir} private: #{e.class}"
    end

    # The rendered config when it was written (not a fallback), else nil.
    def write_boot_config(write_conf, state_dir)
        content, rendered = boot_config(state_dir)
        write_conf.call content
        rendered ? content : nil
    rescue StandardError => e
        msg :error, "FRR::configure: cannot build frr.conf (#{e.class}: #{e.message}); starting FRR without routing protocols"
        write_minimal write_conf
        nil
    end

    # What FRR accepted at boot is what a failed first apply must roll back to.
    def record_last_good(state_dir, content)
        SecureFile.write File.join(state_dir, 'last-good.conf'), content
    rescue SystemCallError => e
        msg :error, "FRR::configure: cannot record last-good in #{state_dir}: #{e.class}"
    end

    def write_minimal(write_conf)
        write_conf.call minimal_config
    rescue StandardError => e
        msg :error, "FRR::configure: cannot write the minimal frr.conf: #{e.class}: #{e.message}"
    end

    def enable_frr
        toggle [:enable]
    rescue StandardError => e
        msg :error, "FRR::configure: enabling frr failed (#{e.class}: #{e.message}); restarting it anyway"
    end

    # The frr.conf FRR starts with: context + remembered overrides (minus the
    # boot-only keys). Invalid attributes must not break the boot, so fall back
    # to last-good.conf, else to a config without routing protocols. Only the validation
    # messages are logged (they never carry secret values).
    def boot_config(state_dir)
        stored = OverrideStore.new(File.join(state_dir, 'overrides.json')).load.except(*BOOT_ONLY_KEYS)
        attrs  = Attributes.merge(ENV.to_h, stored)
        config = Config.parse_frr(attrs, default_router_id: Config.default_router_id(ENV.to_h))

        Sections.pinned?(config) ? write_pin(state_dir, config) : clear_pin(state_dir)
        [Renderer.render(config, hostname: Socket.gethostname, ha_state: HaState.read), true]
    rescue ConfigError => e
        clear_pin state_dir
        [fallback_config(state_dir, e.message), false]
    end

    def fallback_config(state_dir, reason)
        last_good = File.join(state_dir, 'last-good.conf')

        if File.size?(last_good)
            msg :error, "FRR::configure: #{reason}; starting FRR with #{last_good}"
            File.read(last_good)
        else
            msg :error, "FRR::configure: #{reason}; starting FRR without routing protocols"
            minimal_config
        end
    end

    # Without any section; the hostname line is left out when the hostname is unusable.
    def minimal_config = Renderer.header(hostname: safe_hostname)

    def safe_hostname
        hostname = Socket.gethostname
        hostname.match?(Renderer::HOSTNAME_FORMAT) ? hostname : nil
    rescue StandardError
        nil
    end

    # The pin is secondary to rendering: failing to write it must not fail the boot.
    def write_pin(state_dir, config)
        Applier.write_pin state_dir, config
    rescue SystemCallError => e
        msg :error, "FRR::configure: cannot write the boot pin in #{state_dir}: #{e.class}"
    end

    # A pin from an earlier boot must not force a stale ASN/router-id on the next apply.
    def clear_pin(state_dir)
        FileUtils.rm_f File.join(state_dir, 'boot.json')
    rescue SystemCallError => e
        msg :error, "FRR::configure: cannot remove the stale boot pin in #{state_dir}: #{e.class}"
    end

    # A config frr rejects must not leave the router down: retry once with no routing protocols.
    # true when the configured config started.
    def start_frr(write_conf)
        toggle [:restart]
        true
    rescue StandardError => e
        msg :error, "FRR::configure: frr restart failed (#{e.message}); retrying without routing protocols"
        begin
            write_conf.call minimal_config
            toggle [:restart]
        rescue StandardError => retry_error
            msg :error, "FRR::configure: frr restart without routing protocols failed too: #{retry_error.message}"
        end
        false
    end

    # What FRR loads when a daemon restarts: the config of the last successful apply (same mode as at boot).
    def write_frr_conf(content, conf_dir: '/etc/frr', owner: 'frr', group: 'frr')
        file "#{conf_dir}/frr.conf", content, mode: 'u=rw,g=r,o=', owner: owner, group: group, overwrite: true
    end

    # online: false uses the stored overrides and the context only.
    def build_poller(online: true)
        reloader = Reloader.new
        onegate  = online && !ENV['ONEGATE_ENDPOINT'].to_s.empty? ? OneGate.instance : nil
        applier  = Applier.new(reloader: reloader, dir: STATE_DIR, hostname: Socket.gethostname,
                               default_router_id: Config.default_router_id(ENV.to_h), lock_path: LOCK_PATH,
                               conf_writer: method(:write_frr_conf))

        Poller.new(applier: applier, onegate: onegate, store: OverrideStore.new(File.join(STATE_DIR, 'overrides.json')),
                   context: ENV.to_h, ha_state: -> { HaState.read },
                   reporter: Reporter.new(onegate: onegate, reloader: reloader,
                                          sections: Sections::ALL.select { |section| section.in_context?(ENV) }))
    end
end
end
