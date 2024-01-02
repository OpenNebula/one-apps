#!/usr/bin/env ruby

# frozen_string_literal: true

begin
    require '/etc/one-appliance/lib/helpers.rb'
rescue LoadError
    require_relative './lib/helpers.rb'
end

require 'optparse'

STEPS = %w[install configure bootstrap]

SERVICE_D = File.join File.dirname(__FILE__), 'service.d'

SERVICE_LOGDIR = '/var/log/one-appliance'

def include_services(service_d = SERVICE_D)
    Dir[File.join service_d, '**/main.rb'].each do |path|
        require path
    end

    before = Module.constants

    include Service

    after = Module.constants

    (after - before).sort.map do |constant|
        Module.const_get constant
    end
end

if caller.empty?
    steps = <<~STEPS
        Steps:
            #{STEPS.join(' ')}
    STEPS

    parser = OptionParser.new do |opts|
        opts.banner = "Usage: #{$PROGRAM_NAME} [options] step1 step2 ..."
        opts.separator 'Options:'
        opts.on_tail('-h', '--help', 'Show help message') do
            puts opts
            puts steps
            exit 0
        end
    end
    parser.parse!

    if ARGV.empty? || !(ARGV - STEPS).empty?
        puts parser.help
        puts steps
        exit 1
    end

    Dir.mkdir(SERVICE_LOGDIR, 0750) unless File.exist?(SERVICE_LOGDIR)

    stdout, stderr = $stdout.dup, $stderr.dup

    services = sorted_deps(include_services.to_h { |s| [s, s.const_get(:DEPENDS_ON)] })

    ARGV.product(services).each do |step, service|
        set_status step

        open File.join(SERVICE_LOGDIR, "#{step}.log"), 'a' do |logfile|
            $stdout.reopen logfile
            $stderr.reopen logfile
            service.method(step).call
        rescue StandardError => e
            stderr.puts e.full_message
            stderr.flush
            raise e
        ensure
            $stdout.flush
            $stderr.flush
        end
    end

    $stdout, $stderr = stdout, stderr

    set_status :success
end
