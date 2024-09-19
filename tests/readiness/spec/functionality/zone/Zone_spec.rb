#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Zone test" do
    #---------------------------------------------------------------------------
    # OpenNebula configuration
    #---------------------------------------------------------------------------
    before(:all) do
        @template = <<-EOF
            NAME   = test_name
            CPU    = 2
            MEMORU = 128
            ATT1   = "VAL1"
        EOF
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should start the oned in ENABLED mode" do
        xml = cli_action_xml("onezone show -x 0")

        expect(xml["STATE"]).to eq("0")
    end

    it "should disable zone" do
        cli_action("onezone disable 0")

        xml = cli_action_xml("onezone show -x 0")

        expect(xml["STATE"]).to eq("1")
    end

    it "should execute info requests in disabled state" do
        cli_action("oneuser list")
    end

    it "should not be able to create template in disabled state" do
        cli_create("onetemplate create", @template, false)
    end

    it "should enable the zone and create template" do
        cli_action("onezone enable 0")

        cli_create("onetemplate create", @template)
    end
end
