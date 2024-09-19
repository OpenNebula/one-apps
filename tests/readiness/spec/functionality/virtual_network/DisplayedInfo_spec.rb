require 'init_functionality'
require 'opennebula_test'
require 'rubygems'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

describe "VirtualNetwork displayed information" do

    before(:all) do
        #Creating users and groups
        cli_create_user("uA", "abc")
        cli_create_user("uB", "abc")

        cli_create("onegroup create gA")
        cli_create("onegroup create gB")

        cli_action("oneuser chgrp uA gA")
        cli_action("oneuser chgrp uB gB")

        #Creating vnet
        vnet_tmpl = <<-EOF
        NAME = test_vnet
        BRIDGE = br0
        VN_MAD = bridge
        AR=[TYPE = "IP4", IP = "10.0.0.10", SIZE = "100" ]
        EOF

        @vnet_id = cli_create("onevnet create", vnet_tmpl)

        vr_template=<<-EOF
         NAME   = "vr_template"
         CONTEXT = [
            NETWORK = "yes" ]
          CPU = "1.0"
          GRAPHICS = [
            LISTEN = "0.0.0.0",
            TYPE = "vnc" ]
          MEMORY = "128"
          NIC_DEFAULT = [
            MODEL = "virtio" ]
          VCPU = "1"
          VROUTER = "yes"
        EOF

        as_user("uA") do
            @vr_tmpl_id = cli_create("onetemplate create", vr_template)
            @vr_id = cli_create("onevrouter create", vr_template)

            cli_action("onevrouter nic-attach #{@vr_id} -n #{@vnet_id} --float")
        end
    end

    it "User uA should see the vrouter when showing the vnet" do
        xml = nil

        as_user("uA") do
            xml  = cli_action_xml("onevnet show -x #{@vnet_id}")
        end

        vrouters = xml["//VNET/VROUTERS/ID"]
        leases   = xml["//VNET/AR_POOL/AR/LEASES//LEASE"]

        expect(vrouters).to eq(@vr_id.to_s)
        expect(leases).not_to eq(nil)
    end

    it "User uB should see the vrouter when showing the vnet" do
        xml = nil

        as_user("uB") do
            xml  = cli_action_xml("onevnet show -x #{@vnet_id}")
        end

        vrouters = xml["//VNET/VROUTERS/ID"]
        leases   = xml["//VNET/AR_POOL/AR/LEASES//LEASE"]

        expect(vrouters).to eq(nil)
        expect(leases).to eq(nil)
    end

    it "User oneadmin should see the vrouter when showing the vnet" do
        xml  = cli_action_xml("onevnet show -x #{@vnet_id}")

        vrouters = xml["//VNET/VROUTERS/ID"]
        leases   = xml["//VNET/AR_POOL/AR/LEASES//LEASE"]

        expect(vrouters).to eq(@vr_id.to_s)
        expect(leases).not_to eq(nil)
    end

end
