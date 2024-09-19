require 'nokogiri'

RSpec.shared_examples_for "Scalability" do
    it "Starts monitor stress" do
        $monitoring_proc = IO.popen("/var/lib/one/development/readiness/spec/scalability/monitor/monitor.rb -n 2500 -c 10 -t 1 -w 1 &")
        STDERR.puts "monitoring proc = #{$monitoring_proc.pid}"
    end

    it "Starts benchmarking" do
        $feeder_proc = IO.popen("/var/lib/one/development/readiness/spec/scalability/monitor/api_feeder.rb -l /tmp")
        STDERR.puts "feeder proc = #{$feeder_proc.pid}"
    end

    it "Runs tests for 5 minutes" do
        sleep 300
    end

    it "Stops monitoring" do
        output = Process.kill("KILL",$monitoring_proc.pid)
        expect(output).to eq(1)
    end

    it "Stops benchmarking" do
        output = Process.kill("KILL",$feeder_proc.pid)
        #output = system("kill #{feeder_proc.pid}")
        expect(output).to eq(1)
    end

    it "Checks thresholds" do
        hash = {"vm.info" => 5, "vmpool.info" => 5, "host.info" => 5, "hostpool.info" => 5}
        hash.to_a.each do |pair|
            action = pair[0]
            threshold = pair[1] 
            response_times = Array.new
            total_time=0
            File.readlines("/tmp/#{action}").each do |number|
                total_time = total_time + number.to_f
                response_times << number.to_f
            end
            expect(response_times.length).not_to eq(0)
            average = total_time / response_times.length
            expect(average).to be < threshold
        end
    end

    it "Checks if the server is still master" do
        xml = %x( onezone show 0 --xml )
        leader = false
        Nokogiri::XML(xml).xpath('ZONE/SERVER_POOL/SERVER').to_a.each do |server|
            if server.text.include? $ip
                if server.xpath('STATE').children.text == "3"
                    leader = true
                end
            end
        end
        expect(leader).to be true
    end

    it "Waits for everything to settle down" do
        #It takes a little time to replicate every change
        sleep 60
    end

    it "Checks if index is equal among servers" do
        xml = %x( onezone show 0 --xml )
        log_index = Array.new
        Nokogiri::XML(xml).xpath('ZONE/SERVER_POOL/SERVER/LOG_INDEX').to_a.each do
            |index| log_index << index.text.to_i
        end
        expect(log_index[0] - log_index[1]).to be_between(-2,2).inclusive
        expect(log_index[0] - log_index[2]).to be_between(-2,2).inclusive
        expect(log_index[1] - log_index[2]).to be_between(-2,2).inclusive
    end
end


RSpec.describe "Scalability tests" do
    ###Ansible playbook uses the ip address as hostname
    $ip = File.read('/etc/hostname')
    ###Ansible sets opennebula's ha name as Node-$hsot_address
    name = "Node-#{$ip.split('.')[-1]}"
    xml = %x( onezone show 0 --xml )
    leader = false
    Nokogiri::XML(xml).xpath('ZONE/SERVER_POOL/SERVER').to_a.each do |server|
        if server.text.include? $ip
            if server.xpath('STATE').children.text == "3"
                leader = true
            end
        end
    end
    if leader == true
        include_examples "Scalability"
    end
end
