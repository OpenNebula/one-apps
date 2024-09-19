#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
require 'VN'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "VirtualNetwork AR reservation functionality" do

    DEFAULT_LIMIT = "-1"

    def test(xml, xpath, str)
        expect(xml[xpath]).to eq(str)
    end

    def check_reservation(i, name, ip, size, pid, dns="9.9.9.9")
        vnet = cli_action_xml("onevnet show -x #{name}")

        test(vnet, 'TEMPLATE/BRIDGE', "br0")
        test(vnet, 'TEMPLATE/GATEWAY', "1.1.1.1")
        test(vnet, 'PARENT_NETWORK_ID', "0")
        test(vnet, "AR_POOL/AR[AR_ID=\"#{i}\"]/TYPE", "IP4")
        test(vnet, "AR_POOL/AR[AR_ID=\"#{i}\"]/IP", "#{ip}")
        test(vnet, "AR_POOL/AR[AR_ID=\"#{i}\"]/SIZE", "#{size}")
        test(vnet, "AR_POOL/AR[AR_ID=\"#{i}\"]/DNS", dns)
        test(vnet, "AR_POOL/AR[AR_ID=\"#{i}\"]/PARENT_NETWORK_AR_ID", "#{pid}")
    end

    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        template=<<-EOF
         NAME   = "sip4"
         BRIDGE = br0
         PHYDEV = eth0
         VN_MAD = 802.1Q
         VLAN_ID= 13
         DNS    = "8.8.8.8"
         GATEWAY= "1.1.1.1"
         VLAN_TAGGED_ID = 12
         AR = [ TYPE="IP4", SIZE="250", IP="192.168.0.1", DNS="9.9.9.9",
                web="2.2.2.2" ]
         AR = [ TYPE="IP4", SIZE="250", IP="10.0.0.1"]
         AR = [ TYPE="IP6_STATIC", SIZE="250", IP6="2001:a:b:c::1",
                PREFIX_LENGTH=48 ]
        EOF

        vn = VN.create(template)
        vn.ready?

        #Create gaps in the address range
        20.times {
            cli_create("onevm create --name vm1 --cpu 1 --memory 128"\
                       " --nic sip4")
        }

        cli_action("onevm terminate 0") #192.168.0.1
        cli_action("onevm terminate 3") #192.168.0.4
        cli_action("onevm terminate 4") #192.168.0.5
        cli_action("onevm terminate 8") #192.168.0.9
        cli_action("onevm terminate 9") #192.168.0.10
        cli_action("onevm terminate 10") #192.168.0.11
        cli_action("onevm terminate 11") #192.168.0.12
        cli_action("onevm terminate 12") #192.168.0.13
        cli_action("onevm terminate 13") #192.168.0.14

        cli_create_user("uA", "abc")
        cli_create_user("uB", "abc")
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    it "should reserve a continuos ranges any where and deal with gaps" do
        cli_action("onevnet reserve 0 -n r1 -s 2")
        cli_action("onevnet reserve 0 -n r2 -s 6")
        cli_action("onevnet reserve 0 -n r3 -s 1")
        cli_action("onevnet reserve 0 -n r4 -s 20")
        cli_action("onevnet reserve 0 -n r5 -s 240")

        check_reservation(0, "r1", "192.168.0.4", "2", 0)
        check_reservation(0, "r2", "192.168.0.9", "6", 0)
        check_reservation(0, "r3", "192.168.0.1", "1", 0 )
        check_reservation(0, "r4", "192.168.0.21", "20", 0)
        check_reservation(0, "r5", "10.0.0.1", "240", 1, nil)

        xml = cli_action_xml("onevnet show -x sip4")

        test(xml,'AR_POOL/AR[AR_ID="0"]/USED_LEASES',"40")

        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.2"]/VM', "1")

        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.3"]/VM', "2")
        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.4"]/VNET', "1")
        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.5"]/VNET', "1")
        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.6"]/VM', "5")

        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.8"]/VM', "7")
        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.9"]/VNET', "2")
        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.14"]/VNET', "2")
        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.15"]/VM', "14")

        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.1"]/VNET', "3")

        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.20"]/VM', "19")
        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.21"]/VNET', "4")
        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.40"]/VNET', "4")

        test(xml,'AR_POOL/AR[AR_ID="1"]/USED_LEASES', "240")
        test(xml,'AR_POOL/AR[AR_ID="1"]/LEASES/LEASE[IP="10.0.0.1"]/VNET', "5")
        test(xml,'AR_POOL/AR[AR_ID="1"]/LEASES/LEASE[IP="10.0.0.240"]/VNET', "5")

        test(xml,'USED_LEASES', "280")
    end

    it "should reserve a continuos ranges in IPv6 ranges" do
        cli_action("onevnet reserve 0 -a 2  -n ripv6 -s 10")

        vnet = cli_action_xml("onevnet show -x ripv6")

        test(vnet, "AR_POOL/AR[AR_ID=\"0\"]/TYPE", "IP6_STATIC")
        test(vnet, "AR_POOL/AR[AR_ID=\"0\"]/IP6", "2001:a:b:c::1")
        test(vnet, "AR_POOL/AR[AR_ID=\"0\"]/PREFIX_LENGTH", "48")
        test(vnet, "AR_POOL/AR[AR_ID=\"0\"]/SIZE", "10")
        test(vnet, "AR_POOL/AR[AR_ID=\"0\"]/PARENT_NETWORK_AR_ID", "2")

        xml = cli_action_xml("onevnet show -x sip4")

        test(xml,'AR_POOL/AR[AR_ID="2"]/USED_LEASES',"10")

        test(xml,'AR_POOL/AR[AR_ID="2"]/LEASES/LEASE[IP6="2001:a:b:c::1"]/VNET',
             "6")
        test(xml,'AR_POOL/AR[AR_ID="2"]/LEASES/LEASE[IP6="2001:a:b:c::a"]/VNET',
             "6")
    end

    it "should recover VNETs and reservations from DB" do
        @one_test.stop_one
        @one_test.start_one

        check_reservation(0, "r1", "192.168.0.4", "2", 0)
        check_reservation(0, "r2", "192.168.0.9", "6", 0)
        check_reservation(0, "r3", "192.168.0.1", "1", 0)
        check_reservation(0, "r4", "192.168.0.21", "20", 0)
        check_reservation(0, "r5", "10.0.0.1", "240",1,nil)

        xml = cli_action_xml("onevnet show -x sip4")

        test(xml,'AR_POOL/AR[AR_ID="0"]/USED_LEASES',"40")

        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.2"]/VM', "1")

        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.3"]/VM', "2")
        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.4"]/VNET', "1")
        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.5"]/VNET', "1")
        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.6"]/VM', "5")

        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.8"]/VM', "7")
        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.9"]/VNET', "2")
        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.14"]/VNET', "2")
        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.15"]/VM', "14")

        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.1"]/VNET', "3")

        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.20"]/VM', "19")
        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.21"]/VNET', "4")
        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.40"]/VNET', "4")

        test(xml,'AR_POOL/AR[AR_ID="1"]/USED_LEASES', "240")
        test(xml,'AR_POOL/AR[AR_ID="1"]/LEASES/LEASE[IP="10.0.0.1"]/VNET', "5")
        test(xml,'AR_POOL/AR[AR_ID="1"]/LEASES/LEASE[IP="10.0.0.240"]/VNET', "5")

        test(xml,'USED_LEASES', "290")
    end

    it "should check that reservations can be used" do
        vm_id = cli_create("onevm create --name vm1 --cpu 1 --memory 128"\
                   " --nic r4")

        vm_xml = cli_action_xml("onevm show -x #{vm_id}")

        test(vm_xml,'TEMPLATE/NIC[1]/NETWORK',"r4")
        test(vm_xml,'TEMPLATE/NIC[1]/NETWORK_ID',"4")
        test(vm_xml,'TEMPLATE/NIC[1]/IP',"192.168.0.21")
        test(vm_xml,'TEMPLATE/NIC[1]/BRIDGE',"br0")
        test(vm_xml,'TEMPLATE/NIC[1]/PHYDEV',"eth0")
        test(vm_xml,'TEMPLATE/NIC[1]/VLAN_ID',"13")
        test(vm_xml,'TEMPLATE/NIC[1]/AR_ID',"0")

        cli_action("onevm terminate #{vm_id}")
    end

    it "should fail to reserve more addresses than available" do
        cli_action("onevnet reserve 0 -n r6 -s 440", false)
    end

    it "should fail to reserve with an existing reservation name" do
        cli_action("onevnet reserve 0 -n r1 -s 1", false)
    end

    it "should reserve from a given AR" do
        cli_action("onevnet reserve 0 -n r6 -s 2 -a 1")

        check_reservation(0, "r6", "10.0.0.241", "2", 1, nil)

        xml = cli_action_xml("onevnet show -x sip4")

        test(xml,'AR_POOL/AR[AR_ID="1"]/USED_LEASES',"242")

        test(xml,'AR_POOL/AR[AR_ID="1"]/LEASES/LEASE[IP="10.0.0.241"]/VNET',"8")
        test(xml,'AR_POOL/AR[AR_ID="1"]/LEASES/LEASE[IP="10.0.0.242"]/VNET',"8")

        test(xml,'USED_LEASES',"292")
    end

    it "should free all reservations" do
        cli_action("onevnet delete r1")
        cli_action("onevnet delete r2")
        cli_action("onevnet delete r3")
        cli_action("onevnet delete r4")
        cli_action("onevnet delete r5")
        cli_action("onevnet delete r6")

        vn = VN.new('ripv6')
        vn.delete
        vn.deleted?

        vnet_xml = cli_action_xml("onevnet show -x sip4")

        test(vnet_xml,'AR_POOL/AR[AR_ID="0"]/USED_LEASES',"11")
        test(vnet_xml,'AR_POOL/AR[AR_ID="1"]/USED_LEASES',"0")
        test(vnet_xml,'AR_POOL/AR[AR_ID="2"]/USED_LEASES',"0")

        test(vnet_xml,'USED_LEASES',"11")
    end

    it "should reserve a continuos range from a given address" do
        cli_action("onevnet reserve 0 -n r1 -s 5 -a 0 -i 192.168.0.57")
        cli_action("onevnet reserve 0 -n r2 -s 10 -a 1 -m 00:03:0a:00:00:0d")
        cli_action("onevnet reserve 0 -n r3 -s 10 -a 2 -6 2001:a:b:c::5")

        check_reservation(0, "r1", "192.168.0.57", "5",0)
        check_reservation(0, "r2", "10.0.0.13", "10", 1, nil)

        xml = cli_action_xml("onevnet show -x sip4")

        test(xml,'AR_POOL/AR[AR_ID="0"]/USED_LEASES',"16")
        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.57"]/VNET',"9")
        test(xml,'AR_POOL/AR[AR_ID="0"]/LEASES/LEASE[IP="192.168.0.61"]/VNET',"9")

        test(xml,'AR_POOL/AR[AR_ID="1"]/USED_LEASES',"10")
        test(xml,'AR_POOL/AR[AR_ID="1"]/LEASES/LEASE[IP="10.0.0.13"]/VNET',"10")
        test(xml,'AR_POOL/AR[AR_ID="1"]/LEASES/LEASE[IP="10.0.0.22"]/VNET',"10")

        test(xml,'AR_POOL/AR[AR_ID="2"]/USED_LEASES',"10")
        test(xml,'AR_POOL/AR[AR_ID="2"]/LEASES/LEASE[IP6="2001:a:b:c::5"]/VNET',
             "11")
        test(xml,'AR_POOL/AR[AR_ID="2"]/LEASES/LEASE[IP6="2001:a:b:c::e"]/VNET',
             "11")

        test(xml,'USED_LEASES',"36")
    end

    it "it should fail to make an ip-based reservation without AR_ID" do
        cli_action("onevnet reserve 0 -n r1_f -s 5 -i 192.168.0.57", false)
    end

    it "it should fail to make an mac-based reservation with a wrong MAC" do
        cli_action("onevnet reserve 0 -n r2_f -s 10 -a 1 -m rtw.re.re", false)
    end

    it "should add reservations to an existing reservation VNET" do
        cli_action("onevnet reserve 0 r1 -s 10 -a 1 -i 10.0.0.23")

        check_reservation(0, "r1", "192.168.0.57", "5",0)
        check_reservation(1, "r1", "10.0.0.23", "10", 1, nil)

        vnet_xml = cli_action_xml("onevnet show -x sip4")

        test(vnet_xml,'AR_POOL/AR[AR_ID="1"]/USED_LEASES',"20")
        test(vnet_xml,'AR_POOL/AR[AR_ID="1"]/LEASES/LEASE[IP="10.0.0.23"]/VNET',"9")
        test(vnet_xml,'AR_POOL/AR[AR_ID="1"]/LEASES/LEASE[IP="10.0.0.32"]/VNET',"9")

        test(vnet_xml,'USED_LEASES',"46")
    end

    it "should not add reservations to an existing reservation VNET from a different parent VNET" do
        template=<<-EOF
         NAME   = "sip42"
         BRIDGE = br0
         PHYDEV = eth0
         VN_MAD = 802.1Q
         VLAN_ID= 14
         AR = [ TYPE="IP4", SIZE="250", IP="172.16.0.1" ]
        EOF

        ip4_id = cli_create("onevnet create", template)
        cli_action("onevnet reserve sip42 r1 -s 10", false)
    end

    it "should fail to add reservations to a non-reservation nets" do
        cli_action("onevnet reserve sip42 sip4 -s 10", false)
    end

    it "should fail to add reservations to non-existent nets" do
        cli_action("onevnet reserve sip42 54 -s 10", false)
        cli_action("onevnet reserve 100 r1 -s 10", false)

        cli_action("onevnet delete r1")
        cli_action("onevnet delete r2")
        cli_action("onevnet delete r3")

        @one_test.stop_one
        @one_test.start_one

        vnet_xml = cli_action_xml("onevnet show -x sip4")

        test(vnet_xml,'AR_POOL/AR[AR_ID="0"]/USED_LEASES',"11")
        test(vnet_xml,'AR_POOL/AR[AR_ID="1"]/USED_LEASES',"0")

        test(vnet_xml,'USED_LEASES',"11")
    end

    it "should not allow to make double reservations" do
        cli_action("onevnet reserve 0 -n r1 -s 5")
        cli_action("onevnet reserve r1 -n r2 -s 5", false)

        net = VN.new('r1')
        net.state?("READY")

        net.delete
        net.deleted?

        vnet_xml = cli_action_xml("onevnet show -x sip4")

        test(vnet_xml,'AR_POOL/AR[AR_ID="0"]/USED_LEASES',"11")
        test(vnet_xml,'AR_POOL/AR[AR_ID="1"]/USED_LEASES',"0")

        test(vnet_xml,'USED_LEASES',"11")
    end

    it "should make a reservation as a user and add more reservations to it" do
        cli_action("onevnet chmod sip4 644")

         as_user("uA") do

            cli_action("onevnet reserve sip4 -n r1_ua -s 5 -a 0 -i 192.168.0.57")
            check_reservation(0, "r1_ua", "192.168.0.57", "5", 0)

            vnet_xml = cli_action_xml("onevnet show -x r1_ua")

            test(vnet_xml,'UNAME',"uA")
            test(vnet_xml,'GNAME',"users")

            uxml = cli_action_xml("oneuser show -x")

            test(uxml,"NETWORK_QUOTA/NETWORK[ID='0']/LEASES", DEFAULT_LIMIT)
            test(uxml,"NETWORK_QUOTA/NETWORK[ID='0']/LEASES_USED", "5")

            cli_action("onevnet reserve sip4 r1_ua -s 5")

            check_reservation(1, "r1_ua", "192.168.0.9", "5", 0)

            uxml = cli_action_xml("oneuser show -x")

            test(uxml,"NETWORK_QUOTA/NETWORK[ID='0']/LEASES", DEFAULT_LIMIT)
            test(uxml,"NETWORK_QUOTA/NETWORK[ID='0']/LEASES_USED", "10")

            cli_action("onevnet free r1_ua 1")

            uxml = cli_action_xml("oneuser show -x")

            test(uxml,"NETWORK_QUOTA/NETWORK[ID='0']/LEASES", DEFAULT_LIMIT)
            test(uxml,"NETWORK_QUOTA/NETWORK[ID='0']/LEASES_USED", "5")

            vnet_xml = cli_action_xml("onevnet show -x sip4")

            test(vnet_xml,'AR_POOL/AR[AR_ID="0"]/USED_LEASES',"16")
            test(vnet_xml,'AR_POOL/AR[AR_ID="1"]/USED_LEASES',"0")

            test(vnet_xml,'USED_LEASES',"16")

            vnet_xml = cli_action_xml("onevnet show -x r1_ua")

            test(vnet_xml,'AR_POOL/AR[AR_ID="1"]', nil)

            cli_action("onevnet free r1_ua 0")

            @one_test.stop_one
            @one_test.start_one

            uxml = cli_action_xml("oneuser show -x")

            test(uxml,"NETWORK_QUOTA/NETWORK[ID='0']/LEASES", nil)
            test(uxml,"NETWORK_QUOTA/NETWORK[ID='0']/LEASES_USED", nil)

            vnet_xml = cli_action_xml("onevnet show -x sip4")

            test(vnet_xml,'AR_POOL/AR[AR_ID="0"]/USED_LEASES',"11")
            test(vnet_xml,'AR_POOL/AR[AR_ID="1"]/USED_LEASES',"0")

            test(vnet_xml,'USED_LEASES',"11")

            vnet_xml = cli_action_xml("onevnet show -x r1_ua")

            test(vnet_xml,'AR_POOL/AR[AR_ID="0"]', nil)
        end
    end

    it "should update and update_ar on a reservation as a user" do
        as_user("uA") do
            cli_action("onevnet reserve sip4 r1_ua -s 15 -a 0 -i 192.168.0.57")

            check_reservation(0, "r1_ua", "192.168.0.57", "15", 0)

            cli_update("onevnet update r1_ua","EXTRA1=EXTRA1\nEXTRA2=EXTRA2\n",true)

            cli_update("onevnet updatear r1_ua 0","AR=[ AR_ID=0, TYPE=IP4, EXTRA3=EXTRA3, DNS=\"9.9.9.9\" ]", false)
            vnet_xml = cli_action_xml("onevnet show -x r1_ua")

            test(vnet_xml,'TEMPLATE/EXTRA1',"EXTRA1")
            test(vnet_xml,'TEMPLATE/EXTRA2',"EXTRA2")
            test(vnet_xml,'AR_POOL/AR/EXTRA3',"EXTRA3")
        end
    end

    it "should fail to rm_ar and add_ar on a reservation as a user" do
        as_user("uA") do
            check_reservation(0, "r1_ua", "192.168.0.57", "15", 0)

            cli_action("onevnet addar r1_ua -s 128 -i 10.0.0.1", false)

            cli_action("onevnet rmar r1_ua 0", false)
        end
    end

    it "should update reservation owner quotas when adding new reservation" do

        cli_action("onevnet reserve sip4 r1_ua -s 15")

        uxml = cli_action_xml("oneuser show uA -x")

        test(uxml,"NETWORK_QUOTA/NETWORK[ID='0']/LEASES", DEFAULT_LIMIT)
        test(uxml,"NETWORK_QUOTA/NETWORK[ID='0']/LEASES_USED", "30")
    end

    it "should fail to free a non-reserved ar from reservation VNET" do
        cli_action("onevnet addar r1_ua -s 128 -i 10.0.0.1")

        vnet_xml = cli_action_xml("onevnet show -x r1_ua")

        test(vnet_xml,'TEMPLATE/BRIDGE',"br0")
        test(vnet_xml,'TEMPLATE/GATEWAY',"1.1.1.1")
        test(vnet_xml,'PARENT_NETWORK_ID',"0")
        test(vnet_xml,"AR_POOL/AR[AR_ID=\"2\"]/TYPE","IP4")
        test(vnet_xml,"AR_POOL/AR[AR_ID=\"2\"]/IP","10.0.0.1")
        test(vnet_xml,"AR_POOL/AR[AR_ID=\"2\"]/SIZE","128")
        test(vnet_xml,"AR_POOL/AR[AR_ID=\"2\"]/DNS", nil)
        test(vnet_xml,"AR_POOL/AR[AR_ID=\"2\"]/PARENT_NETWORK_AR_ID", nil)

        as_user("uA") do
            cli_action("onevnet free r1_ua 2")

            uxml = cli_action_xml("oneuser show uA -x")

            test(uxml,"NETWORK_QUOTA/NETWORK[ID='0']/LEASES", DEFAULT_LIMIT)
            test(uxml,"NETWORK_QUOTA/NETWORK[ID='0']/LEASES_USED", "30")
        end
    end

    it "should update quotas on chown a reservation" do
        cli_action("onevnet chown r1_ua uB")

        uxml = cli_action_xml("oneuser show uA -x")

        test(uxml,"NETWORK_QUOTA/NETWORK[ID='0']/LEASES", nil)
        test(uxml,"NETWORK_QUOTA/NETWORK[ID='0']/LEASES_USED", nil)

        uxml = cli_action_xml("oneuser show uB -x")

        test(uxml,"NETWORK_QUOTA/NETWORK[ID='0']/LEASES", DEFAULT_LIMIT)
        test(uxml,"NETWORK_QUOTA/NETWORK[ID='0']/LEASES_USED", "30")

        vn = VN.new('r1_ua')
        vn.delete
        vn.deleted?

        vnet_xml = cli_action_xml("onevnet show -x sip4")

        test(vnet_xml,'AR_POOL/AR[AR_ID="0"]/USED_LEASES',"11")
        test(vnet_xml,'AR_POOL/AR[AR_ID="1"]/USED_LEASES',"0")

        uxml = cli_action_xml("oneuser show uA -x")

        test(uxml,"NETWORK_QUOTA/NETWORK[ID='0']/LEASES", nil)
        test(uxml,"NETWORK_QUOTA/NETWORK[ID='0']/LEASES_USED", nil)

        uxml = cli_action_xml("oneuser show uB -x")

        test(uxml,"NETWORK_QUOTA/NETWORK[ID='0']/LEASES", nil)
        test(uxml,"NETWORK_QUOTA/NETWORK[ID='0']/LEASES_USED", nil)
    end
end

