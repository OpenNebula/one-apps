#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Host err-dsbl-off filtering test" do

    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end


    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    
    it "should create 4 new Hosts and wait untill exit init state" do
        hosts = ["good-host", "second-host", "third-host"]
        hosts.each do |host|
            cli_create("onehost create #{host} --im dummy --vm dummy")
            cli_action("onehost show #{host}")
        end
        cli_create("onehost create fourth-host -i kvm -v kvm")
        cli_action("onehost show fourth-host")
        hosts.each do |host|
            wait_for_host_not_in_state(host,'INIT')
        end
        wait_for_host_not_in_state('fourth-host','INIT')
    end

    it "should check the state of hosts after creation" do
        hosts = ["good-host", "second-host", "third-host", "fourth-host"]
        # Check state of first three hosts
        hosts[0..2].each do |host|
            xml = cli_action_xml("onehost show #{host} -x")
            expect(OpenNebula::Host::HOST_STATES[xml['STATE'].to_i]).to eq('MONITORED')
        end
        # Check state of fourth host
        xml = cli_action_xml("onehost show fourth-host -x")
        expect(OpenNebula::Host::HOST_STATES[xml['STATE'].to_i]).to eq('ERROR')
    end

    it "should change second_host state to off" do
        cli_action("onehost offline second-host")
        xml = cli_action_xml("onehost show second-host -x")
        OpenNebula::Host::HOST_STATES[xml['STATE'].to_i]=='OFFLINE'
    end
    
    it "should change third_host state to disable" do
        cli_action("onehost disable third-host")
        xml = cli_action_xml("onehost show third-host -x")
        OpenNebula::Host::HOST_STATES[xml['STATE'].to_i]=='DISABLED'
    end
 
    it "should list all err-dbl-off host (all expect good-host)" do
        host_list_output = cli_action("onehost list --operator OR --no-pager --csv --filter='STAT=off,STAT=err,STAT=dsbl' --list=NAME 2>/dev/null")
        host_list_text = host_list_output.stdout
        expect(host_list_text).to include("second-host", "third-host", "fourth-host")
        expect(host_list_text).not_to include("good-host")
    end

    it "should delete all hosts" do
        hosts = ["good-host", "second-host", "third-host", "fourth-host"]
        hosts.each do |host|
            cli_action("onehost delete #{host}")
        end
        wait_loop(timeout: 60, interval: 1) do
            host_list_finish = cli_action("onehost list --no-pager --csv --list=NAME")
            host_text = host_list_finish.stdout.strip
            break if hosts.none? { |host| host_text.include?(host) }
        end
    end

    # Wait until the specified host transitions out of the given state.
    #
    # Parameters:
    # - host: The name of the host to monitor.
    # - state: The actual state of the host that needs to exit 
    #
    # Returns:
    # Nothing. It finishes once the host's state
    # transitions out of the specified state.
    def wait_for_host_not_in_state(host, state)
	wait_loop(timeout: 60, interval: 1) do
	    xml = cli_action_xml("onehost show #{host} -x")
	    host_state = OpenNebula::Host::HOST_STATES[xml['STATE'].to_i]
	    break if ![state].include?(host_state)
        end
    end
end
