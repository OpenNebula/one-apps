require 'init_functionality'
require 'pry'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Hook Generic test" do

    before(:all) do
        @template = <<-EOF
                        NAME = hook
                        TYPE = api
                        COMMAND = aa.rb
                        CALL = "one.zone.raftstatus"
                        REMOTE = YES
                        ZZZZ = xxxx
        EOF

        @new_user = 'new_user'
        cli_create_user(@new_user, 'abc')

        wait_loop {
            system('grep "Hooks successfully loaded" /var/log/one/onehem.log')
        }
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    #---------------------------------------------------------------------------
    # Check creation process (Default values, mandatory attributes...)
    #---------------------------------------------------------------------------

    it "should fails to create a new Hook without name" do
        template = <<-EOF
                    TYPE = api
                    COMMAND = aa.rb
                    CALL = "one.zone.raftstatus"
                    REMOTE = YES
        EOF

        cli_create("onehook create", template, false)
    end

    it "should fails to create a new Hook without TYPE or with invalid one" do
        template = <<-EOF
                    NAME = hook
                    TYPE = xxxx
                    COMMAND = aa.rb
                    CALL = "one.zone.raftstatus"
                    REMOTE = YES
        EOF

        cli_create("onehook create", template, false)

        template = <<-EOF
                    NAME = hook
                    COMMAND = aa.rb
                    CALL = "one.zone.raftstatus"
                    REMOTE = YES
        EOF

        cli_create("onehook create", template, false)
    end

    it "should fails to create a new Hook without command" do
        template = <<-EOF
                    NAME = hook
                    TYPE = api
                    CALL = "one.zone.raftstatus"
                    REMOTE = YES
        EOF

        cli_create("onehook create", template, false)
    end

    it "should set REMOTE to YES" do
        template = <<-EOF
                    NAME = hook
                    TYPE = STATE
                    COMMAND = a.rb
                    ON = "PROLOG"
                    RESOURCE = VM
                    REMOTE = YES
        EOF

        hook_id = cli_create('onehook create', template)

        xml = cli_action_xml("onehook show -x #{hook_id}")

        expect(xml["TEMPLATE/REMOTE"]).to eq("YES")

        cli_action("onehook delete #{hook_id}")
    end

    #---------------------------------------------------------------------------
    # Check rename
    #---------------------------------------------------------------------------

    it "should rename a hook" do
        hook_id = cli_create('onehook create', @template)

        cli_action("onehook rename #{hook_id} new_name")

        xml = cli_action_xml("onehook show -x #{hook_id}")

        expect(xml["NAME"]).to eq("new_name")

        cli_action("onehook delete #{hook_id}")
    end

    #---------------------------------------------------------------------------
    # Check lock/unlock
    #---------------------------------------------------------------------------

    it "should lock and unlock a hook" do
        hook_id = cli_create('onehook create', @template)

        cli_action("onehook lock #{hook_id} --use")
        expect(cli_action("onehook show #{hook_id}").stdout).to match(/Use/)

        cli_action("onehook unlock #{hook_id}")
        expect(cli_action("onehook show #{hook_id}").stdout).not_to match(/Use/)

        cli_action("onehook delete #{hook_id}")
    end

    #---------------------------------------------------------------------------
    # Check permissions
    #---------------------------------------------------------------------------

    it "a hook should not be managed by a non admin user" do
        hook_id = cli_create('onehook create', @template)
        cli_action("onehook rename #{hook_id} new_name")

        as_user "new_user" do
            cli_action("onehook show #{hook_id}", false)
            cli_action("onehook rename #{hook_id} name", false)
            cli_create("onehook create", @template, false)
        end

        cli_action("onehook delete #{hook_id}")
    end

end

