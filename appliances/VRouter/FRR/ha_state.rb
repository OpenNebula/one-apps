# frozen_string_literal: true

require 'fileutils'

module Service
module FRR
module HaState
    extend self

    PATH   = '/run/one-frr/ha-state'
    STATES = %i[master backup].freeze

    def read(path = PATH)
        File.read(path).strip == 'backup' ? :backup : :master
    rescue SystemCallError # missing (the default at boot), unreadable, a directory: never break the poller
        :master
    end

    def write(state, path = PATH)
        raise ArgumentError, "state must be one of #{STATES.inspect}" unless STATES.include?(state)

        FileUtils.mkdir_p File.dirname(path)

        tmp = "#{path}.#{Process.pid}.tmp"
        begin
            File.write tmp, state.to_s
            File.rename tmp, path # atomic: readers never see a truncated file
        rescue StandardError
            FileUtils.rm_f tmp
            raise
        end
    end
end
end
end
