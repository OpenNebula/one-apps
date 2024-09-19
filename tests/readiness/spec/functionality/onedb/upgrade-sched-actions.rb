# encoding: utf-8
# coding: utf-8

require 'init_functionality'
require 'opennebula_test'
require 'pry'
require 'fileutils'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# Test upgrade from DB version 6.4
RSpec.describe 'Upgrade Scheduled Actions test' do

    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do
        if @main_defaults && @main_defaults[:db]
            unless @main_defaults[:db]['BACKEND'] == 'mysql'
                skip 'only for mysql DB backend'
            end
        end

        system('xz --decompress spec/functionality/onedb/db-sched-actions.dump.xz')

        mysql_version_line = `mysql --version`
        if m = mysql_version_line.match(/^mysql\s+Ver\s+(?:[\d\.]+\s+Distrib\s+)?([\d\.]+).*/)
            @version = Gem::Version.new(m[1])
        end

        if @main_defaults && @main_defaults[:build_components]
            unless @main_defaults[:build_components].include?('enterprise')
                skip 'only for EE'
            end
        end
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it 'should restore and upgrade database with MySQL' do
        @one_test.stop_one

        `mysql -u oneadmin -popennebula -e "drop database opennebula"`
        `mysql -u oneadmin -popennebula -e "create database opennebula"`

        @one_test.restore_db('spec/functionality/onedb/db-sched-actions.dump')

        @share_version, @local_version = @one_test.version_db

        rc = @one_test.upgrade_db

        expect(rc).to eq(true)

        rc = @one_test.start_one

        expect(rc).to eq(true)

        share_version_up, local_version_up = @one_test.version_db

        expect(Gem::Version.new(@local_version)).to be < (Gem::Version.new(local_version_up))
        expect(Gem::Version.new(@share_version)).to be < (Gem::Version.new(share_version_up))
    end

    it 'should check VM scheduled actions are migrated' do
        vm_xml = cli_action_xml('onevm show 0 -x')

        # Test Scheduled Action attributes
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=0]/ACTION']).to eq('poweroff-hard')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=0]/PARENT_ID']).to eq('0')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=0]/TYPE']).to eq('VM')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=0]/TIME'].to_i).to be > 0
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=0]/DONE'].to_i).to be > 0
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=0]/END_TYPE']).to eq('1')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=0]/END_VALUE']).to eq('2')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=0]/REPEAT']).to eq('0')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=0]/DAYS']).to eq ('3,4')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=0]/MESSAGE']).not_to be_nil

        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=1]/ACTION']).to eq('resume')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=1]/PARENT_ID']).to eq('0')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=1]/TYPE']).to eq('VM')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=1]/TIME'].to_i).to be > 0
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=1]/DONE']).to eq('-1')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=1]/END_TYPE']).to eq('-1')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=1]/END_VALUE']).to eq('-1')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=1]/REPEAT']).to eq('-1')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=1]/DAYS']).to eq('')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=1]/MESSAGE']).not_to be_nil
    end

    it 'should update VM scheduled actions' do
        new_time = Time.now.to_i + 10000
        cli_update('onevm sched-update 0 0', "TIME=\"#{new_time}\"", false)
        cli_update('onevm sched-update 0 1', "TIME=\"#{new_time}\"", false)

        vm_xml = cli_action_xml('onevm show 0 -x')

        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=0]/ACTION']).to eq('poweroff-hard')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=0]/PARENT_ID']).to eq('0')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=0]/TYPE']).to eq('VM')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=0]/TIME'].to_i).to eq(new_time)
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=0]/DONE'].to_i).to be > 0
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=0]/END_TYPE']).to eq('1')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=0]/REPEAT']).to eq('0')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=0]/DAYS']).to eq ('3,4')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=0]/MESSAGE']).not_to be_nil

        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=1]/ACTION']).to eq('resume')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=1]/PARENT_ID']).to eq('0')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=1]/TYPE']).to eq('VM')
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=1]/TIME'].to_i).to eq(new_time)
        expect(vm_xml['TEMPLATE/SCHED_ACTION[ID=0]/MESSAGE']).not_to be_nil
    end

    it 'should check creating a new VM scheduled action' do
        cli_action('onevm terminate 2 --schedule "1/1/2033"')

        vm_xml = cli_action_xml('onevm show 2 -x')

        # Test Scheduled Action attributes
        prefix = 'TEMPLATE/SCHED_ACTION[ACTION[contains(.,"terminate")]]'
        expect(vm_xml[prefix + '/ID'].to_i).to be > 0
        expect(vm_xml[prefix + '/PARENT_ID']).to eq('2')
        expect(vm_xml[prefix + '/TYPE']).to eq('VM')
        expect(vm_xml[prefix + '/TIME'].to_i).to be > 0
    end

    it 'should check creating a new Backup Job with scheduled action' do
        template = <<-EOF
            NAME = bj_test
            BACKUP_VMS = "0,2,4"
            DATASTORE_ID = "-1"
            FS_FREEZE  = "AGENT"
            KEEP_LAST  = "5"

            SCHED_ACTION = [
                REPEAT="3",
                DAYS="1",
                TIME="1695478500"
            ]
        EOF

        id = cli_create('onebackupjob create', template)

        xml = cli_action_xml("onebackupjob show -x #{id}")

        expect(xml['NAME']).to eq('bj_test')

        expect(xml['TEMPLATE/BACKUP_VMS']).to eq('0,2,4')
        expect(xml['TEMPLATE/FS_FREEZE']).to eq('AGENT')
        expect(xml['TEMPLATE/KEEP_LAST']).to eq('5')
        expect(xml['TEMPLATE/MODE']).to eq('FULL')
        expect(xml['TEMPLATE/BACKUP_VOLATILE']).to eq('NO')

        expect(xml['TEMPLATE/SCHED_ACTION/PARENT_ID']).to eq(id.to_s)
        expect(xml['TEMPLATE/SCHED_ACTION/REPEAT']).to eq('3')
        expect(xml['TEMPLATE/SCHED_ACTION/DAYS']).to eq('1')
        expect(xml['TEMPLATE/SCHED_ACTION/TIME']).to eq('1695478500')
        expect(xml['TEMPLATE/SCHED_ACTION/ACTION']).to eq('backup')
    end

    it 'should check new json search query' do
        vms = cli_action(
            'onevm list --search "VM.NAME=test" -l NAME --no-header'
        ).stdout.split("\n")

        expect(vms.size).to eq(7)
    end

    it 'should run fsck' do
        run_fsck
    end
end
