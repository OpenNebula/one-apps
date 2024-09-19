#!/usr/bin/ruby

require 'init'
require 'rubygems'

RSpec.describe 'fog-opennebula gem integration testing' do
    before(:all) do
        @defaults = RSpec.configuration.defaults
        @info = {}
    end

    it 'connects to XMLRPC' do
        Gem.clear_paths
        require 'fog/opennebula'

        # TODO: move credentials to defaults.yaml
        @info[:con] = Fog::Compute.new(
            :provider => 'OpenNebula',
            :opennebula_username => 'oneadmin',
            :opennebula_endpoint => 'http://localhost:2633/RPC2',
            :opennebula_password => 'opennebula'
        )
    end

    it 'instantiates template 0' do
        # creates the vm object, the vm is not instantiated yet
        newvm = @info[:con].servers.new

        newvm.flavor = @info[:con].flavors.get 0 # appplies template to VM

        # Set some attributes
        newvm.name = 'fogVM'
        newvm.flavor.cpu = 0.69
        newvm.flavor.vcpu = 2
        newvm.flavor.memory = 133

        @info[:vm] = newvm.save # instantiate the new vm

        @info[:vm_xml] = cli_action_xml("onevm show -x #{@info[:vm].id}")
    end

    # Checks

    it 'has the same name' do
        expect(vm_xml('NAME') == @info[:vm].name).to be(true)
    end

    # debian10 and alma8 run old gem version
    if Gem::Specification.find_all_by_name('fog-opennebula', '0.0.2').any?
        it 'has the same cpu' do
            expect(vm_xml('TEMPLATE/VCPU') == @info[:vm].cpu).to be(true)
        end
    else
        it 'has the same VCPU' do
            expect(vm_xml('TEMPLATE/VCPU') == @info[:vm].vcpu).to be(true)
        end

        it 'has the same CPU' do
            expect(vm_xml('TEMPLATE/CPU') == @info[:vm].cpu).to be(true)
        end
    end

    it 'has the same memory' do
        expect(vm_xml('TEMPLATE/MEMORY') == @info[:vm].memory).to be(true)
    end

    # Actions

    it 'poweroff created VM' do
        sleep 10 # Wait for VM to boot #TODO: Improve with wait loop

        @info[:vm].stop
        sleep 10 # Wait for VM to poweroff #TODO: Improve with wait loop

        # TODO: Match status with CLI
    end

    it 'resumes created VM' do
        @info[:vm].resume
        sleep 10 # Wait for VM to boot #TODO: Improve with wait loop

        # TODO: Match status with CLI
    end

    it 'destroys created VM' do
        @info[:vm].destroy
        sleep 10 # Wait for VM to stop #TODO: Improve with wait loop

        # TODO: Match status with CLI
    end

    # Helper to get xml field data from a VM
    def vm_xml(value)
        @info[:vm_xml][value]
    end
end
