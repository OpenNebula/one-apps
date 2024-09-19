#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
# ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
require 'VN'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe 'VirtualNetwork operations test' do
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__), 'defaults.yaml')
    end

    before(:all) do
        # backup vnet_create and vnet_delete action, break posible symlinks
        @dummy_c = "#{ONE_VAR_LOCATION}/remotes/vnm/dummy/vnet_create"
        @dummy_d = "#{ONE_VAR_LOCATION}/remotes/vnm/dummy/vnet_delete"

        FileUtils.mv(@dummy_c, "#{@dummy_c}.orig")
        FileUtils.mv(@dummy_d, "#{@dummy_d}.orig")

        File.open(@dummy_c, File::CREAT|File::TRUNC|File::RDWR, 0o744) do |f|
            f.write("#!/bin/bash\n")
            f.write("exit 0\n")
        end

        File.open(@dummy_d, File::CREAT|File::TRUNC|File::RDWR, 0o744) do |f|
            f.write("#!/bin/bash\n")
            f.write("exit 0\n")
        end

        @vn_template=<<-EOF
            NAME   = "vnet_state"
            BRIDGE = br0
            VN_MAD = dummy
        EOF

        @vn_id = -1
    end

    after(:each) do
        FileUtils.cp("#{@dummy_c}.orig", @dummy_c)
        FileUtils.cp("#{@dummy_d}.orig", @dummy_d)
    end

    def build_vnet
        template=<<-EOF
         NAME   = "all_net"
         BRIDGE = br0
         VN_MAD = dummy
         AR = [ TYPE="ETHER", SIZE="128", MAC="00:02:01:02:03:04" ]
         AR = [ TYPE="ETHER", SIZE="64" ]
         AR = [ TYPE="IP4", SIZE="250", IP="192.168.0.1" ]
         AR = [ TYPE="IP6", SIZE="512", ULA_PREFIX="fd00:0:0:1::",
                GLOBAL_PREFIX="2001::" ]
         AR = [ TYPE="IP4_6", SIZE="256", ULA_PREFIX="fd00:ef:ab:1::",
                GLOBAL_PREFIX="2001:0:a:b::", IP="10.0.0.0" ]
         AR = [ TYPE="IP6_STATIC", SIZE="512", IP6="2001:1:2:a:b::1",
                 PREFIX_LENGTH = 48 ]
         AR = [ TYPE="IP4_6_STATIC", SIZE="256" , IP6="2001:1:2:a:b::1",
                IP="10.0.0.0", PREFIX_LENGTH = 48 ]
        EOF
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it 'should create a non existing Virtual Network with stdin template and check all AR types' do
        @vn_id   = cli_create_stdin('onevnet create', build_vnet)
        vnet_xml = cli_action_xml("onevnet show -x #{@vn_id}")

        expect(vnet_xml['NAME']).to eq('all_net')
        expect(vnet_xml['BRIDGE']).to eq('br0')
    end

    it 'should create a new VirtualNetwork from XML' do
        xml_text = <<~EOF
            <TEMPLATE>
              <NAME>xml_test</NAME>
              <BRIDGE>br5</BRIDGE>
              <VN_MAD>dummy</VN_MAD>
              <AR><TYPE>IP4</TYPE><SIZE>12</SIZE><IP>192.168.3.8</IP></AR>
            </TEMPLATE>
        EOF

        id       = cli_create('onevnet create', xml_text)
        vnet_xml = cli_action_xml("onevnet show -x #{id}")

        expect(vnet_xml['NAME']).to eq('xml_test')
        expect(vnet_xml['BRIDGE']).to eq('br5')
    end

    it 'should not create a VirtualNetwork with the same name' do
        id = cli_create('onevnet create', build_vnet, false)
    end

    it 'should not create a VirtualNetwork without BRIDGE or PHYDEV' do
        id = cli_create('onevnet create', "NAME=fail\nVN_MAD=dummy\n", false)
    end

    it 'should not create a VirtualNetwork without VN_MAD' do
        id = cli_create('onevnet create', "NAME=fail\nBRIDGE=br\n", false)
    end

    it 'should not create a VirtualNetwork with an AR without IP' do
        template = <<-EOF
        NAME   = test_fail
        BRIDGE = br0
        VN_MAD = dummy
        AR = [ TYPE = "IP4", SIZE = "34" ]
        EOF
        vn = VN.create(template)
        vn.error?

        template = <<-EOF
        NAME   = test_fail2
        BRIDGE = br0
        VN_MAD = dummy
        AR = [ TYPE = "IP4_6", SIZE = "34", GLOBAL_PREFIX="2001::" ]
        EOF
        vn = VN.create(template)
        vn.error?
    end

    it 'should not create a VirtualNetwork with an AR without IP6' do
        template = <<-EOF
        NAME   = test_fail3
        BRIDGE = br0
        VN_MAD = dummy
        AR = [ TYPE = "IP6_STATIC", IP="34.12.23.3" ]
        EOF
        vn = VN.create(template)
        vn.error?

        template = <<-EOF
        NAME   = test_fail4
        BRIDGE = br0
        VN_MAD = dummy
        AR = [ TYPE = "IP4_6_STATIC", IP="34.12.23.3" ]
        EOF
        vn = VN.create(template)
        vn.error?
    end

    it 'should not create a VirtualNetwork with an AR without TYPE' do
        template = <<-EOF
        NAME   = test_fail5
        BRIDGE = br0
        VN_MAD = dummy
        AR = [ SIZE = "34", IP="34.12.23.3" ]
        EOF
        vn = VN.create(template)
        vn.error?
    end

    it 'should not create a VirtualNetwork with an AR with wrong IP' do
        template = <<-EOF
        NAME   = test_fail6
        BRIDGE = br0
        VN_MAD = dummy
        AR = [ TYPE="IP4", SIZE = "34", IP="if34.12.23.3" ]
        EOF
        vn = VN.create(template)
        vn.error?

        template = <<-EOF
        NAME   = test_fail7
        BRIDGE = br0
        VN_MAD = dummy
        AR = [ TYPE="IP4_6", SIZE = "34", IP="if34.12.23.3",
            GLOBAL_PREFIX="2001::" ]
        EOF
        vn = VN.create(template)
        vn.error?

        template = <<-EOF
        NAME   = test_fail8
        BRIDGE = br0
        VN_MAD = dummy
        AR = [ TYPE="IP6_STATIC", SIZE = "34", IP6="203a::1::2::3",
                 PREFIX_LENGTH = 48 ]
        EOF
        vn = VN.create(template)
        vn.error?
    end

    it 'should not create a VirtualNetwork with an AR with wrong prefix' do
        template = <<-EOF
        NAME   = test_fail9
        BRIDGE = br0
        VN_MAD = dummy
        AR = [ TYPE="IP6", SIZE = "34", ULA_PREFIX="203a::1::2::3" ]
        EOF
        vn = VN.create(template)
        vn.error?
    end

    it 'should create a VirtualNetwork and generate BRIDGE' do
        template = <<-EOF
        NAME    = test_br
        PHYDEV  = "eth0"
        VN_MAD  = 802.1Q
        VLAN_ID = 13
        EOF

        id = cli_create('onevnet create', template)
        vnet_xml = cli_action_xml("onevnet show -x #{id}")

        expect(vnet_xml['NAME']).to eq('test_br')
        expect(vnet_xml['BRIDGE']).to eq('onebr.13')
    end

    it 'should delete a VirtualNetwork without used leases' do
        cli_action('onevnet delete all_net')
        wait_loop do
            cmd = cli_action('onevnet show all_net', nil, true)
            cmd.fail?
        end
    end

    #+---------------+---------+--------+--------------------------+----------------+
    # |   Driver      | PHYDEV  | BRIDGE |         VLAN_ID          |      OTHER     |
    #+---------------+---------+--------+--------------------------+----------------+
    # |vcenter        | no      | yes    | no                       | VCENTER_NET_REF|
    # |dummy          | no      | yes    | no                       |                |
    # |bridge         | no      | no     | no                       |                |
    # |ebtables       | no      | no     | no                       |                |
    # |fw             | no      | no     | no                       |                |
    # |802.1q         | yes     | no     | yes or AUTOMATIC         |                |
    # |vxlan          | yes     | no     | yes or AUTOMATIC         |                |
    # |ovswitch       | no      | no     | yes or AUTOMATIC         |                |
    # |ovswitch_vxlan | yes     | no     | OUTER or AUTOMATIC_OUTER |                |
    #+---------------+---------+--------+--------------------------+----------------+
    it 'should check mandatory attributes' do
        next_id_fail = 0
        next_id = 0
        vn_mad_1 = ['dummy']
        vn_mad_2 = ['802.1Q', 'vxlan']
        vn_mad_3 = ['bridge', 'ebtables', 'fw', 'ovswitch']

        # dummy
        vn_mad_1.each do |mad|
            cli_create('onevnet create', "NAME=fail#{next_id_fail}\n
                VN_MAD=#{mad}\n", false)
            next_id_fail += 1

            cli_create('onevnet create', "NAME=notfail#{next_id}\n
                VN_MAD=#{mad}\nBRIDGE=br\n", true)
            next_id += 1
        end

        # bridge, ebtables, fw, ovswitch
        vn_mad_3.each do |mad|
            cli_create('onevnet create', "NAME=notfail#{next_id}\n
                VN_MAD=#{mad}\n", true)
            next_id += 1
        end

        # 802.1Q / vxlan
        vn_mad_2.each do |mad|
            cli_create('onevnet create', "NAME=fail#{next_id_fail}\nVN_MAD=#{mad}\n", false)
            next_id_fail += 1

            cli_create('onevnet create', "NAME=fail#{next_id_fail}\nVN_MAD=#{mad}\nPHYDEV=eth0\n",
                       false)
            next_id_fail += 1

            cli_create('onevnet create', "NAME=fail#{next_id_fail}\nVN_MAD=#{mad}\nVLAN_ID=0\n",
                       false)
            next_id_fail += 1

            cli_create('onevnet create',
                       "NAME=notfail#{next_id}\nVN_MAD=#{mad}\nVLAN_ID=0\nPHYDEV=eth0\n", true)
            next_id += 1

            cli_create('onevnet create',
                       "NAME=notfail#{next_id}\nVN_MAD=#{mad}\nAUTOMATIC_VLAN_ID=YES\nPHYDEV=eth0\n", true)
            next_id += 1
        end

        # ovswitch_vxlan
        cli_create('onevnet create', "NAME=fail#{next_id_fail}\n
            VN_MAD=ovswitch_vxlan\n", false)
        next_id_fail += 1

        cli_create('onevnet create', "NAME=notfail#{next_id_fail}\n
            VN_MAD=ovswitch_vxlan\nPHYDEV=eth0\n", false)
        next_id_fail += 1

        cli_create('onevnet create', "NAME=fail#{next_id}\n
            VN_MAD=ovswitch_vxlan\nPHYDEV=eth0\nOUTER_VLAN_ID=0\n", true)
        next_id += 1

        cli_create('onevnet create', "NAME=notfail#{next_id}\n
            VN_MAD=ovswitch_vxlan\nPHYDEV=eth0\nAUTOMATIC_OUTER_VLAN_ID=YES\n", true)
        next_id += 1
    end

    it 'should create/delete Virtual Network and check state' do
        vn = VN.create(@vn_template)
        vn.ready?

        vn.delete
        vn.deleted?
    end

    it 'should recover success from LOCK_DELETE' do
        File.write(@dummy_d, 'sleep 10; exit 1')

        vn = VN.create(@vn_template)
        vn.ready?

        vn.delete

        vn.state?('LOCK_DELETE', 'READY')

        cli_action("onevnet recover #{vn.id} --success")

        vn.deleted?
    end

    it 'should recover success from LOCK_CREATE' do
        File.write(@dummy_c, 'exit 1')

        vn = VN.create(@vn_template)
        vn.error?

        cli_action("onevnet recover #{vn.id} --success")

        vn.ready?

        vn.delete
        vn.deleted?
    end

    it 'should recover failure from LOCK_CREATE' do
        File.write(@dummy_c, 'sleep 10; exit 0')

        vn = VN.create(@vn_template)
        vn.state?('LOCK_CREATE', 'READY')

        cli_action("onevnet recover #{vn.id} --failure")

        vn.error?

        vn.delete
        vn.deleted?
    end
end
