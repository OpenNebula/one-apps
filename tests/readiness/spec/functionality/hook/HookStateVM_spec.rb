require 'init_functionality'
require 'pry'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Hook State test" do

    before(:all) do
        @template = <<-EOF
                        NAME = hook
                        TYPE = state
                        ON = CUSTOM
                        RESOURCE = VM
                        REMOTE = YES
                        COMMAND = aa.rb
                        ZZZZ = xxxx
                        STATE = PENDING
                        LCM_STATE = PROLOG
        EOF

        @new_user = 'new_user'
        cli_create_user(@new_user, 'abc')

        cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)
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

    it "should fails to create a new Hook without a resource or with invalid one" do
        template = <<-EOF
                    NAME = hook
                    TYPE = state
                    COMMAND = a.rb
                    ON = CREATE
                    RESOURCE = VNET
                    REMOTE = YES
        EOF

        cli_create("onehook create", template, false)

        template = <<-EOF
                    NAME = hook
                    TYPE = state
                    COMMAND = a.rb
                    REMOTE = YES
        EOF

        cli_create("onehook create", template, false)
    end

    it "should fails to create a new Hook without a state or with invalid one" do
        template = <<-EOF
                    NAME = hook
                    TYPE = state
                    COMMAND = a.rb
                    ON = INVALID
                    RESOURCE = VM
                    REMOTE = YES
        EOF

        cli_create("onehook create", template, false)

        template = <<-EOF
                    NAME = hook
                    TYPE = state
                    COMMAND = a.rb
                    REMOTE = YES
                    RESOURCE = VM
        EOF

        cli_create("onehook create", template, false)
    end

    it "should asks for a STATE and LCM_STATE if ON is set to CUSTOM" do
        template = <<-EOF
                    NAME = hook
                    TYPE = state
                    COMMAND = a.rb
                    ON = CUSTOM
                    RESOURCE = VM
                    REMOTE = YES
        EOF

        cli_create("onehook create", template, false)

        template = <<-EOF
                    NAME = hook
                    TYPE = state
                    COMMAND = a.rb
                    ON = CUSTOM
                    STATE = INIT
                    RESOURCE = VM
                    REMOTE = YES
        EOF

        cli_create("onehook create", template, false)

        template = <<-EOF
                    NAME = hook
                    TYPE = state
                    COMMAND = a.rb
                    ON = CUSTOM
                    LCM_STATE = PROLOG_FAILURE
                    RESOURCE = VM
                    REMOTE = YES
        EOF

        cli_create("onehook create", template, false)

        template = <<-EOF
                    NAME = hook
                    TYPE = state
                    COMMAND = a.rb
                    ON = CUSTOM
                    STATE = INVALID
                    LCM_STATE = INVALID
                    RESOURCE = VM
                    REMOTE = YES
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
                    ON = CUSTOM
                    STATE = PENDING
                    LCM_STATE = LCM_INIT
                    RESOURCE = VM
                    ARGUMENTS = "test $TEMPLATE"
                    ARGUMENTS_STDIN = yes
        EOF

        hook_id = cli_create('onehook create', template)

        sleep 1 # Prevent race condition failure

        vm_id = cli_create("onevm create --cpu 1 --memory 2 --name test")

        wait_hook(hook_id, 0)

        xml = cli_action_xml("onehook show -x #{hook_id}")

        stdout = Base64.decode64(xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDOUT"]).split(" ")
        stderr = xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDERR"]

        expect(stdout[0].strip).to eq("test")
        expect(Base64.decode64(stdout[1]).include?("<ID>#{vm_id}</ID>")).to eq(true)
        expect(stderr).to eq("")

        cli_action("onehook delete #{hook_id}")
        cli_action("onevm terminate --hard #{vm_id}")
    end

    it "check REMOTE attribute works correctly" do
        template = <<-EOF
                    NAME = hook
                    TYPE = state
                    COMMAND = "/$(which printenv)"
                    ON = PROLOG
                    RESOURCE = VM
                    REMOTE = yes
        EOF

        hook_id = cli_create('onehook create', template)

        host_id = cli_create("onehost create -v dummy -i dummy localhost")
        vm_id   = cli_create("onevm create --cpu 1 --memory 2 --name test")

        cli_action("onevm deploy #{vm_id} #{host_id}")

        # Wait for the hook event
        wait_loop()do
            xml = cli_action_xml("onevm show #{vm_id} -x")
            OpenNebula::VirtualMachine::LCM_STATE[xml['LCM_STATE'].to_i] == 'PROLOG' ||
            OpenNebula::VirtualMachine::LCM_STATE[xml['LCM_STATE'].to_i] == 'RUNNING'
        end

        # Wait for the hook execution record to be available
        wait_hook(hook_id, 0)

        xml = cli_action_xml("onehook show -x #{hook_id}")

        stdout = Base64.decode64(xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDOUT"])
        stderr = xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDERR"]

        expect(stdout.include?("SSH_CLIENT")).to eq(true)
        expect(stderr).to eq("")

        cli_action("onehook delete #{hook_id}")
        cli_action("onevm terminate --hard #{vm_id}")

        wait_loop()do
            xml = cli_action_xml("onevm show #{vm_id} -x")
            OpenNebula::VirtualMachine::VM_STATE[xml['STATE'].to_i] == 'DONE'
        end

        cli_action("onehost delete #{host_id}")
    end

end

