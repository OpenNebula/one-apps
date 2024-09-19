require 'init_functionality'
require 'opennebula_test'
require 'rubygems'

VMS = [
    { :name => 'abc' },
    { :name => 'abc-test', :image => %w[db1 db2] },
    { :name => 'def', :image => %w[db1] }
]

describe 'VirtualMachine search test' do
    before(:all) do
        if @main_defaults &&
           @main_defaults[:db] &&
           @main_defaults[:db]['BACKEND'] != 'mysql'
            skip 'only for mysql DB backend'
        end

        m_version = `mysql --version`
        m         = m_version.match(
            /^mysql\s+Ver\s+(?:[\d\.]+\s+Distrib\s+)?([\d\.]+).*/
        )

        @version = Gem::Version.new(m[1]) if m

        skip if @version < Gem::Version.new('5.6')

        # ----------------------------------------------------------------------
        # Create datablocks
        # ----------------------------------------------------------------------
        %w[db1 db2].each do |db|
            cli_action("oneimage create --size 1024 --name #{db} --datastore 1 --no_check_capacity")
        end

        # ----------------------------------------------------------------------
        # Create VMs
        # ----------------------------------------------------------------------
        VMS.each do |vm|
            vm[:image] ? disk = "--disk #{vm[:image].join(',')}" : disk = ''

            cli_action(
                "onevm create --name #{vm[:name]} --memory 1 --cpu 1 #{disk}"
            )
        end
    end

    # --------------------------------------------------------------------------
    # Search tests:
    #
    #   - A - Find multiple VMs with same pattern on them (abc)
    #   - B - Find a VM that matches two conditions (name & disk)
    #   - C - Find a VM that contains an specifc disk (db1)
    #   - D - NOT find a VM
    # --------------------------------------------------------------------------

    it 'A - should find a VM using NAME attribute' do
        vms = cli_action(
            'onevm list --search "VM.NAME=abc" -l NAME --no-header'
        ).stdout.split("\n")

        expect(vms.size).to eq(2)
        expect(vms[0]).to eq('abc-test')
        expect(vms[1]).to eq('abc')
    end

    it 'B - should find a VM using NAME & DISK name attributes' do
        vm = cli_action(
            'onevm list --search "VM.NAME=abc&VM.TEMPLATE.DISK[*].IMAGE=db1" ' \
            '-l NAME --no-header'
        ).stdout.strip

        expect(vm).to eq('abc-test')
    end

    it 'C - should find a VM using DISK name attribute' do
        vms = cli_action(
            'onevm list --search "VM.TEMPLATE.DISK[*].IMAGE=db1" ' \
            '-l NAME --no-header'
        ).stdout.split("\n")

        expect(vms.size).to eq(2)
        expect(vms[0]).to eq('def')
        expect(vms[1]).to eq('abc-test')
    end

    it 'D - should NOT find a VM using NAME attribute' do
        vms = cli_action(
            'onevm list --search "VM.NAME=non-exist" -l NAME --no-header'
        ).stdout

        expect(vms).to be_empty
    end

    # --------------------------------------------------------------------------
    # Extended tests
    # --------------------------------------------------------------------------

    it 'should find a VM with extended info' do
        xml = cli_action_xml('onevm list -x --search "VM.NAME=def" --extended')

        expect(xml['//VM/PERMISSIONS']).to_not eq(nil)
    end

    it 'should list a VM with extended info' do
        xml = cli_action_xml('onevm list -x --extended')

        expect(xml['//VM/PERMISSIONS']).to_not eq(nil)
    end
end
