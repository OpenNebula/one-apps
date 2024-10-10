require 'rspec'
require_relative 'lib/init' # Load CLI libraries. These issue opennebula commands to mimic admin behavior

# Establish some configuration
VM_TEMPLATE = 'suse15'
KERNEL_VERSION = '6.4.0-150600.23.7-default'

describe 'Contextualization' do
    before(:all) do
        @info = {}  # Used to pass info across tests
    end

    # Check if dnsmas is running on the OpenNebula frontend
    it 'dnsmasq is running' do
        unless system('sudo systemctl is-active --quiet dnsmasq')
            STDERR.puts('dnmasq was not runnin, starting')
            system('sudo systemctl start dnsmasq')
        end

        expect(system('sudo systemctl is-active --quiet dnsmasq')).to be(true)
    end

    # Create a new VM by issuing onetempalte instantiate VM_TEMPLATE
    it 'create a new VM' do
        @info[:vm] = VM.instantiate(VM_TEMPLATE)

        @info[:vm].running? # is RUNNING state
        @info[:vm].reachable? # has ssh access
    end

    it 'inspects VM kernel version' do
        execution = @info[:vm].ssh('uname -r') # execute the uname -r command via ssh on the VM

        expect(execution.exitstatus).to eq(0) # check the command is sucessful as expected

        kernel_version = execution.stdout.chomp # get output and trim newline

        expect(kernel_version).to eq(KERNEL_VERSION) # verify if the kernel version matches
    end
end
