#!/bin/env ruby

require 'pp'
require 'fileutils'

ONE_LOCATION = ENV['ONE_LOCATION']

if !ONE_LOCATION
    GEMS_LOCATION     = '/usr/share/one/gems'
    RUBY_LIB_LOCATION = '/usr/lib/one/ruby'
    VAR_LOCATION = '/var/lib/one'
    LIB_LOCATION = '/usr/lib/one'
    ETC_LOCATION = '/etc/one'
else
    GEMS_LOCATION     = ONE_LOCATION + '/share/gems'
    RUBY_LIB_LOCATION = ONE_LOCATION + '/lib/ruby'
    VAR_LOCATION = ONE_LOCATION + '/var'
    LIB_LOCATION = ONE_LOCATION + '/lib'
    ETC_LOCATION = ONE_LOCATION + '/etc'
end

# %%RUBYGEMS_SETUP_BEGIN%%
if File.directory?(GEMS_LOCATION)
    real_gems_path = File.realpath(GEMS_LOCATION)
    if !defined?(Gem) || Gem.path != [real_gems_path]
        $LOAD_PATH.reject! {|l| l =~ /vendor_ruby/ }

        # Suppress warnings from Rubygems
        # https://github.com/OpenNebula/one/issues/5379
        begin
            verb = $VERBOSE
            $VERBOSE = nil
            require 'rubygems'
            Gem.use_paths(real_gems_path)
        ensure
            $VERBOSE = verb
        end
    end
end
# %%RUBYGEMS_SETUP_END%%

$LOAD_PATH << RUBY_LIB_LOCATION

require 'yaml'
require 'erb'
require 'tempfile'
require 'fileutils'
require 'json'
require 'optparse'
require_relative 'log'

options = {}
DEFAULTS = {
    :vminfo => 3, :vmpoolinfo => 3, :hostinfo => 3, :hostpoolinfo => 1, :zoneraftstatus => 3,
    :credentials => 'oneadmin:opennebula', :xmlrpc => true
}
DESCRIPTION = {
    :vm => "vm.info requests/s, defaults to #{DEFAULTS[:vminfo]}",
    :vmpool => "vm.pool.info requests/s, defaults to #{DEFAULTS[:vmpoolinfo]}",
    :host => "host.info requests/s, defaults to #{DEFAULTS[:hostinfo]}",
    :hostpool => "host.pool.info requests/s, defaults to #{DEFAULTS[:hostpoolinfo]}",
    :zoneraftstatus => "zone.raftstatus requests/s, defaults to #{DEFAULTS[:zoneraftstatus]}",
    :logs => 'Logs folder path. If not specified logs will be printed on STDOUT',
    :credentials => "Credentials in the form: user:password, defaults to #{DEFAULTS[:credentials]}"
}

ARGV.options do |opts|
    script_name = File.basename($PROGRAM_NAME)
    opts.banner = 'OpenNebula benchmarking tool'
    opts.define_head("Usage: #{script_name} [OPTIONS]",
                     'Example', "#{script_name} -c oneadmin:oneadmin")
    opts.separator('')
    opts.on('-v', '--vminfo STR', String, DESCRIPTION[:vm]) {|v| options[:vminfo] = v }
    opts.on('-V', '--vmpoolinfo STR', String, DESCRIPTION[:vmpool]) {|v| options[:vmpoolinfo] = v }
    opts.on('-o', '--hostinfo STR', String, DESCRIPTION[:host]) {|v| options[:hostinfo] = v }
    opts.on('-O', '--hostpoolinfo STR', String, DESCRIPTION[:hostpool]) {|v| options[:hostpoolinfo] = v }
    opts.on('-z', '--zoneraftstatus STR', String, DESCRIPTION[:zoneraftstatus]) {|v| options[:zoneraftstatus] = v }
    opts.on('-l', '--logs STR', String, DESCRIPTION[:logs]) {|v| options[:logs] = v }
    opts.on('-c', '--credentials STR', String, DESCRIPTION[:credentials]) {|v| options[:credentials] = v }
    opts.on('--cli') { options[:xmlrpc] = false }
    opts.separator('')
    opts.on_tail('-h', '--help', 'Show this help message.') do
        puts(opts)
        exit(0)
    end
    opts.parse!
end

# Defaults
options[:vminfo] ||= DEFAULTS[:vminfo]
options[:vmpoolinfo] ||= DEFAULTS[:vmpoolinfo]
options[:hostinfo] ||= DEFAULTS[:hostinfo]
options[:hostpoolinfo] ||= DEFAULTS[:hostpoolinfo]
options[:zoneraftstatus] ||= DEFAULTS[:zoneraftstatus]
options[:credentials] ||= DEFAULTS[:credentials]
options[:xmlrpc] ||= DEFAULTS[:xmlrpc]

# This defines the worker threads, as CONSTANT
VM_INFO = {
    :action    => 'vm.info',
    :arguments => proc {
        [rand(20000)]
    },
    :command => proc {
        "onevm show #{rand(20000)}"
    },
    :sleep   => 1,
    :threads => options[:vminfo]
}

VM_POOL_INFO = {
    :action    => 'vmpool.info',
    :arguments => proc {
        [-2, -1, -1, -1]
    },
    :command => proc {
        'onevm list'
    },
    :sleep   => 10,
    :threads => options[:vmpoolinfo]
}

HOST_INFO = {
    :action    => 'host.info',
    :arguments => proc {
        [rand(1250)]
    },
    :command => proc {
        "onehost show #{rand(1250)}"
    },
    :sleep   => 1,
    :threads => options[:hostinfo]
}

HOST_POOL_INFO = {
    :action    => 'hostpool.info',
    :arguments => proc {
        [-2, -1, -1]
    },
    :command => proc {
        'onehost list'
    },
    :sleep   => 1,
    :threads => options[:hostpoolinfo]
}

ZONE_INFO = {
    :action    => 'zone.raftstatus',
    :arguments => proc {
        []
    },
    :command => proc {
        'onezone list'
    },
    :sleep   => 1,
    :threads => options[:zoneraftstatus]
}

class ActionThread

    def initialize(client, do_thread, endpoint)
        @client = client
        @endpoint = endpoint
        @do_thread = do_thread
    end

    def do_api_calls(threads, options, log)
        options[:threads].to_i.times {|i|
            threads << Thread.new {
                puts "Starting thread for #{options[:action]} #{i+1}/#{options[:threads]}"

                loop do
                    length = '-'

                    ti = Time.now

                    if @do_thread == true

                        rc = @client.call(options[:action], *options[:arguments].call)

                        if OpenNebula.is_error? rc
                            puts rc.message
                            exit 1
                        end

                        length = rc.length
                    else
                        `ONE_XMLRPC=#{@endpoint} #{options[:command].call} | cat`
                    end

                    te = Time.now

                    if log
                        log.write(te - ti)
                    else
                        puts "#{te} #{options[:action]} \t #{te - ti} \t #{length}"
                    end

                    sleep options[:sleep]
                end
            }
        }
    end

end

require 'opennebula'
include OpenNebula

['vm.info', 'vmpool.info', 'host.info', 'hostpool.info', 'zone.raftstatus'].each do |file|
    File.delete(file) if File.exist?(file)
    File.open("/tmp/#{file}", 'w') {}
end

ENDPOINT = 'http://127.0.0.1:2633/RPC2'
client = Client.new(options[:credentials], ENDPOINT)

at = ActionThread.new(client, options[:xmlrpc], ENDPOINT)

threads = []
logs = []

if options[:logs]
    ['vm.info', 'vmpool.info', 'host.info', 'hostpool.info', 'zone.raftstatus'].each do |call|
        logs << LogFile.new(options[:logs] + "/#{call}.log")
    end
else
    5.times { logs << nil }
end

at.do_api_calls(threads, VM_INFO, logs[0])
at.do_api_calls(threads, VM_POOL_INFO, logs[1])
at.do_api_calls(threads, HOST_INFO, logs[2])
at.do_api_calls(threads, HOST_POOL_INFO, logs[3])
at.do_api_calls(threads, ZONE_INFO, logs[4])

threads.each(&:join)
