#!/usr/bin/env ruby

require 'augeas'
require 'fileutils'
require 'json'
require 'nokogiri'
require 'open3'
require 'tempfile'
require 'yaml'

NFLOWS   = 8000 # Number of flows to deploy
CHUNK    = 8    # Number of chunks
SLEEP    = 10   # Sleep in seconds
TIMEOUT  = 1200 # Wait timeout in seconds
NSAMPLES = 2000 # Number of random samples

# Database options
DB_NAME = 'opennebula'
DB_USER = 'oneadmin'
DB_PASS = 'oneadmin'

LOG_FILE = "load.log-#{Time.now.to_i}"

log_file = File.open(LOG_FILE, 'w')

################################################################################
# HELPERS
################################################################################

# Print header in bold
def print_header(text)
    print "\33[2J\33[H"
    print "\33[1m"
    print text
    print "\33[0m"
    puts
end

# Error message
def error_message(rc, msg)
    if rc
        STDERR.puts msg
    else
        STDERR.puts 'Something went wrong, aborting tests...'
        exit(-1)
    end
end

# Clean database and auth files
def clean
    STDERR.puts 'Deleting DB tables...'
    Open3.capture3(
        "TABLES=$(mysql -u #{DB_USER} -p#{DB_PASS} #{DB_NAME} -e 'show tables' | awk '{ print $1}' | grep -v '^Tables' )

        for t in $TABLES
        do
            mysql -u #{DB_USER} -p#{DB_PASS} #{DB_NAME} -e \"drop table $t\"
        done"
    )

    if File.exist?('/var/lib/one/.one')
        STDERR.puts 'Deleting .one...'
        FileUtils.rm_r('/var/lib/one/.one')
    end

    STDERR.puts 'Creating .one...'
    FileUtils.mkdir('/var/lib/one/.one')

    STDERR.puts 'Deleting /etc/one files...'
    FileUtils.rm('/etc/one/oned.conf')
    FileUtils.rm('/etc/one/monitord.conf')
    FileUtils.rm('/etc/one/oneflow-server.conf')

    STDERR.puts 'Copying /etc/one files...'
    FileUtils.cp('one/oned.conf', '/etc/one')
    FileUtils.cp('one/monitord.conf', '/etc/one')
    FileUtils.cp('one/oneflow-server.conf', '/etc/one')
end

# Get augeas object
def get_augeas(file)
    file_dir  = File.dirname(file)
    file_name = File.basename(file)

    aug = Augeas.create(:no_modl_autoload => true,
                        :no_load          => true,
                        :root             => file_dir,
                        :loadpath         => file)

    aug.clear_transforms
    aug.transform(:lens => 'Oned.lns', :incl => file_name)
    aug.context = "/files/#{file_name}"
    aug.load

    aug
end

# Modify scheduler attrs
def modify_sched
    STDERR.puts 'Updating sched conf...'

    aug = get_augeas('/etc/one/sched.conf')

    aug.set('SCHED_INTERVAL', '5')
    aug.set('MAX_DISPATCH', '1000')
    aug.set('MAX_HOST', '1000')

    aug.save
end

# Modify oned database conf
def modify_oned
    STDERR.puts 'Updating oned conf...'

    aug = get_augeas('/etc/one/oned.conf')

    aug.set('DB/BACKEND', 'mysql')
    aug.set('DB/SERVER', 'localhost')
    aug.set('DB/PORT', '0')
    aug.set('DB/USER', DB_USER)
    aug.set('DB/PASSWD', DB_PASS)
    aug.set('DB/DB_NAME', DB_NAME)
    aug.set('DB/CONNECTIONS', '25')

    aug.save

    Open3.capture3(
        'echo "VM_MAD = [ NAME=\"dummy\", SUNSTONE_NAME=\"Testing\", ' \
        'EXECUTABLE=\"one_vmm_dummy\", TYPE=\"xml\" ]" >> ' \
        '/etc/one/oned.conf'
    )
end

# Modify monitord conf
def modify_monitor
    STDERR.puts 'Updating monitord conf...'

    Open3.capture3('echo "IM_MAD = [
     NAME          = \"dummy\",
     SUNSTONE_NAME = \"Dummy\",
     EXECUTABLE    = \"one_im_sh\",
     ARGUMENTS     = \"-r 3 -t 15 -w 90 dummy\",
     THREADS       = 0]" >> /etc/one/monitord.conf')
end

# Modify oneflow-server conf
def modify_flow
    STDERR.puts 'Updating oneflow-server conf...'

    yaml = YAML.load_file('/etc/one/oneflow-server.conf')

    yaml[:wait_timeout] = 1

    File.open('/etc/one/oneflow-server.conf', 'w') do |file|
        file.write(yaml.to_yaml)
    end
end

# Start services
def start
    STDERR.puts 'Starting...'

    _, _, s1 = Open3.capture3('one start &> /dev/null')
    _, _, s2 = Open3.capture3('oneflow-server start &> /dev/null')

    error_message(s1.success? && s2.success?, 'Services started, testing...')
end

# Stop services
def stop
    STDERR.puts 'Stopping...'

    _, _, s1 = Open3.capture3('one stop &> /dev/null')
    _, _, s2 = Open3.capture3('oneflow-server stop &> /dev/null')

    error_message(s1.success? && s2.success?,
                  'Services stopped, tests finished...')
end

# Create resources for tests
#   - host
#   - VM template
#   - Flow template
def create_resources
    host          = 'localhost'
    vm_template   = 'vm_template'
    flow_template = 'flow_template'

    cpu = 0.01
    mem = 1

    STDERR.puts 'Creating resources...'

    _, _, s = Open3.capture3("onehost create #{host} -i dummy -v dummy")
    error_message(s.success?, 'Host created...')

    _, _, s = Open3.capture3(
        "onetemplate create --name #{vm_template} --cpu #{cpu} --memory #{mem}"
    )
    error_message(s.success?, 'VM template created...')

    flow = <<-EOF
        {
            "name": "#{flow_template}",
            "deployment": "straight",
            "description": "",
            "roles": [
                {
                "name": "master",
                "cardinality": 1,
                "vm_template": 0,
                "elasticity_policies": [

                ],
                "scheduled_policies": [

                ]
                },
                {
                "name": "slave",
                "cardinality": 1,
                "vm_template": 0,
                "parents": [
                    "master"
                ],
                "elasticity_policies": [

                ],
                "scheduled_policies": [

                ]
                }
            ],
            "shutdown_action": "terminate-hard",
            "ready_status_gate": false
        }
    EOF

    flow_f = Tempfile.new('flow')
    flow_f << flow
    flow_f.close

    _, _, s = Open3.capture3("oneflow-template create #{flow_f.path}")
    error_message(s.success?, 'Flow template created...')

    [host, flow_template]
end

# Update reserved CPU
def update_host(host)
    f = Tempfile.new('host')
    f << 'RESERVED_CPU="-1000000"'
    f << "\n"
    f << 'RESERVED_MEM="-1000000000000"'
    f.close

    Open3.capture3("onehost update #{host} #{f.path}")

    f.unlink
end

# Instantiate flow template NFLOW times
def instantiate_flow(flow_template, ratio)
    m  = NFLOWS / ratio
    _, _, s = Open3.capture3(
        "oneflow-template instantiate #{flow_template} -m #{m}"
    )
    error_message(s.success?, 'Flows instantiated...')
end

def wait_flows(filter, total, msg)
    STDERR.puts msg

    s_time = Time.now
    rc     = true

    loop do
        n, = Open3.capture3("oneflow list | grep -i #{filter} | wc -l")

        n.strip!

        break if n.to_i == total

        if Time.now - s_time >= TIMEOUT
            STDERR.puts 'Timeout reached!!!!...'
            rc = false
            break
        end

        sleep SLEEP
    end

    rc
end

################################################################################
# TESTS
################################################################################

# Test #1: Instantiate a large number of flows in different chunks
#   Wait until all of them are running
def test_1(log_file, flow_template)
    print_header('Running test #1')
    puts "#{NFLOWS} flows in chunks of #{NFLOWS / CHUNK} flows"

    time = 1
    rc   = true

    CHUNK.times do
        STDERR.puts "Iteration #{time}"

        s_time = Time.now
        instantiate_flow(flow_template, CHUNK)
        rc &&= wait_flows('runn',
                          (NFLOWS / CHUNK) * time,
                          'Waiting flows to be RUNNING...')

        e_time = Time.now
        STDERR.puts "Done in #{e_time - s_time} seconds"
        log_file << "Iterarion #{time} done in #{e_time - s_time} seconds\n"

        time += 1
    end

    if rc
        log_file << "Test #1: OK\n"
    else
        log_file << "Test #1: FAIL\n"
    end
end

# Test #2: Power off VMs randomly to check warning state
#   Wait until all random flows are in warning

def test_2(log_file)
    print_header('Running test #2')
    puts "Randomly power off #{NSAMPLES} VMs and check warning"

    flows   = (0..NFLOWS).to_a
    samples = flows.sample(NSAMPLES)
    rc      = true

    STDERR.puts 'Powering off VMs...'

    # Poweroff random VMs
    samples.each do |s|
        Open3.capture3("onevm poweroff #{s}")
    end

    s_time = Time.now
    samples.each do |s|
        s_time = Time.now

        loop do
            xml     = Nokogiri::XML(Open3.capture3("onevm show #{s} -x")[0])
            service = xml.xpath('//SERVICE_ID').text
            service = JSON.parse(Open3.capture3("oneflow show #{service} -j")[0])

            if service['DOCUMENT']['TEMPLATE']['BODY']['state'] == 4
                STDERR.puts "Flow #{service['DOCUMENT']['ID']} is in warning..."
                break
            end

            if Time.now - s_time >= TIMEOUT
                STDERR.puts 'Timeout reached!!!!...'
                STDERR.puts "Flow #{service['DOCUMENT']['ID']} is NOT in warning..."
                rc = false
                break
            end

            sleep SLEEP
        end
    end
    e_time = Time.now

    STDERR.puts "Done in #{e_time - s_time} seconds"
    sleep 5

    if rc
        log_file << "Test #2: OK #{e_time - s_time} seconds\n"
    else
        log_file << "Test #2: FAIL #{e_time - s_time} seconds\n"
    end

    samples
end

# Test #3: Power on VMs to check running state again
#   Wait until all flows are in running
def test_3(log_file, samples)
    print_header('Running test #3')
    puts "Resume #{NSAMPLES} VMs and check running"

    STDERR.puts 'Resuming VMs...'

    # Resume random VMs
    samples.each do |s|
        Open3.capture3("onevm resume #{s}")
    end

    s_time = Time.now
    rc     = wait_flows('runn', NFLOWS, 'Waiting flows to be RUNNING')
    e_time = Time.now

    STDERR.puts "Done in #{e_time - s_time} seconds"
    sleep 5

    if rc
        log_file << "Test #3: OK #{e_time - s_time} seconds\n"
    else
        log_file << "Test #3: FAIL #{e_time - s_time} seconds\n"
    end
end

# Test #4: Check number of established connections
#   There should be only one, the watch dog
def test_4(log_file, pid)
    print_header('Running test #4')
    puts 'Check that there is only 1 connection ESTABLISHED'

    n_conn = Open3.capture3("ss -tanp | grep -i esta | grep #{pid} | wc -l")[0].strip

    if n_conn.to_i == 1
        STDERR.puts 'OK'
        log_file << "Test #4: OK\n"
    else
        STDERR.puts "FAIL: #{n_conn}"
        log_file << "Test #4: FAIL #{n_conn}\n"
    end
end

def get_memory(pid)
    Open3.capture3(
        "cat /proc/#{pid}/status | grep VmRSS | cut -d ':' -f 2"
    )[0].strip
end

# Test #5: Check RES Memory
def test_5(log_file, pid)
    print_header('Running test #5')
    puts 'Check RES memory'

    log_file << "Test #5: #{get_memory(pid)}\n"
end

# Test #6: Check FD opened by the server
#   There should be 13 FD opened, 4 related with log 17 related with the process
def test_6(log_file, pid)
    print_header('Running test #6')
    puts 'Check FD opened'

    n_files = Open3.capture3("ls /proc/#{pid}/fd | wc -l")[0].strip

    if n_files.to_i == 21
        STDERR.puts 'OK'
        log_file << "Test #6: OK\n"
    else
        STDERR.puts "FAIL: #{n_files}"
        log_file << "Test #6: FAIL #{n_files}\n"
    end
end

################################################################################
# MAIN
################################################################################

# Test #0: Preparation
#   - Clean
#   - Change config files
#   - Create resources
clean

modify_monitor
modify_oned
modify_sched
modify_flow

start

loop do
    break if File.exist?('/var/run/one/oned.pid') &&
             File.exist?('/var/run/one/oneflow.pid')
end

sleep 10

host, flow_template = create_resources
pid  = Open3.capture3('ps auxww | grep "ruby /usr/lib/one/oneflow/oneflow-server.rb" | grep -v grep | awk \'{print $2}\'')[0].strip
oned = Open3.capture3('ps auxww | grep "oned" | grep -v grep | awk \'{print $2}\'')[0].strip

update_host(host)

log_file << "Oned Init Memory #{get_memory(oned)}\n"
log_file << "Flow Init Memory #{get_memory(pid)}\n"

################################################################################

test_1(log_file, flow_template)

################################################################################

samples = test_2(log_file)

################################################################################

test_3(log_file, samples)

################################################################################

test_4(log_file, pid)

################################################################################

test_5(log_file, pid)

################################################################################

test_6(log_file, pid)

################################################################################

log_file << "Oned Final Memory #{get_memory(oned)}\n"

stop

log_file.close
print_header("Log stored in #{LOG_FILE}")
