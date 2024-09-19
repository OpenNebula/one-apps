require 'init_functionality'
require 'flow_helper'

require 'json'
require 'yaml'

#-------------------------------------------------------------------------------
# Checks CLI format outputs
#-------------------------------------------------------------------------------

# Commands that do not have list/show operation
EXCLUDE_CMDS = %w[one
                  oneacct
                  onecfg
                  oned
                  onedb
                  oneflow-server
                  onegate
                  onegate.rb
                  onegate-server
                  onehem-server
                  onevcenter
                  onevmdump
                  onegather
                  oneirb
                  onelog
                  onegather
                  oneverify]

# Check list commads outputs
#
# @param cmds        [Array]     Commands to check
# @param format      [String]    Format to check
# @param f_class     [Class]     Format class
# @param f_exception [Exception] Parse exception
def check_list(cmds, format, f_class, f_exception)
    cmds.each do |cmd|
        ret = SafeExec.run("#{cmd} list --#{format}")
        ok  = false

        if ret.stdout.empty?
            expect(ret.stderr.empty?).to eq(true), cmd
        else
            begin
                f_class.parse(ret.stdout)
                ok = true
            rescue f_exception => e
                STDERR.puts e
            end

            expect(ok).to eq(true), cmd
        end
    end
end

# Check show commands format
#
# @param cmds   [Array]  Commands to check
# @param format [String] Format to check
def check_show_format(cmds, format)
    cmds.each do |cmd|
        ret = SafeExec.run("#{cmd} show --#{format}")
        expect(ret.stderr).to_not match("invalid option: --#{format}\n"), cmd
    end
end

# Check show command output
#
# @param cmds    [Array]  Commands to execute
# @param foramt  [String] Format to check
# @param f_class [Class]  Format class
def check_show(cmds, format, f_class)
    cmds.each do |cmd|
        ret = SafeExec.run("#{cmd} show 0 --#{format}")
        ok  = false

        begin
            f_class.parse(ret.stdout)
            ok = true
        rescue StandardError => e
            STDERR.puts e
        end

        expect(ok).to eq(true), cmd
    end
end

RSpec.describe 'CLI format output' do
    include FlowHelper

    before(:all) do
        start_flow

        # All the commands has list output, empty or not
        @cmds  = Dir['/usr/bin/one*']
        @cmds  = @cmds.map {|cmd| cmd.gsub('/usr/bin/', '') }
        @cmds -= EXCLUDE_CMDS

        # To avoid create one object of each resource type, check show only with
        # these commands
        @cmds_show = %w[onecluster onedatastore onevdc]
    end


    context 'when using the --search option with JSON and YAML formats' do
        let(:search_term) { 'LXD_SECURITY_PRIVILEGED' }

        let(:db_type) { @main_defaults[:db]['BACKEND'] || 'mysql' }

        before(:each) do
            skip 'Skipping test for non-MySQL databases' unless db_type == 'mysql'
        end

        it 'correctly filters and formats the output with --search and --json' do
            command = "onevm list --json --no-pager --search #{search_term}"
            output = SafeExec.run(command)
            json_output = JSON.parse(output.stdout)
            expect(json_output).to be_a(Hash)
        end

        it 'correctly filters and formats the output with --search and --yaml' do
            command = "onevm list --yaml --no-pager --search #{search_term}"
            output = SafeExec.run(command)
            yaml_output = YAML.safe_load(output.stdout)
            expect(yaml_output).to be_a(Hash)
        end
    end


    ############################################################################
    # JSON
    ############################################################################

    it 'should check JSON output in list commands' do
        check_list(@cmds, 'json', JSON, JSON::ParserError)
    end

    it 'should check that all show cmds respond to JSON' do
        check_show_format(@cmds, 'json')
    end

    it 'should check JSON output in show commands' do
        check_show(@cmds_show, 'json', JSON)
    end

    ############################################################################
    # YAML
    ############################################################################

    it 'should check YAML output in list commands' do
        check_list(@cmds, 'yaml', YAML, StandardError)
    end

    it 'should check that all show cmds respond to YAML' do
        check_show_format(@cmds, 'yaml')
    end

    it 'should check YAML output in show commands' do
        check_show(@cmds_show, 'yaml', YAML)
    end

    after(:all) do
        stop_flow
    end
end


RSpec.describe 'CLI format output adjusted by XSD' do

    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do
        @info = {}

        mads = "TM_MAD=dummy\nDS_MAD=dummy"
        cli_update('onedatastore update system', mads, false)
        cli_update('onedatastore update default', mads, false)

        # sys DS somehow remains unmonitored
        SafeExec.run('onedb change-body datastore --id 0 /DATASTORE/FREE_MB 10000')
        SafeExec.run('onedb change-body datastore --id 0 /DATASTORE/TOTAL_MB 10000')
    end

    it 'Create host, image, template' do
        cli_create("onehost create localhost --im dummy --vm dummy")

        cli_create('oneimage create -d default --name test --size 1 --no_check_capacity')

        template = <<-EOF
            NAME   = "test"
            CPU    = "1"
            DISK   = [ IMAGE="test" ]
            MEMORY = "128"
            OS     = [ ARCH="x86_64" ]
        EOF

        cli_create('onetemplate create', template)
    end

    it 'Deploys' do
        vmid = cli_create("onetemplate instantiate test")
        @info[:vm] = VM.new(vmid)
        @info[:vm].running?
    end

    it 'VM single disk is array (json)' do
        cmd = cli_action("onevm show #{@info[:vm].id} --json")
        vm = JSON.parse(cmd.stdout)
        expect(vm['VM']['TEMPLATE']['DISK']).to be_an_instance_of(Array)
    end

    it 'VM single disk is array (yaml)' do
        cmd = cli_action("onevm show #{@info[:vm].id} --yaml")
        vm = YAML.load(cmd.stdout)
        disks = vm['VM']['TEMPLATE']['DISK']
        expect(vm['VM']['TEMPLATE']['DISK']).to be_an_instance_of(Array)
    end

    it 'Snapshot disk' do
        cli_action("onevm disk-snapshot-create #{@info[:vm].id} 0 snap")
    end

    it 'VM single snapshot is array (json)' do
        cmd = cli_action("onevm show #{@info[:vm].id} --json")
        vm = JSON.parse(cmd.stdout)
        expect(vm['VM']['SNAPSHOTS']).to be_an_instance_of(Array)
        expect(vm['VM']['SNAPSHOTS'][0]['SNAPSHOT']).to be_an_instance_of(Array)
    end

    it 'VM single snapshot is array (yaml)' do
        cmd = cli_action("onevm show #{@info[:vm].id} --yaml")
        vm = YAML.load(cmd.stdout)
        expect(vm['VM']['SNAPSHOTS']).to be_an_instance_of(Array)
        expect(vm['VM']['SNAPSHOTS'][0]['SNAPSHOT']).to be_an_instance_of(Array)
    end
end
