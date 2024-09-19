require 'init_functionality'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Hook State test" do

    before(:all) do
        @template = <<-EOF
                        NAME = hook_dummy
                        TYPE = state
                        STATE= LOCK_CREATE
                        RESOURCE = NET
                        COMMAND = a_command.rb
                        ZZZZ = xxxx
        EOF

        @new_user = 'new_user'
        cli_create_user(@new_user, 'abc')

        cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy\nSAFE_DIRS=\"/\"", false)
        cli_update("onedatastore update system", "TM_MAD=dummy\nDS_MAD=dummy", false)

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
    it "should fails to create a new Hook without a state or with invalid one" do
        template = <<-EOF
                    NAME = hook_invalid_state
                    TYPE = state
                    COMMAND = a.rb
                    STATE = INVALID
                    RESOURCE = NET
        EOF

        cli_create("onehook create", template, false)

        template = <<-EOF
                    NAME = hook_no_state
                    TYPE = state
                    COMMAND = a.rb
                    RESOURCE = NET
        EOF

        cli_create("onehook create", template, false)
    end

    #---------------------------------------------------------------------------
    # Check update process (Don't remove mandatory values, override, append... )
    #---------------------------------------------------------------------------

    it "should fails to update a hook if any mandatory attribute is left" do
        hook_id = cli_create('onehook create', @template)

        tpl = Tempfile.new("")
        tpl.puts "AAAA=bbbb"
        tpl.close

        cli_action("onehook update #{hook_id} #{tpl.path}", false)

        xml = cli_action_xml("onehook show -x #{hook_id}")

        cli_action("onehook delete #{hook_id}")
    end

    it "should update a hook with append option" do
        hook_id = cli_create('onehook create', @template)

        tpl = Tempfile.new("")
        tpl.puts "AAAA=bbbb"
        tpl.close

        cli_action("onehook update -a #{hook_id} #{tpl.path}")

        xml = cli_action_xml("onehook show -x #{hook_id}")

        expect(xml["TEMPLATE/AAAA"]).to eq("bbbb")
        expect(xml["TEMPLATE/ZZZZ"]).to eq("xxxx")

        cli_action("onehook delete #{hook_id}")
    end

    it "check $TEMPLATE params is parsed correctly" do
        template = <<-EOF
                    NAME = hook
                    TYPE = state
                    COMMAND = "/$(which cat)"
                    STATE = READY
                    RESOURCE = NET
                    ARGUMENTS = "test $TEMPLATE"
                    ARGUMENTS_STDIN = yes
        EOF

        hook_id = cli_create('onehook create', template)

        sleep 1 # Prevent race condition failure

        vn_template=<<-EOF
            NAME   = "vnet_test"
            BRIDGE = br0
            VN_MAD = dummy
        EOF

        id = cli_create("onevnet create", vn_template)

        wait_hook(hook_id, 0)

        xml = cli_action_xml("onehook show -x #{hook_id}")

        stdout = Base64.decode64(xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDOUT"]).split(" ")
        stderr = xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDERR"]

        expect(stdout[0].strip).to eq("test")
        expect(Base64.decode64(stdout[1]).include?("<ID>#{id}</ID>")).to eq(true)
        expect(stderr).to eq("")

        cli_action("onehook delete #{hook_id}")
        cli_action("onevnet delete #{id}")
    end
end

