#!/usr/bin/ruby

require 'fileutils'

# Minimal hook template file
class Hook

    attr_accessor :template

    def initialize(name, cmd, type)
        @template = "
NAME      = #{name}
COMMAND   = #{cmd}
TYPE      = #{type}
"
    end

    # Returns the id of the added hook
    def add_to_one
        file = '/tmp/hook.tmpl'

        FileUtils.rm_f(file)

        File.open(file, 'a') {|f| f.write("#{@template}\n") }
        `onehook create #{file}`.split(' ').last
    end

end

class ApiHook < Hook

    def initialize(name, cmd, type, call)
        super(name, cmd, type)

        @template << "CALL    = #{call}"
    end

end
