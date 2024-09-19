#!/usr/bin/ruby

require 'optparse'
require_relative 'log'
require_relative 'hook'
require 'English'
require 'yaml'
require 'time'

IDENT = ' ' * 37

# Test execution modes
MODES = {
    :mon => 'only monitoring',
    :api => 'only api',
    :api_mon => 'monitoring + api_feeder',
    :hem => 'api_mon + hooks'
}

CALLS = [10, 20, 30] # total calls per second

def mode_desc
    text = ''
    MODES.each do |k, v|
        info = "#{k} -> #{v}\n"
        info.prepend IDENT unless text.empty?
        text << info
    end
    text
end

def valid_format(arg)
    text = "Valid values for --#{arg} are"

    [text, text.length]
end

options = {
    :delay => 5,
    :repeat => 1,
}

ARGV.options do |opts|
    opts.banner = 'OpenNebula Frontend test runner'
    opts.define_head("Usage: #{$PROGRAM_NAME} [OPTIONS]",
                     'Example', "#{$PROGRAM_NAME} -m clean -c 10 [-d 3]")
    opts.separator('')

    opts.on('-m', '--mode STR', String, mode_desc) do |v|
        if !MODES.key? v.to_sym
            valid = valid_format('mode')
            puts valid[0]

            MODES.keys.map {|k| k.to_s }.each {|k| puts "#{' ' * valid[1]} #{k}" }

            exit 1
        end

        options[:mode] = v
    end
    opts.separator('')

    opts.on('-c', '--calls NUM', Integer, 'Calls per second, possible values 10, 20, 30') do |v|
        if !CALLS.include? v
            valid = valid_format('mode')
            puts valid[0]

            CALLS.each {|c| puts "#{' ' * valid[1]} #{c}" }

            exit 1
        end

        options[:calls] = v
    end
    opts.separator('')

    opts.on('-d', '--delay NUM', Integer, 'Delay between monitoring chunks') do |v|
        options[:delay] = v
    end
    opts.separator('')

    opts.on('-r', '--repeat NUM', Integer, 'How many times repeat the monitor cycle') do |v|
        options[:repeat] = v
    end
    opts.separator('')

    opts.on_tail('-h', '--help', 'Show this help message.') do
        puts(opts)
        exit(0)
    end
    opts.parse!
end

if !options[:calls] || !options[:mode]
    puts 'It is required to pass --mode and --calls arguments'
    exit 1
end

log_dir = "/var/lib/one/scalability_tests/#{LogFile.name}/#{options[:mode]}/#{options[:calls]}"
FileUtils.mkdir_p(log_dir)
File.chmod(0o777, log_dir)

# Setup individual test scripts # TODO: configure monitoring via CLI
monitor_args = "--hosts 1250 --chunks 25 --hosts_time #{options[:delay]} --chunk_time #{options[:delay]} --cycles 1 --log #{log_dir}/monitor.log"
# subscriber_args = "'EVENT API' 2101 8125 #{log_dir}/subscriber.log" # TODO

calls = [3, 2, 3, 2, 2].map {|a| a * options[:calls] / 10 }
api_calls = %w[host.info hostpool.info vm.info vmpool.info zone.raftstatus]

api_feeder_args = " --logs #{log_dir}"

0.upto(calls.size - 1) do |n|
    api_feeder_args.prepend("--#{api_calls[n].delete('.')} #{calls[n]} ")
end

def output_results(log_dir, mode)
    # Print memory usage stats for oned
    usage = `top -b -n 1 -p \`pgrep oned\` | tail -1`.split
    puts "oned     MEM virtual: #{usage[4]}, reserved: #{usage[5]}, shared: #{usage[6]}"

    usage = `top -b -n 1 -p \`pgrep monitord\` | tail -1`.split
    puts "monitord MEM virtual: #{usage[4]}, reserved: #{usage[5]}, shared: #{usage[6]}"

    if mode != 'mon'
        # Print statistics from api_feeder
        actions = [ "vm.info", "vmpool.info", "host.info", "hostpool.info", "zone.raftstatus" ]
        actions.each do |action|
            response_times = Array.new
            total_time=0
            File.readlines("#{log_dir}/#{action}.log").each do |number|
                total_time = total_time + number.to_f
                response_times << number.to_f
            end
            average = total_time / response_times.length
            puts "Action - #{action}:\ttotal time: #{'%.2f' %total_time} sec, average #{'%.2f' %average} sec"
        end
    end

    if mode != 'api'
        # Parse monitord.conf, print monitoring statistics
        host_mon = File.foreach("/var/log/one/monitor.log").grep(/Successfully monitored host/);
        vm_mon = File.foreach("/var/log/one/monitor.log").grep(/Successfully monitored VM/);
        puts "Count of host monitoring actions: #{host_mon.count}"
        puts "Count of vm monitoring actions:   #{vm_mon.count}"

        timeFirst = Time.parse(host_mon[0].split(' [').first)
        timeLast = Time.parse(host_mon[-1].split(' [').first)
        puts "Monitoring hosts time = #{timeLast - timeFirst}"

        timeFirst = Time.parse(vm_mon[0].split(' [').first)
        timeLast = Time.parse(vm_mon[-1].split(' [').first)
        puts "Monitoring VM time    = #{timeLast - timeFirst}"

        puts `cat #{log_dir}/monitor.log`
    end

    if mode == 'hem'
        # Parse monitord.conf, print monitoring statistics
        puts 'Hook results:'
        puts `tail -2 #{log_dir}/subscriber.log`
    end

end

###############
# Start Tests #
###############

if options[:mode] == 'hem'
    # Setup api hooks
    hook_exec_log = "#{log_dir}/hook_script.log"
    hook_cmd = '/tmp/scalability_hook'
    hook_cmd_content = "
#!/bin/bash

echo executed hook script >> #{hook_exec_log}
    "
    FileUtils.rm_f(hook_cmd)
    File.open(hook_cmd, 'a') {|f| f.write(hook_cmd_content) }
    File.chmod(0o777, hook_cmd)

    hook_ids = []

    hook = ApiHook.new("scalability_raftstatus", hook_cmd, 'api', "one.zone.raftstatus")
    hook_ids << hook.add_to_one

    # Set hook concurrency
    hem_config_file = '/etc/one/onehem-server.conf'
    hem_config = YAML.load_file hem_config_file
    hem_config[:concurrency] = options[:calls]*2
    File.open(hem_config_file, 'w') {|f| f.write hem_config.to_yaml }

    `service opennebula-hem status 2>/dev/null`

    if $CHILD_STATUS == 0
        # The service exists, restart it
        `systemctl restart opennebula-hem`

        if $CHILD_STATUS != 0
            puts 'Failed to restart HEM, run test again'
            exit $CHILD_STATUS
        end
    end
end

puts 'Restarting opennebula'
`service opennebula status 2>/dev/null`

if $CHILD_STATUS != 0
    # Open nebula is not service
    `one restart`
    if $CHILD_STATUS != 0
        puts 'Failed to restart opennebula'
        exit $CHILD_STATUS
    end
else
    # Restart opennebula as service
    `systemctl restart opennebula`

    if $CHILD_STATUS != 0
        puts 'Failed to restart opennebula'
        exit $CHILD_STATUS
    end
end

`killall -9 mm_sched`

begin
    pids = []

    # Start api_feeder
    if options[:mode] != 'mon'
        puts 'Starting api_feeder'
        cmd = "ruby #{__dir__}/api_feeder.rb #{api_feeder_args}"
        pids << spawn(cmd)
    end

    # Start subs if hem or hm
    if options[:mode] == ('hem')
        cmd = "ruby #{__dir__}/subscriber.rb #{log_dir}/subscriber.log"
        pids << spawn(cmd)
    end

    # Start monitoring and terminate tests when cycles run
    if options[:mode] == 'api'
        # Only api mode, wait 30 seconds to measure results
        puts 'Sleeping for 30 sec'
        sleep 30
    else
        puts "Total cycles #{options[:repeat]}"
        options[:repeat].times do |n|
            # Run monitoring cycle
            puts "Starting monitoring #{n+1}. cycle"
            `ruby #{__dir__}/monitor.rb #{monitor_args}`

            usage = `top -b -n 1 -p \`pgrep oned\` | tail -1`.split
            puts "oned     MEM virtual: #{usage[4]}, reserved: #{usage[5]}, shared: #{usage[6]}"

            usage = `top -b -n 1 -p \`pgrep monitord\` | tail -1`.split
            puts "monitord MEM virtual: #{usage[4]}, reserved: #{usage[5]}, shared: #{usage[6]}"
        end
    end

ensure
    pids.each {|pid| Process.kill('HUP', pid) }

    # Delete added hooks
    hook_ids.each {|i| `onehook delete #{i}` } if options[:mode] == 'hem'

    sleep 1

    output_results(log_dir, options[:mode])

    # Save HEL
    #FileUtils.mv(hook_exec_log, "#{hook_exec_log}.#{File.mtime(hook_exec_log).to_i}") if File.exist?(hook_exec_log)
end
