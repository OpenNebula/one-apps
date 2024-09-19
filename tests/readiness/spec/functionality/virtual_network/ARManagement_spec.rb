#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
require 'VN'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "VirtualNetwork add/rm leases functionality" do
    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should add a new Address Range to an existing VirtualNetwork" do
        template=<<-EOF
         NAME   = "sip4"
         BRIDGE = br0
         VN_MAD = dummy
         AR = [ TYPE="IP4", SIZE="250", IP="192.168.0.1" ]
        EOF

        vn = VN.create(template)
        vn.ready?

        cli_action("onevnet addar #{vn.id} -s 128 -i 10.0.0.1")

        cli_action("onevnet addar #{vn.id} -s 256 -m 11:22:33:44:55:66")

        cli_action("onevnet addar #{vn.id} -s 512 -i 172.16.0.0 "\
                   "-g 2001:a:b:c:d::")

        cli_action("onevnet addar #{vn.id} -s 1024 -u fd01:a:b:: "\
                   "-g 2001:a:b:c:d::")

        cli_action("onevnet addar #{vn.id} -s 2048 -6 200e:6:1:5::1/48")

        cli_action("onevnet addar #{vn.id} -s 4096 -i 172.16.0.0 "\
                   "-6 200e:6:1:5::1/64")

        vnet_xml = vn.xml

        expect(vnet_xml['AR_POOL/AR[AR_ID="1"]/TYPE']).to eq("IP4")
        expect(vnet_xml['AR_POOL/AR[AR_ID="1"]/IP']).to eq("10.0.0.1")
        expect(vnet_xml['AR_POOL/AR[AR_ID="1"]/SIZE']).to eq("128")

        expect(vnet_xml['AR_POOL/AR[AR_ID="2"]/TYPE']).to eq("ETHER")
        expect(vnet_xml['AR_POOL/AR[AR_ID="2"]/MAC']).to eq("11:22:33:44:55:66")
        expect(vnet_xml['AR_POOL/AR[AR_ID="2"]/SIZE']).to eq("256")

        expect(vnet_xml['AR_POOL/AR[AR_ID="3"]/TYPE']).to eq("IP4_6")
        expect(vnet_xml['AR_POOL/AR[AR_ID="3"]/IP']).to eq("172.16.0.0")
        expect(vnet_xml['AR_POOL/AR[AR_ID="3"]/GLOBAL_PREFIX']).to eq("2001:a:b:c:d::")
        expect(vnet_xml['AR_POOL/AR[AR_ID="3"]/SIZE']).to eq("512")

        expect(vnet_xml['AR_POOL/AR[AR_ID="4"]/TYPE']).to eq("IP6")
        expect(vnet_xml['AR_POOL/AR[AR_ID="4"]/GLOBAL_PREFIX']).to eq("2001:a:b:c:d::")
        expect(vnet_xml['AR_POOL/AR[AR_ID="4"]/ULA_PREFIX']).to eq("fd01:a:b::")
        expect(vnet_xml['AR_POOL/AR[AR_ID="4"]/SIZE']).to eq("1024")

        expect(vnet_xml['AR_POOL/AR[AR_ID="5"]/TYPE']).to eq("IP6_STATIC")
        expect(vnet_xml['AR_POOL/AR[AR_ID="5"]/IP6']).to eq("200e:6:1:5::1")
        expect(vnet_xml['AR_POOL/AR[AR_ID="5"]/SIZE']).to eq("2048")
        expect(vnet_xml['AR_POOL/AR[AR_ID="5"]/PREFIX_LENGTH']).to eq("48")

        expect(vnet_xml['AR_POOL/AR[AR_ID="6"]/TYPE']).to eq("IP4_6_STATIC")
        expect(vnet_xml['AR_POOL/AR[AR_ID="6"]/IP6']).to eq("200e:6:1:5::1")
        expect(vnet_xml['AR_POOL/AR[AR_ID="6"]/IP']).to eq("172.16.0.0")
        expect(vnet_xml['AR_POOL/AR[AR_ID="6"]/SIZE']).to eq("4096")
        expect(vnet_xml['AR_POOL/AR[AR_ID="6"]/PREFIX_LENGTH']).to eq("64")
    end

    it "should delete an Address Range from an existing VirtualNetwork" do
        cli_action("onevnet rmar sip4 1")

        vnet_xml = cli_action_xml("onevnet show -x sip4")

        expect(vnet_xml['AR_POOL/AR[AR_ID="1"]/TYPE']).to be_nil

        cli_action("onevnet rmar sip4 6")
        cli_action("onevnet rmar sip4 5")
        cli_action("onevnet rmar sip4 4")
        cli_action("onevnet rmar sip4 3")
        cli_action("onevnet rmar sip4 2")
        cli_action("onevnet rmar sip4 0")

        vnet_xml = cli_action_xml("onevnet show -x sip4")

        expect(vnet_xml['AR_POOL/AR[AR_ID="6"]/TYPE']).to be_nil
        expect(vnet_xml['AR_POOL/AR[AR_ID="5"]/TYPE']).to be_nil
        expect(vnet_xml['AR_POOL/AR[AR_ID="4"]/TYPE']).to be_nil
        expect(vnet_xml['AR_POOL/AR[AR_ID="3"]/TYPE']).to be_nil
        expect(vnet_xml['AR_POOL/AR[AR_ID="2"]/TYPE']).to be_nil
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/TYPE']).to be_nil

        cli_action("onevnet addar sip4 -s 128 -i 10.0.0.1")

        vnet_xml = cli_action_xml("onevnet show -x sip4")

        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/IP']).to eq("10.0.0.1")
    end

    it "should fail to rm a non-existing Address Range" do
        cli_action("onevnet rmar sip4 15", false)
        cli_action("onevnet rmar sip4 4", false)
    end

    it "should update an existing Address Range" do
        cli_action("onevnet addar sip4 -s 128 -m 11:22:33:44:55:66")

        vnet_xml = cli_action_xml("onevnet show -x sip4")

        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/DNS']).to be_nil
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/GATEWAY']).to be_nil

        ar_str = <<-EOT
            AR = [
                AR_ID=0,
                DNS=192.4.4.4,
                GATEWAY=192.3.3.3
            ]
        EOT

        cli_update("onevnet updatear sip4 0", ar_str, false)

        vnet_xml = cli_action_xml("onevnet show -x sip4")

        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/DNS']).to eq("192.4.4.4")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/GATEWAY']).to eq("192.3.3.3")

        ar_str = <<-EOT
            AR = [
                AR_ID=0,
                DNS=4.4.4.4
            ]
        EOT

        cli_update("onevnet updatear sip4 0", ar_str, false)

        vnet_xml = cli_action_xml("onevnet show -x sip4")

        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/DNS']).to eq("4.4.4.4")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/GATEWAY']).to eq(nil)

        ar_str = <<-EOT
            AR = [
                AR_ID=0,
                SIZE=-5
            ]
        EOT

        cli_update("onevnet updatear sip4 0", ar_str, false, false)
    end

    it "should append information to an existing Address Range" do
        cli_action("onevnet addar sip4 -s 128 -m 11:22:33:44:55:66")

        ar_str = <<-EOT
            APPEND=1
        EOT

        cli_update("onevnet updatear sip4 0", ar_str, true)

        vnet_xml = cli_action_xml("onevnet show -x sip4")

        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/APPEND']).to eq("1")
    end

    it "should not delete AR with active leases" do
        cli_create("onevm create --name vm1 --cpu 1 --memory 128 --nic sip4")

        cli_action("onevnet rmar sip4 0", false)

        vnet_xml = cli_action_xml("onevnet show -x sip4")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]']).not_to be_nil
    end

    it "should delete AR with active leases with force option" do
        cli_action("onevnet rmar sip4 0 --force")

        vnet_xml = cli_action_xml("onevnet show -x sip4")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]']).to be_nil
    end

    it "should not add an incomplete or wrong Address Range" do
        cli_action("onevnet addar sip4 -i 10.0.0.1", false)
        cli_action("onevnet addar sip4 -s 3 -i 10.0-21?", false)
        cli_action("onevnet addar sip4 -s 3 -g 10.0.0.fe", false)
        cli_action("onevnet addar sip4 -s 3 -u 10.0.0.fe", false)
        cli_action("onevnet addar sip4 -s -3 -i 10.0.1.1", false)
    end

    it "should not create VirtualNetwork with negative size in Address Range" do
        template=<<-EOF
         NAME   = "sip5"
         BRIDGE = br0
         VN_MAD = dummy
         AR = [ TYPE="IP4", SIZE="-25", IP="192.168.1.1" ]
        EOF

        vn = VN.create(template)
        vn.error?
    end

    it "should create AddressRange with size > 2^32" do
        template=<<-EOF
            NAME   = "sip6"
            BRIDGE = br0
            VN_MAD = dummy
            AR = [ TYPE="IP6_STATIC",
                SIZE="14294967296",
                IP6="200e:7:1:5::1",
                PREFIX_LENGTH="48"
            ]
        EOF

        vn = VN.create(template)
        vn.ready?

        vnet_xml = vn.xml

        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/TYPE']).to eq("IP6_STATIC")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/IP6']).to eq("200e:7:1:5::1")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/IP6_END']).to eq("200e:7:1:5:0:3:540b:e400")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/SIZE']).to eq("14294967296")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/PREFIX_LENGTH']).to eq("48")

        cli_action("onevnet addar #{vn.id} -s 142949672960 -6 200e:6:1:5::1/48")

        vnet_xml = vn.xml

        expect(vnet_xml['AR_POOL/AR[AR_ID="1"]/TYPE']).to eq("IP6_STATIC")
        expect(vnet_xml['AR_POOL/AR[AR_ID="1"]/IP6']).to eq("200e:6:1:5::1")
        expect(vnet_xml['AR_POOL/AR[AR_ID="1"]/IP6_END']).to eq("200e:6:1:5:0:21:4876:e800")
        expect(vnet_xml['AR_POOL/AR[AR_ID="1"]/SIZE']).to eq("142949672960")
        expect(vnet_xml['AR_POOL/AR[AR_ID="1"]/PREFIX_LENGTH']).to eq("48")
    end

    it "should create AdressRange size from prefix" do
        template=<<-EOF
            NAME   = "sip7"
            BRIDGE = br0
            VN_MAD = dummy
            AR = [ TYPE="IP6_STATIC",
                IP6="200e:7:1:6::",
                PREFIX_LENGTH="72"
            ]
        EOF

        vn = VN.create(template)
        vn.ready?

        vnet_xml = vn.xml

        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/SIZE']).to eq((2**(128-72)).to_s)
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/IP6']).to eq("200e:7:1:6::")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/IP6_END']).to eq("200e:7:1:6:ff:ffff:ffff:ffff")

        # Update AR with prefix length <96
        cli_action("onevnet addar #{vn.id} -6 200e:6:1:5::5/92")

        vnet_xml = vn.xml

        expect(vnet_xml['AR_POOL/AR[AR_ID="1"]/SIZE']).to eq((2**(128-92)-5).to_s)
        expect(vnet_xml['AR_POOL/AR[AR_ID="1"]/IP6']).to eq("200e:6:1:5::5")
        expect(vnet_xml['AR_POOL/AR[AR_ID="1"]/IP6_END']).to eq("200e:6:1:5:0:f:ffff:ffff")

        # Update AR with longer prefix, which may corrupt the computed size
        cli_action("onevnet addar #{vn.id} -6 200e:5:1:4::1:0:1a/96")

        vnet_xml = vn.xml

        expect(vnet_xml['AR_POOL/AR[AR_ID="2"]/SIZE']).to eq((2**(128-96)-0x1a).to_s)
        expect(vnet_xml['AR_POOL/AR[AR_ID="2"]/IP6']).to eq("200e:5:1:4::1:0:1a")
        expect(vnet_xml['AR_POOL/AR[AR_ID="2"]/IP6_END']).to eq("200e:5:1:4:0:1:ffff:ffff")
    end

    it "should update AdressRange with huge size" do
        template=<<-EOF
            NAME   = "sip8"
            BRIDGE = br0
            VN_MAD = dummy
            AR = [ TYPE="IP6_STATIC",
                IP6="200e:7:1:7::1",
                PREFIX_LENGTH="120"
            ]
        EOF

        vn = VN.create(template)
        vn.ready?

        vnet_xml = vn.xml

        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/SIZE']).to eq((2**(128-120)-1).to_s)
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/IP6']).to eq("200e:7:1:7::1")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/IP6_END']).to eq("200e:7:1:7::ff")

        # Update AR size
        ar_template = <<-EOT
            AR = [
                AR_ID=0,
                SIZE=14294967296
            ]
        EOT

        cli_update("onevnet updatear #{vn.id} 0", ar_template, false)

        vnet_xml = vn.xml

        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/SIZE']).to eq("14294967296")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/PREFIX_LENGTH']).to eq("120")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/IP6']).to eq("200e:7:1:7::1")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/IP6_END']).to eq("200e:7:1:7:0:3:540b:e400")

        # Update AR prefix length, remove the size
        #   The SIZE remains unchanged, the updatear command does not recompute SIZE
        #   from the PREFIX_LENGTH attribute
        ar_template = <<-EOT
            AR = [
                AR_ID=0,
                SIZE="",
                PREFIX_LENGTH=96
            ]
        EOT

        cli_update("onevnet updatear #{vn.id} 0", ar_template, false)

        vnet_xml = vn.xml

        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/SIZE']).to eq("14294967296")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/PREFIX_LENGTH']).to eq("96")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/IP6']).to eq("200e:7:1:7::1")
        expect(vnet_xml['AR_POOL/AR[AR_ID="0"]/IP6_END']).to eq("200e:7:1:7:0:3:540b:e400")
    end
end

