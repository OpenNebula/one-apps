# frozen_string_literal: false

require 'json'
require 'tempfile'

module Service
module Failover
    extend self

    VROUTER_ID = env :VROUTER_ID, nil

    SERVICES = {
        'one-router4' => { _ENABLED: 'ONEAPP_VNF_ROUTER4_ENABLED', fallback: VROUTER_ID.nil? ? 'NO' : 'YES' },

        'one-nat4'    => { _ENABLED: 'ONEAPP_VNF_NAT4_ENABLED' },

        'one-lvs'     => { _ENABLED: 'ONEAPP_VNF_LB_ENABLED' },

        'one-haproxy' => { _ENABLED: 'ONEAPP_VNF_HAPROXY_ENABLED' },
        'haproxy'     => { _ENABLED: 'ONEAPP_VNF_HAPROXY_ENABLED', dependency: true },

        'one-sdnat4'  => { _ENABLED: 'ONEAPP_VNF_SDNAT4_ENABLED' },

        'one-dns'     => { _ENABLED: 'ONEAPP_VNF_DNS_ENABLED' },
        'unbound'     => { _ENABLED: 'ONEAPP_VNF_DNS_ENABLED', dependency: true },

        'one-dhcp4v2' => { _ENABLED: 'ONEAPP_VNF_DHCP4_ENABLED' },
        'coredhcp'    => { _ENABLED: 'ONEAPP_VNF_DHCP4_ENABLED', dependency: true },

        'one-wg'      => { _ENABLED: 'ONEAPP_VNF_WG_ENABLED' }
    }

    FIFO_PATH  = '/run/keepalived/vrrp_notify_fifo.sock'
    STATE_PATH = '/run/one-failover.state'
    HOOKS_DIR  = '/etc/one-appliance/ha-hooks.d'
    HOOK_TIMEOUT = 30
    HOOK_LOG_TAIL = 4096

    STATE_TO_DIRECTION = {
        'BACKUP'  => :down,
        'DELETED' => :stay,
        'FAULT'   => :stay,
        'MASTER'  => :up,
        'STOP'    => :stay,
        nil       => :stay
    }

    def to_event(line)
        k = [:type, :name, :state, :priority]
        v = line.strip.split.map(&:strip).map{|s| s.delete_prefix('"').delete_suffix('"')}
        k.zip(v).to_h
    end

    def to_task(event)
        event[:state].upcase!

        state = load_state
        state[:state].upcase!

        if event[:type] != 'GROUP'
            direction = :stay
            ignored   = true
        else
            case
            when event[:state] == 'BACKUP'
                direction = STATE_TO_DIRECTION['BACKUP']
                ignored   = false
            when STATE_TO_DIRECTION[event[:state]] == STATE_TO_DIRECTION[state[:state]]
                direction = :stay
                ignored   = false
            else
                direction = STATE_TO_DIRECTION[event[:state]]
                ignored   = false
            end
            save_state event[:state]
        end

        { event: event, from: state[:state], to: event[:state], direction: direction, ignored: ignored }
    end

    def save_state(state, state_path = STATE_PATH)
        content = JSON.fast_generate({ state: state })
        File.open state_path, File::CREAT | File::TRUNC | File::WRONLY do |f|
            f.flock File::LOCK_EX
            f.write content
        end
    end

    def load_state(state_path = STATE_PATH)
        content = File.open state_path, File::RDONLY do |f|
            f.flock File::LOCK_EX
            f.read
        end
        JSON.parse content, symbolize_names: true
    rescue Errno::ENOENT
        { state: 'UNKNOWN' }
    end

    def process_events(fifo_path = FIFO_PATH)
        loop do
            begin
                File.open fifo_path, File::RDONLY do |f|
                    f.each do |line|
                        event = to_event line
                        task = to_task event
                        msg :debug, task
                        method(task[:direction]).call
                    end
                end
            rescue StandardError => e
                msg :error, e.full_message
                # NOTE: We always disable all services on fatal errors
                #       to avoid any potential conflicts.
                down
                next
            ensure
                sleep 1
            end
        end
    end

    def wait_ready(role = :master)
        # Give one-context 30 seconds to fully start..
        6.times do
            bash 'rc-service one-context status', terminate: false
            break
        rescue RuntimeError => e
            msg :error, e.full_message
            sleep 5
        end.then do |result|
            msg :error, 'one-context not ready!' unless result.nil?
        end
        # Give keepalived 30 seconds to fully start..
        6.times do
            bash "rc-service keepalived #{role == :master ? 'ready' : 'standby'}", terminate: false
            break
        rescue RuntimeError => e
            msg :error, e.full_message
            sleep 5
        end.then do |result|
            msg :error, 'keepalived not ready!' unless result.nil?
        end
    end

    def execute
        msg :info, 'Failover::execute'
        process_events
    end

    # Runs /etc/one-appliance/ha-hooks.d/* with "up" (MASTER) or "down" (BACKUP).
    # Hooks must never break the failover itself, so every failure is only logged.
    # Each hook runs synchronously but bounded: output goes to a file (not a pipe,
    # so leftover children cannot block us) and a hook past the timeout is killed
    # together with its whole process group.
    def run_hooks(direction, dir: HOOKS_DIR, timeout: HOOK_TIMEOUT)
        Dir.glob(File.join(dir, '*')).sort.each do |hook|
            next unless File.file?(hook) && File.executable?(hook)

            run_hook hook, direction, timeout
        end
    end

    def run_hook(hook, direction, timeout)
        Tempfile.create('one-ha-hook') do |out|
            pid = Process.spawn hook, direction.to_s, pgroup: true, [:out, :err] => out
            status = wait_hook pid, Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

            if status.nil?
                msg :error, "hook #{hook} #{direction} timed out after #{timeout}s, killed"
            elsif !status.success?
                msg :error, "hook #{hook} #{direction} failed (#{status.exitstatus || status}): #{hook_output out}"
            end
        end
    rescue StandardError => e
        msg :error, "hook #{hook} #{direction} raised: #{e.message}"
    end

    # Returns the exit status, or nil after killing the process group on timeout.
    def wait_hook(pid, deadline)
        loop do
            _, status = Process.wait2 pid, Process::WNOHANG
            return status if status
            break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

            sleep 0.05
        end
        begin
            Process.kill 'KILL', -pid
        rescue Errno::ESRCH, Errno::EPERM
            nil
        end
        Process.wait pid
        nil
    end

    def hook_output(file)
        file.flush
        file.seek [file.size - HOOK_LOG_TAIL, 0].max
        file.read.to_s
    end

    def stay
        msg :debug, ":STAY (pid = #{Process.pid})"
    end

    def up
        msg :debug, ":UP (pid = #{Process.pid})"

        wait_ready :master

        load_env

        SERVICES.each do |service, settings|
            if env settings[:_ENABLED], (settings[:fallback] || 'NO')
                next if settings[:dependency]

                msg :info, "#{service}(:enabled)"

                puts bash "rc-service #{service} restart ||:", terminate: false
            else
                msg :info, "#{service}(:disabled)"

                puts bash "rc-service #{service} stop ||:", terminate: false
            end
        end

        puts bash 'rc-update -v -u ||:', terminate: false

        run_hooks :up # after the stock services: forwarding must not wait for hooks
    end

    def down
        msg :debug, ":DOWN (pid = #{Process.pid})"

        run_hooks :down

        wait_ready :standby

        12.times do |attempt|
            services = bash 'rc-status --nocolor --format ini --servicelist', terminate: false

            stopped = services.lines.map(&:split)
                                    .select { |_, _, s| s == 'stopped' }
                                    .map(&:first)

            break if (running = SERVICES.keys - stopped).empty?

            running.each do |service|
                msg :info, "#{service}(:disabled)"

                puts bash "rc-service #{service} stop ||:", terminate: false
            end

            puts bash 'rc-update -v -u ||:', terminate: false
        rescue RuntimeError => e
            msg :error, e.full_message
            sleep 5
        end.then do |result|
            msg :error, 'could not stop services!' unless result.nil?
        end
    end
end
end
