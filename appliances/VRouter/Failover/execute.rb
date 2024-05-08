# frozen_string_literal: false

require 'json'

module Service
module Failover
    extend self

    VROUTER_ID = env :VROUTER_ID, nil

    SERVICES = {
        'one-router4' => { _ENABLED: 'ONEAPP_VNF_ROUTER4_ENABLED',
                           fallback: VROUTER_ID.nil? ? 'NO' : 'YES' },

        'one-nat4'    => { _ENABLED: 'ONEAPP_VNF_NAT4_ENABLED',
                           fallback: 'NO' },

        'one-lvs'     => { _ENABLED: 'ONEAPP_VNF_LB_ENABLED',
                           fallback: 'NO' },

        'one-haproxy' => { _ENABLED: 'ONEAPP_VNF_HAPROXY_ENABLED',
                           fallback: 'NO' },

        'one-sdnat4'  => { _ENABLED: 'ONEAPP_VNF_SDNAT4_ENABLED',
                           fallback: 'NO' },

        'one-dns'     => { _ENABLED: 'ONEAPP_VNF_DNS_ENABLED',
                           fallback: 'NO' },

        'one-dhcp4'   => { _ENABLED: 'ONEAPP_VNF_DHCP4_ENABLED',
                           fallback: 'NO' },

        'one-wg'      => { _ENABLED: 'ONEAPP_VNF_WG_ENABLED',
                           fallback: 'NO' }
    }

    FIFO_PATH  = '/run/keepalived/vrrp_notify_fifo.sock'
    STATE_PATH = '/run/one-failover.state'

    STATE_TO_DIRECTION = {
        'BACKUP'  => :down,
        'DELETED' => :down,
        'FAULT'   => :down,
        'MASTER'  => :up,
        'STOP'    => :down,
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
            if STATE_TO_DIRECTION[event[:state]] == STATE_TO_DIRECTION[state[:state]]
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
                        msg :info, task
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

    def execute
        msg :info, 'Failover::execute'
        process_events
    end

    def stay
        msg :debug, :STAY
    end

    def up
        msg :debug, :UP

        load_env

        SERVICES.each do |service, settings|
            enabled = env settings[:_ENABLED], settings[:fallback]

            msg :debug, "#{service}(#{enabled ? ':enabled' : ':disabled'})"

            if enabled
                bash "rc-service #{service} restart ||:", terminate: false
            else
                bash "rc-service #{service} stop ||:" , terminate: false
            end

            sleep 1
        end
    end

    def down
        msg :debug, :DOWN

        SERVICES.each do |service, _|
            msg :debug, "#{service}(:disabled)"

            bash "rc-service #{service} stop ||:", terminate: false

            sleep 1
        end
    end
end
end
