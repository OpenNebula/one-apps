# frozen_string_literal: true

require 'fileutils'
require 'json'
require_relative '../vrouter.rb'
require_relative 'secure_file'

module Service
module FRR
# Remembers the last overrides read from the VM user template, so a reboot or
# an unreachable OneGate does not drop them.
class OverrideStore
    def initialize(path)
        @path = path
    end

    # Never raises: a missing, unreadable, corrupt or non-object file counts as
    # no overrides. Only the error class is logged (the file holds passwords).
    def load
        data = JSON.parse(File.read(@path))
        return data if data.is_a?(Hash)

        msg :warn, "OverrideStore: ignoring #{@path}: not a JSON object"
        {}
    rescue Errno::ENOENT
        {}
    rescue JSON::ParserError, SystemCallError => e
        msg :warn, "OverrideStore: ignoring unreadable #{@path}: #{e.class}"
        {}
    end

    def save(overrides)
        SecureFile.write @path, JSON.generate(overrides)
    end
end
end
end
