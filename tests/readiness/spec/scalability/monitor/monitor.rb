#!/usr/bin/env ruby

require 'erb'
require 'socket'
require 'base64'
require 'resolv'
require 'ipaddr'
require 'zlib'
require 'getoptlong'
require_relative 'log'

class CollectdFeeder

    def initialize(opt = {})
        @opt = {
            :port => 4124,
            :host => '127.0.0.1',
            :tmpl_system => "#{`dirname #{$PROGRAM_NAME}`.delete("\n")}/monitor_system.erb",
            :tmpl_host => "#{`dirname #{$PROGRAM_NAME}`.delete("\n")}/monitor_host.erb",
            :tmpl_vm => "#{`dirname #{$PROGRAM_NAME}`.delete("\n")}/monitor_vm.erb",
            :tmpl_vm_state => "#{`dirname #{$PROGRAM_NAME}`.delete("\n")}/monitor_vm_state.erb",
            :numh => 10,
            :freq => 30,
            :chunk => 5,
            :freq_chunk => 5
        }.merge!(opt)

        addr = Socket.getaddrinfo(@opt[:host], @opt[:port])[0]

        @family = addr[0]
        @host   = addr[3]
        @port   = addr[1]

        @udp = UDPSocket.new(@family)
        @udp.connect(@host, @port)
        @tcp = TCPSocket.new(@host, @port)

        @log = LogFile.new @opt[:log]

        tmpl_system = File.read(@opt[:tmpl_system])
        @erb_system = ERB.new(tmpl_system, nil, '-')

        tmpl_host = File.read(@opt[:tmpl_host])
        @erb_host = ERB.new(tmpl_host, nil, '-')

        tmpl_vm = File.read(@opt[:tmpl_vm])
        @erb_vm = ERB.new(tmpl_vm, nil, '-')

        tmpl_vm_state = File.read(@opt[:tmpl_vm_state])
        @erb_vm_state = ERB.new(tmpl_vm_state, nil, '-')
    end

    def do_monitor
        @opt[:cycles].times do
            chunk = @opt[:numh] / @opt[:chunk]
            t_ini = Time.now

            puts "[#{t_ini}] Monitoring Pool"

            chunk.times {|i|
                sent = 0

                @opt[:chunk].times {|j|
                    send_host_data(@opt[:chunk] * i + j)
                    sent += 1
                }

                puts "  chunk #{i}: sent #{sent} messages"

                print "    waiting... for #{@opt[:freq_chunk]} seconds"
                STDOUT.flush

                sleep(@opt[:freq_chunk])

                puts ' done'
            }

            t_end = Time.now
            result = "[#{t_end}] Pool monitored in (#{t_end - t_ini})."

            puts result
            @log.write result

            sleep(@opt[:freq])
        end
    end

    def send_host_data(host_id)
        @id  = host_id

        send_data("SYSTEM_HOST", @erb_system.result(binding))
        send_data("MONITOR_HOST", @erb_host.result(binding))
        send_data("BEACON_HOST", Time.now.to_i.to_s)
        send_data("MONITOR_VM", @erb_vm.result(binding))
        send_data("STATE_VM", @erb_vm_state.result(binding))
    end

    def send_data(msg_type, data)
        zdata  = Zlib::Deflate.deflate(data, Zlib::BEST_COMPRESSION)
        data64 = Base64.encode64(zdata).strip.delete("\n")

        @udp.send("#{msg_type} SUCCESS #{@id} #{Time.now.to_i} #{data64}\n", 0)
    end

    def send_data_tcp(msg_type, data)
        zdata  = Zlib::Deflate.deflate(data, Zlib::BEST_COMPRESSION)
        data64 = Base64.encode64(zdata).strip.delete("\n")

        @tcp.send("#{msg_type} SUCCESS #{@id} #{Time.now.to_i} #{data64}\n", 0)
    end

end

hosts  = 2000
chunk  = 3
chunk_time = 210
hosts_time = 20
cycles = 1
log = LogFile.name

options = GetoptLong.new(
    ['--help', '-h', GetoptLong::NO_ARGUMENT],
    ['--hosts', '-n', GetoptLong::REQUIRED_ARGUMENT],
    ['--chunks', '-c', GetoptLong::REQUIRED_ARGUMENT],
    ['--hosts_time', '-t', GetoptLong::REQUIRED_ARGUMENT],
    ['--chunk_time', '-w', GetoptLong::REQUIRED_ARGUMENT],
    ['--cycles', '-T', GetoptLong::REQUIRED_ARGUMENT],
    ['--log', '-l', GetoptLong::REQUIRED_ARGUMENT]
)

options.each do |opt, arg|
    case opt
    when '--help'
        puts <<-EOF
-h, --help:
   show help

--hosts x, -n x:
   Number of hosts in the pool. Defaults to #{hosts}

--chunks x, -c x:
   Hosts are divided in chunks. All of the hosts in a chunk are monitored at the same time. Defaults to #{chunk}

--hosts_time x, -t x:
   Seconds to wait after all hosts have been monitored to start over. Defaults to #{hosts_time}

--chunk_time x, -w x:
   Seconds to wait after each chunk. Defaults to #{chunk_time}

--cycles x, -T x:
   How many repetitions will be performed. Defaults to #{cycles}

--log x, -l x:
   Where to write the total monitoring time. Defaults to #{log}

        EOF
        exit 0

    when '--hosts'
        hosts = arg.to_i

    when '--chunks'
        chunk = arg.to_i

    when '--hosts_time'
        hosts_time = arg.to_i

    when '--chunk_time'
        chunk_time = arg.to_i

    when '--cycles'
        cycles = arg.to_i

    when '--log'
        log = arg
    end
end

puts <<-EOF
  Generating monitor messages every #{hosts_time} for #{hosts} hosts in chunks
  of #{chunk} hosts.

EOF

#
# Example: ruby ./monitor.rb -n 2000 -c 300 -t 20 -w 5
#
cf = CollectdFeeder.new(:numh => hosts, :chunk => chunk, :freq => hosts_time,
                        :freq_chunk => chunk_time, :cycles => cycles,
                        :log => log)
cf.do_monitor
# cf.send_host_data(0)
