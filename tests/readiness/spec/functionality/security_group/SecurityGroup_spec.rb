#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Security Group operations test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        @template = "NAME = SG\nATT1 = VAL1\nATT2 = VAL2"

        cli_create_user("uA1", "abc")
        cli_create_user("uA2", "abc")

        cli_action("oneacl create '* SECGROUP/* CREATE'")
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should create a new Security Group" do
        cli_create("onesecgroup create", @template)
        cli_action("onesecgroup show SG")
    end

    it "should create a new Template from XML" do
        xml = <<-EOT
<TEMPLATE>
    <NAME>xml_test</NAME>
    <RULE>
      <PROTOCOL><![CDATA[TCP]]></PROTOCOL>
      <RANGE><![CDATA[1000:2000]]></RANGE>
      <RULE_TYPE><![CDATA[inbound]]></RULE_TYPE>
    </RULE>
    <RULE>
      <PROTOCOL><![CDATA[TCP]]></PROTOCOL>
      <RANGE><![CDATA[1000:2000]]></RANGE>
      <RULE_TYPE><![CDATA[outbound]]></RULE_TYPE>
    </RULE>
    <RULE>
      <NETWORK_ID><![CDATA[0]]></NETWORK_ID>
      <PROTOCOL><![CDATA[ICMP]]></PROTOCOL>
      <RULE_TYPE><![CDATA[inbound]]></RULE_TYPE>
    </RULE>
</TEMPLATE>
        EOT

        cli_create("onesecgroup create", xml)
        cli_action("onesecgroup show xml_test")
    end

    it "should not create a SG with duplicates" do
      sg=<<-EOF
        NAME = duplicate

        RULE = [
            PROTOCOL = TCP,
            RULE_TYPE = inbound,
            RANGE = 1000:2000
        ]

        RULE = [
            PROTOCOL = TCP,
            RULE_TYPE = inbound,
            RANGE = 1000:2000
        ]

        RULE = [
            PROTOCOL= TCP,
            RULE_TYPE = outbound,
            RANGE = 1000:2000
        ]

        RULE = [
            PROTOCOL = ICMP,
            RULE_TYPE = inbound,
            NETWORK_ID = 0
        ]

        RULE = [
            PROTOCOL= TCP,
            RULE_TYPE = outbound,
            RANGE = 1000:2000
        ]
        EOF

        sgid   = cli_create("onesecgroup create", sg)
        sg_xml = cli_action_xml("onesecgroup show -x #{sgid}")
        rules  = sg_xml.retrieve_elements('//TEMPLATE/RULE')

        expect(rules.size).to eq(3)

        cli_update("onesecgroup update #{sgid}", sg, false)

        sg_xml = cli_action_xml("onesecgroup show -x #{sgid}")
        rules  = sg_xml.retrieve_elements('//TEMPLATE/RULE')

        expect(rules.size).to eq(3)
    end

    it "should try to create an existing Security Group and check the failure" do
        cli_create("onesecgroup create", @template, false)
    end

    it "should not create a Security Group (without NAME)" do
        cli_create("onesecgroup create", "ATT1 = VAL1\nATT2 = VAL2", false)
    end

    it "should edit dynamically an existing Security Group template" do
        sg_xml = cli_action_xml("onesecgroup show SG -x")

        expect(sg_xml['TEMPLATE/ATT1']).to eq("VAL1")
        expect(sg_xml['TEMPLATE/ATT2']).to eq("VAL2")

        sg_update = "ATT2 = NEW_VAL\nATT3 = VAL3\n"

        cli_update("onesecgroup update SG", sg_update, false)

        sg_xml = cli_action_xml("onesecgroup show SG -x")
        expect(sg_xml['TEMPLATE/ATT1']).to eq(nil)
        expect(sg_xml['TEMPLATE/ATT2']).to eq("NEW_VAL")
        expect(sg_xml['TEMPLATE/ATT3']).to eq("VAL3")
    end

    it "should edit dynamically an existing Security Group template in XML" do
        sg_update =<<-EOT
<TEMPLATE>
  <ATT1>new_att1_val</ATT1>
  <ATT3>new_att3_val</ATT3>
  <ATT4>new_att4_val</ATT4>
</TEMPLATE>
        EOT

        cli_update("onesecgroup update SG", sg_update, false)

        sg_xml = cli_action_xml("onesecgroup show SG -x")
        expect(sg_xml['TEMPLATE/ATT1']).to eql("new_att1_val")
        expect(sg_xml['TEMPLATE/ATT2']).to eql(nil)
        expect(sg_xml['TEMPLATE/ATT3']).to eql("new_att3_val")
        expect(sg_xml['TEMPLATE/ATT4']).to eql("new_att4_val")
    end

    it "should delete a Security Group and check that now it does not exist" do
        cli_action("onesecgroup delete SG")
        cli_action("onesecgroup show SG", false)
    end

    it "should not create two security groups with the same name & owner" do
        as_user "uA1" do
            cli_create("onesecgroup create", "NAME=duplicated_name")
            cmd = cli_create("onesecgroup create", "NAME=duplicated_name", false)

            expect(cmd.stderr).to match(/NAME is already taken/)
        end
    end

    it "should create two security groups with the same name & different owner" do
        as_user "uA1" do
            cli_create("onesecgroup create", "NAME=duplicated_name_2")
        end

        as_user "uA2" do
            cli_create("onesecgroup create", "NAME=duplicated_name_2")
        end
    end

    it "should not create SG range with port outside 0-65545" do
        sg=<<-EOF
          NAME = out_of_range

          RULE = [
              PROTOCOL = TCP,
              RULE_TYPE = inbound,
              RANGE = 1000:67890
          ]
          EOF

          sgid   = cli_create("onesecgroup create", sg, false)
      end
end

