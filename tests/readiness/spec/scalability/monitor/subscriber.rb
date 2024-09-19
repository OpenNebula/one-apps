#!/usr/bin/ruby

require 'ffi-rzmq'
require 'base64'
# require 'statsd-ruby'
require_relative 'log'

# Initialize event queue connection

@context    = ZMQ::Context.new(1)
@subscriber = @context.socket(ZMQ::SUB)

subscription = 'EVENT API' # TODO: Setup via CLI

@subscriber.setsockopt(ZMQ::SUBSCRIBE, subscription)
@subscriber.connect('tcp://localhost:2101') # TODO: Setup via CLI

# Initialize statsd connection for grafana

# Set up a global Statsd client for a server on localhost:8125
# $statsd = Statsd.new 'localhost', 8125 # TODO: Setup via CLI

log = LogFile.new(ARGV.last || LogFile.name)

key = ''
content = ''

events = 0
success_counter = 0

# Read messages from the event queue
loop do
    @subscriber.recv_string(key)
    @subscriber.recv_string(content)

    key_p = key.split[2].tr('.', '_')

    success = key.split[3].to_i
    events += 1

    if success == 1
        success_counter += 1
        log.write "SUCCESS: #{key_p}"
    else

        log.write "FAILURE: #{key_p}"
    end

    info = "TOTAL: #{events}, SUCCESS: #{success_counter}"

    log.write info
end
