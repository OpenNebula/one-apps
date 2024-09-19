# encoding: utf-8
# coding: utf-8

require 'init_functionality'
require 'opennebula_test'
require 'pry'
require 'fileutils'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# Test upgrade from DB version 6.6
RSpec.describe 'Upgrade Backup' do

    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do
        if @main_defaults && @main_defaults[:db]
            unless @main_defaults[:db]['BACKEND'] == 'mysql'
                skip 'only for mysql DB backend'
            end
        end

        # Alma8 and Alma9 has older MySQL version, which doesn't recognize utf8mb4_0900_ai_ci
        skip 'MySQL version doesn\'t recognize utf8mb4_0900_ai_ci' if `hostname`.match('alma')

        system('xz --decompress spec/functionality/onedb/db-backup.dump.xz')

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

        @one_test.restore_db('spec/functionality/onedb/db-backup.dump')

        @share_version, @local_version = @one_test.version_db

        rc = @one_test.upgrade_db

        expect(rc).to eq(true)

        rc = @one_test.start_one

        expect(rc).to eq(true)

        share_version_up, local_version_up = @one_test.version_db

        expect(Gem::Version.new(@local_version)).to be < (Gem::Version.new(local_version_up))
        expect(Gem::Version.new(@share_version)).to be < (Gem::Version.new(share_version_up))
    end

    it 'should check Backup Image metadata' do
        xml = cli_action_xml('oneimage show 5 -x')
        expect(xml['BACKUP_DISK_IDS/ID']).to eq('0')

        xml = cli_action_xml('oneimage show 7 -x')
        expect(xml['BACKUP_DISK_IDS/ID']).to eq('23')

        xml = cli_action_xml('oneimage show 8 -x')
        expect(xml['BACKUP_DISK_IDS/ID']).to eq('123')
    end

    it 'should run fsck' do
        run_fsck
    end
end
