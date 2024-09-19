# encoding: utf-8
# coding: utf-8
#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
require 'opennebula_test'
require 'pry'
require 'fileutils'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# Test upgrade from DB version 5.4
# Huge DB, the test takes a very long time
RSpec.describe "Upgrade test" do

    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do
        if @main_defaults && @main_defaults[:db]
            unless @main_defaults[:db]['BACKEND'] == 'mysql'
                skip 'only for mysql DB backend'
            end
        end

        system('xz --decompress spec/functionality/onedb/db.dump.xz')

        @auth = ENV['ONE_AUTH'] || ENV["HOME"] + "/.one/one_auth"

        FileUtils.cp(@auth,"#{@auth}.bck")

        File.open(@auth , "w") {|f| f.write("admin:pantufla") }

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

    after(:all) do
        FileUtils.cp("#{@auth}.bck", @auth) if @auth

#        system('xz -9 spec/functionality/onedb/db.dump')
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should restore and upgrade database with MySQL" do

        @one_test.stop_one

        `mysql -u oneadmin -popennebula -e "drop database opennebula"`
        `mysql -u oneadmin -popennebula -e "create database opennebula"`

        @one_test.restore_db('spec/functionality/onedb/db.dump')

        @share_version, @local_version = @one_test.version_db

        #Insert one record in logdb table
        `mysql -u oneadmin -popennebula opennebula -e "INSERT INTO logdb \
        (log_index, term, sqlcmd, timestamp, fed_index) \
        VALUES (1,-1,'eJxLys8vKS4pSixQKC5JLEkFADHEBiA=',1234,-1);"`

        rc = @one_test.upgrade_db

        if !rc
            # Make DB encoding match table encoding.
            `mysql -u oneadmin -popennebula opennebula -e \
            "ALTER DATABASE opennebula CHARACTER SET latin1 COLLATE latin1_spanish_ci;"`

            rc = @one_test.upgrade_db
        end

        expect(rc).to eq(true)

        rc = @one_test.start_one

        expect(rc).to eq(true)

        share_version_up, local_version_up = @one_test.version_db

        expect(Gem::Version.new(@local_version)).to be < (Gem::Version.new(local_version_up))
        expect(Gem::Version.new(@share_version)).to be < (Gem::Version.new(share_version_up))

        vm_xml = cli_action_xml("onevm show 60126 -x")

        expect(vm_xml["TEMPLATE/SNAPSHOT/NAME"]).to eq("snapshot-0")
        expect(vm_xml["SNAPSHOTS/SNAPSHOT[ID=0]/NAME"]).to eq("snap-disk")
    end

    it "should check that the network contains BRIDGE_TYPE attribute" do
        n_xml = cli_action_xml("onevnet show -x 2")
        expect(n_xml['BRIDGE_TYPE']).not_to eq(nil)
    end

    it "should read template with utf8 characters" do
        template_name="centos7"
        xml = cli_action_xml("onetemplate show -x '#{template_name}'", true)
        expect(xml.class).to be(OpenNebula::XMLElement)

        description_template = "ÁÉÍÓÚáéíóúÀÈÌÒÙàèìòùÑñ"
        expect(xml["TEMPLATE/DESCRIPTION"]).to eq(description_template)
    end

    it "should check that the VM contains BRIDGE_TYPE for the NIC" do
        vm_id = cli_create("onevm create --name upgrade_test --cpu 1 --memory 1 --nic 2")
        vm_xml = cli_action_xml("onevm show -x #{vm_id}")
        expect(vm_xml['/VM/TEMPLATE/NIC/BRIDGE_TYPE']).not_to eq(nil)
    end

    it "should check oneuser list/show" do
        cli_action('oneuser list')

        cli_action('oneuser show')
    end

    it "should check oneimage list/show" do
        cli_action('oneimage list')

        cli_action('oneimage show 6')
    end

    it "should check onehost list/show" do
        cli_action('onehost list')

        cli_action('onehost show 0')
    end

    it "should check onemarket list/show" do
        cli_action('onemarket list')

        cli_action('onemarket show 0')
    end

    it "should check onemarketapp list/show" do
        cli_action('onemarketapp list')

        cli_action('onemarketapp show 0')
    end

    it "should check onevm list/show" do
        cli_action('onevm list')

        cli_action('onevm list -x')

        cli_action('onevm list -x --extended')

        cli_action('onevm show 40638')
    end

    it "should check onevnet list/show" do
        cli_action('onevnet list')

        cli_action('onevnet show 1')
    end

    it "should check onedatastore list/show" do
        cli_action('onedatastore list')

        cli_action('onedatastore show 1')
    end

    it "should check that vn_template_pool table is defined" do
        cli_action("onevntemplate list")
    end

    it "should find a VM using search option" do
        if @version > Gem::Version.new("5.6")
            xml  = cli_action_xml('onevm list -x --search "VM.NAME=upgrade_test"')

            name = xml["//VM/NAME"]

            expect(name).to eq("upgrade_test")
        end
    end

    it "should check logdb fields type" do
        types = `mysql -u oneadmin -popennebula opennebula -Be "select data_type from information_schema.columns \
                   where table_schema = 'opennebula' and table_name = 'logdb' and column_name like '%_index';" \
                 | tail -n +2`.split("\n")

        types.each do |type|
            expect(type).to eq("bigint")
        end
    end

    it "should check that raft status information is only in system_attributes table" do
        raft_status = `mysql -u oneadmin -popennebula opennebula -Be "select * from logdb where sqlcmd like '%<TEMPLATE>%';"`
        expect(raft_status).to be_empty

        raft_status = `mysql -u oneadmin -popennebula opennebula -Be "select * from system_attributes where name = 'RAFT_STATE';"`
        expect(raft_status).not_to be_empty
    end

    it "should check that -1s values are replaced by UINT64_MAX" do
        fed_index = `mysql -u oneadmin -popennebula opennebula -B -e "SELECT fed_index \
                     FROM logdb WHERE log_index = 1" | tail -n +2`

        expect(fed_index.chomp).to eq("18446744073709551615")
    end

    it 'should check hook_pool table is created' do
        cli_action("onehook list")
    end

    it 'should check images have FORMAT attribute defined' do
        ipool_xml = cli_action_xml("oneimage list -x")

        ipool_xml.retrieve_xmlelements("/IMAGE_POOL/IMAGE/ID").each do |i|
            cli_action("oneimage show #{i.text}")
        end
    end

    it 'should show VM with local characters' do
        xml = cli_action_xml('onevm show 0 -x')

        expect(xml["USER_TEMPLATE/DESCRIPTION"]).to eq('les problèmes')
    end

    it "should check onebackupjob list" do
        cli_action('onebackupjob list')
    end
end
