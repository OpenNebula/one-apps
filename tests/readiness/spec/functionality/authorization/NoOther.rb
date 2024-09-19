#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "ENABLE_OTHER_PERMISIONS=NO test" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults_noOther.yaml')
    end

    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        cli_create_user("userA", "passwordA")

        @template_1 = <<-EOF
            NAME = test_template
            CPU  = 1
            MEMORY = 128
        EOF
    end

    before(:each) do 
        as_user "userA" do
            @tid = cli_create("onetemplate create", @template_1)
        end
    end

    after(:each) do
        cli_action("onetemplate delete #{@tid}")
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    it "user should be able to modify permissions for user and group" do
        as_user "userA" do
            cli_action("onetemplate chmod #{@tid} 660")

        expect(cli_action("onetemplate show #{@tid}").stdout).to match(/OWNER *: um-/)
            expect(cli_action("onetemplate show #{@tid}").stdout).to match(/GROUP *: um-/)
            expect(cli_action("onetemplate show #{@tid}").stdout).to match(/OTHER *: ---/)
        end
    end

    it "user should not be able to modify permissions for other" do
        as_user "userA" do
            cli_action("onetemplate chmod #{@tid} 006", false)
        end
    end

    it "oneadmin should be able to set all permissions" do
        cli_action("onetemplate chmod #{@tid} 777")

        expect(cli_action("onetemplate show #{@tid}").stdout).to match(/OWNER *: uma/)
        expect(cli_action("onetemplate show #{@tid}").stdout).to match(/GROUP *: uma/)
        expect(cli_action("onetemplate show #{@tid}").stdout).to match(/OTHER *: uma/)
    end
end
