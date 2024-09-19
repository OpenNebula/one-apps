#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Security Group usage test" do
    def build_vm(extra)
        template=<<-EOF
            NAME = test_vm
            CPU  = 1
            MEMORY = 128
        EOF

        template << extra if !extra.empty?

        return template
    end

    def test_vm_sg(vm_xml, sgs, no_sgs)
        sgs.each do |id|
            r=vm_xml["TEMPLATE/SECURITY_GROUP_RULE[SECURITY_GROUP_ID=\"#{id}\""\
                   " and RULE_TYPE=\"inbound\"]/RANGE"]

            expect(r).to eq("#{id},22,53,80:900")

            r=vm_xml["TEMPLATE/SECURITY_GROUP_RULE[SECURITY_GROUP_ID=\"#{id}\""\
                   " and RULE_TYPE=\"outbound\"and AR_ID=\"0\"]/RANGE"]

            expect(r).to eq("#{id},22,53,80:900")

            r=vm_xml["TEMPLATE/SECURITY_GROUP_RULE[SECURITY_GROUP_ID=\"#{id}\""\
                   " and RULE_TYPE=\"outbound\"and AR_ID=\"1\"]/RANGE"]

            expect(r).to eq("#{id},22,53,80:900")
        end

        no_sgs.each do |id|
            r=vm_xml["TEMPLATE/SECURITY_GROUP_RULE[SECURITY_GROUP_ID=\"#{id}\"]/RANGE"]

            expect(r).to be_nil
        end
    end

    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        6.times do |i|
            range = "#{i+100},22,53,80:900"
            template =<<-EOF
             NAME = "sg#{i+100}"
             RULE = [ PROTOCOL="TCP", RANGE="#{range}", RULE_TYPE="inbound" ]
             RULE = [ PROTOCOL="TCP", RANGE="#{range}", RULE_TYPE="outbound",
                    NETWORK_ID="2" ]
            EOF

            cli_create("onesecgroup create", template)
        end

        template =<<-EOF
         NAME = "no_sg"
         VN_MAD = dummy
         BRIDGE = br
         AR = [ TYPE="IP4", SIZE="250", IP="10.0.0.1" ]
        EOF
        cli_create("onevnet create", template)

        template =<<-EOF
         NAME = "sg"
         SECURITY_GROUPS="100,101"
         VN_MAD = dummy
         BRIDGE = br
         AR = [ TYPE="IP4", SIZE="250", IP="10.0.0.1" ]
        EOF
        cli_create("onevnet create", template)

        template =<<-EOF
         NAME = "sg_ar"
         SECURITY_GROUPS="100,101"
         VN_MAD=dummy
         BRIDGE=br
         AR = [ TYPE="IP4", SIZE="250", IP="192.168.70.1", SECURITY_GROUPS="102,103"]
         AR = [ TYPE="IP4", SIZE="250", IP="192.168.75.1"]
        EOF

        cli_create("onevnet create", template)
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    it "should copy SG from vnet to VM" do
        vmid = cli_create("onevm create", build_vm("NIC = [ NETWORK=sg ]"))

        vm_xml = cli_action_xml("onevm show -x #{vmid}")
        sg = vm_xml["TEMPLATE/NIC/SECURITY_GROUPS"].split(",")

        expect(sg.include?("0")).to be(true)
        expect(sg.include?("100")).to be(true)
        expect(sg.include?("101")).to be(true)
        expect(sg.include?("102")).to be(false)
        expect(sg.include?("103")).to be(false)
        expect(sg.include?("104")).to be(false)
        expect(sg.include?("105")).to be(false)

        test_vm_sg(vm_xml, [100, 101], [102, 103, 104, 105])

        vmid = cli_create("onevm create", build_vm("NIC = [ NETWORK=no_sg ]"))

        vm_xml = cli_action_xml("onevm show -x #{vmid}")
        expect(vm_xml["TEMPLATE/NIC/SECURITY_GROUPS"]).to eq("0")
    end

    it "should copy SG from AR to VM" do
        vmid = cli_create("onevm create", build_vm(
            "NIC = [ NETWORK=sg_ar, IP=\"192.168.70.20\" ]"))

        vm_xml = cli_action_xml("onevm show -x #{vmid}")
        sg     = vm_xml["TEMPLATE/NIC/SECURITY_GROUPS"].split(",")

        expect(sg.include?("0")).to be(true)
        expect(sg.include?("100")).to be(true)
        expect(sg.include?("101")).to be(true)
        expect(sg.include?("102")).to be(true)
        expect(sg.include?("103")).to be(true)
        expect(sg.include?("104")).to be(false)
        expect(sg.include?("105")).to be(false)

        test_vm_sg(vm_xml, [100, 101, 102, 103], [104, 105])

        vmid = cli_create("onevm create", build_vm(
            "NIC = [ NETWORK=sg_ar, IP=\"192.168.75.20\" ]"))

        vm_xml = cli_action_xml("onevm show -x #{vmid}")
        sg     = vm_xml["TEMPLATE/NIC/SECURITY_GROUPS"].split(",")

        expect(sg.include?("0")).to be(true)
        expect(sg.include?("100")).to be(true)
        expect(sg.include?("101")).to be(true)
        expect(sg.include?("102")).to be(false)
        expect(sg.include?("103")).to be(false)
        expect(sg.include?("104")).to be(false)
        expect(sg.include?("105")).to be(false)

        test_vm_sg(vm_xml, [100, 101], [102, 103, 104, 105])
    end

    it "should copy SG from NIC" do
        vmid = cli_create("onevm create", build_vm(
            "NIC = [ NETWORK=sg_ar, IP=\"192.168.70.21\", "\
            "SECURITY_GROUPS=\"104,105\" ]"))

        vm_xml = cli_action_xml("onevm show -x #{vmid}")
        sg     = vm_xml["TEMPLATE/NIC/SECURITY_GROUPS"].split(",")

        expect(sg.include?("0")).to be(true)
        expect(sg.include?("100")).to be(true)
        expect(sg.include?("101")).to be(true)
        expect(sg.include?("102")).to be(true)
        expect(sg.include?("103")).to be(true)
        expect(sg.include?("104")).to be(true)
        expect(sg.include?("105")).to be(true)

        vmid = cli_create("onevm create", build_vm(
            "NIC = [ NETWORK=sg_ar, IP=\"192.168.75.21\", "\
            "SECURITY_GROUPS=\"104,105\" ]"))

        vm_xml = cli_action_xml("onevm show -x #{vmid}")
        sg     = vm_xml["TEMPLATE/NIC/SECURITY_GROUPS"].split(",")

        expect(sg.include?("0")).to be(true)
        expect(sg.include?("100")).to be(true)
        expect(sg.include?("101")).to be(true)
        expect(sg.include?("102")).to be(false)
        expect(sg.include?("103")).to be(false)
        expect(sg.include?("104")).to be(true)
        expect(sg.include?("105")).to be(true)

        test_vm_sg(vm_xml, [100, 101, 104, 105], [])
    end

    it "should attach/detach a SG to VM" do
        vmid = cli_create("onevm create", build_vm("NIC = [ NETWORK=sg ]"))

        vm_xml = cli_action_xml("onevm show -x #{vmid}")
        sg = vm_xml["TEMPLATE/NIC/SECURITY_GROUPS"].split(",")

        expect(sg.include?("0")).to be(true)
        expect(sg.include?("100")).to be(true)
        expect(sg.include?("101")).to be(true)
        expect(sg.include?("102")).to be(false)
        expect(sg.include?("103")).to be(false)
        expect(sg.include?("104")).to be(false)
        expect(sg.include?("105")).to be(false)

        test_vm_sg(vm_xml, [100, 101], [102, 103, 104, 105])

        # Attach SG
        cli_action("onevm sg-attach #{vmid} 0 102")

        vm_xml = cli_action_xml("onevm show -x #{vmid}")
        sg = vm_xml["TEMPLATE/NIC/SECURITY_GROUPS"].split(",")

        expect(sg.include?("0")).to be(true)
        expect(sg.include?("100")).to be(true)
        expect(sg.include?("101")).to be(true)
        expect(sg.include?("102")).to be(true)
        expect(sg.include?("103")).to be(false)
        expect(sg.include?("104")).to be(false)
        expect(sg.include?("105")).to be(false)

        test_vm_sg(vm_xml, [100, 101, 102], [103, 104, 105])

        # Detach SG
        cli_action("onevm sg-detach #{vmid} 0 102")

        vm_xml = cli_action_xml("onevm show -x #{vmid}")
        sg = vm_xml["TEMPLATE/NIC/SECURITY_GROUPS"].split(",")

        expect(sg.include?("0")).to be(true)
        expect(sg.include?("100")).to be(true)
        expect(sg.include?("101")).to be(true)
        expect(sg.include?("102")).to be(false)
        expect(sg.include?("103")).to be(false)
        expect(sg.include?("104")).to be(false)
        expect(sg.include?("105")).to be(false)

        test_vm_sg(vm_xml, [100, 101], [102, 103, 104, 105])
    end

    it "should fail to attach/detach SG with wrong parameters" do
        vmid = cli_create("onevm create", build_vm("NIC = [ NETWORK=sg ]"))

        # Attach
        cli_action("onevm sg-attach 123 0 102", false)       # wrong vm id
        cli_action("onevm sg-attach #{vmid} 123 102", false) # wrong nic id
        cli_action("onevm sg-attach #{vmid} 0 123", false)   # wrong sg id

        # Detach
        cli_action("onevm sg-detach 123 0 102", false)       # wrong vm id
        cli_action("onevm sg-detach #{vmid} 123 102", false) # wrong nic id
        cli_action("onevm sg-detach #{vmid} 0 123", false)   # wrong sg id
    end

    # it "should respect user rights for attach/detach SG" do
    #     # todo Give first user all right for all secgroups
    #     #      Creat
    # end
end

