#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Umask test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        cli_create_user("a", "a")

        @tmpl = <<-EOF
        NAME = test
        CPU = 1
        MEMORY = 128
        EOF
    end

    after(:each) do
        cli_action("onetemplate delete test")
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    it "should check the default umask for users" do
        as_user("a") do
            cli_create("onetemplate create", @tmpl)

            expect(cli_action("onetemplate show test").stdout).to match(/OWNER *: um-/)
            expect(cli_action("onetemplate show test").stdout).to match(/GROUP *: ---/)
            expect(cli_action("onetemplate show test").stdout).to match(/OTHER *: ---/)
        end
    end

    it "should check the default umask for oneadmin" do    
        cli_create("onetemplate create", @tmpl)

        expect(cli_action("onetemplate show test").stdout).to match(/OWNER *: um-/)
        expect(cli_action("onetemplate show test").stdout).to match(/GROUP *: ---/)
        expect(cli_action("onetemplate show test").stdout).to match(/OTHER *: ---/)
    end

    it "should set the user mask to 137" do
        as_user("a") do
            cli_action("oneuser umask a 137")

            cli_create("onetemplate create", @tmpl)

            expect(cli_action("onetemplate show test").stdout).to match(/OWNER *: um-/)
            expect(cli_action("onetemplate show test").stdout).to match(/GROUP *: u--/)
            expect(cli_action("onetemplate show test").stdout).to match(/OTHER *: ---/)
        end
    end

    it "should unset the umask" do
        as_user("a") do
            cli_action("oneuser umask a 137")
            cli_action("oneuser umask a ''")

            cli_create("onetemplate create", @tmpl)

            expect(cli_action("onetemplate show test").stdout).to match(/OWNER *: um-/)
            expect(cli_action("onetemplate show test").stdout).to match(/GROUP *: ---/)
            expect(cli_action("onetemplate show test").stdout).to match(/OTHER *: ---/)
        end
    end

    it "should set the user mask to 131" do
        as_user("a") do
            cli_action("oneuser umask a 131")

            cli_create("onetemplate create", @tmpl)

            expect(cli_action("onetemplate show test").stdout).to match(/OWNER *: um-/)
            expect(cli_action("onetemplate show test").stdout).to match(/GROUP *: u--/)
            expect(cli_action("onetemplate show test").stdout).to match(/OTHER *: um-/)
        end
    end

    it "should set the user mask to 000 as a regular user, and check the "<<
        "admin rights are not granted" do
        as_user("a") do
            cli_action("oneuser umask a 000")

            cli_create("onetemplate create", @tmpl)

            expect(cli_action("onetemplate show test").stdout).to match(/OWNER *: um-/)
            expect(cli_action("onetemplate show test").stdout).to match(/GROUP *: um-/)
            expect(cli_action("onetemplate show test").stdout).to match(/OTHER *: um-/)
        end
    end

    it "should set the user mask to 000 as a oneadmin user, and check the "<<
        "admin rights are granted" do
        cli_action("oneuser umask oneadmin 000")

        cli_create("onetemplate create", @tmpl)

        expect(cli_action("onetemplate show test").stdout).to match(/OWNER *: uma/)
        expect(cli_action("onetemplate show test").stdout).to match(/GROUP *: uma/)
        expect(cli_action("onetemplate show test").stdout).to match(/OTHER *: uma/)
    end
end