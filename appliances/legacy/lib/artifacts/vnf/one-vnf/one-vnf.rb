#!/usr/bin/env ruby

# -------------------------------------------------------------------------- #
# Copyright 2002-2022, OpenNebula Project, OpenNebula Systems                #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

require 'syslog/logger'
require 'json'
require 'yaml'
require 'getoptlong'
require 'ipaddr'
require 'open3'
require 'socket'
require 'set'
require 'concurrent'

# load appliance plugin framework
require_relative 'lib/appliance'
require_relative 'lib/appliance/plugin'

# defaults
config_file = '/opt/one-appliance/etc/one-vnf-config.js'

begin
    GetoptLong.new(
        ['--config', '-c', GetoptLong::REQUIRED_ARGUMENT],
        ['--help',   '-h', GetoptLong::NO_ARGUMENT]
    ).each do |opt, arg|
        case opt
        when '--config'
            config_file = arg
        when '--help'
            puts <<~EOT
                #{File.basename($PROGRAM_NAME)} [-h|--help]
                #{File.basename($PROGRAM_NAME)} [-c|--config CONFIG_FILE] run
                #{File.basename($PROGRAM_NAME)} [-c|--config CONFIG_FILE] get <plugin>
                #{File.basename($PROGRAM_NAME)} [-c|--config CONFIG_FILE] set <plugin> enabled|disabled
            EOT

            exit(0)
        end
    end
rescue StandardError => e
    STDERR.puts e.to_s
    exit(-1)
end

# default action is run
action = :run

if ARGV.length > 0
    command = ARGV.shift
    case command
    when 'run'
        action = :run
        # continue below
    when 'get'
        action = :get
        app = Appliance.new(config_file, action)

        if ARGV.length != 1
            STDERR.puts 'Missing argument for get'
            exit(-1)
        end

        plugin_name = ARGV.shift.to_s.strip


        if app.get_plugin(plugin_name)
            puts "enabled"
        else
            puts "disabled"
        end

        exit(0)
    when 'set'
        action = :set
        app = Appliance.new(config_file, action)

        if ARGV.length != 2
            STDERR.puts 'Missing argument(s) for set'
            exit(-1)
        end

        plugin_name = ARGV.shift.to_s.strip
        plugin_state = ARGV.shift.to_s.strip.downcase

        case plugin_state
        when 'enabled'
            plugin_state = true
        when 'disabled'
            plugin_state = false
        else
            STDERR.puts "Unknown plugin state: #{plugin_state}"
            exit(-1)
        end

        if app.set_plugin(plugin_name, plugin_state)
            app.save_config
        end

        exit(0)
    else
        STDERR.puts "Unknown argument: #{command}"
        exit(-1)
    end
end

# terminate
exit(0) unless action == :run

#
# regular run below
#

app = Appliance.new(config_file)

# cleanup on exit
at_exit do
    app.cleanup
end

# setup trap on SIGHUP
Signal.trap('HUP') do
    # ignore another HUP until we handle this one
    this_handler = Signal.trap('HUP', 'IGNORE')

    app.reconfigure

    # set the handler back
    Signal.trap('HUP', this_handler)
end

app.run
