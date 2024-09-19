require 'init_functionality'
require 'pry'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Hook State test" do

    before(:all) do
        @template = <<-EOF
                        NAME = hook
                        TYPE = state
                        STATE = MONITORED
                        RESOURCE = HOST
                        REMOTE = NO
                        COMMAND = aa.rb
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

    it "should fails to create a new Hook without a resource or with invalid one" do
        template = <<-EOF
                    NAME = hook
                    TYPE = state
                    COMMAND = a.rb
                    STATE = CREATE
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
                    STATE = INVALID
                    RESOURCE = HOST
                    REMOTE = YES
        EOF

        cli_create("onehook create", template, false)

        template = <<-EOF
                    NAME = hook
                    TYPE = state
                    COMMAND = a.rb
                    REMOTE = YES
                    RESOURCE = HOST
        EOF

        cli_create("onehook create", template, false)
    end

    #---------------------------------------------------------------------------
    # Check update process (Don't remove mandatory values, override, append... )
    #---------------------------------------------------------------------------

    it "should update a hook but left mandatory attributes" do
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
                    STATE = INIT
                    RESOURCE = HOST
                    ARGUMENTS = "test $TEMPLATE"
                    ARGUMENTS_STDIN = yes
        EOF

        hook_id = cli_create('onehook create', template)

        sleep 1 # Prevent race condition failure

        host_id = cli_create("onehost create -v kvm -i kvm localhost")

        wait_hook(hook_id, 0)

        xml = cli_action_xml("onehook show -x #{hook_id}")

        stdout = Base64.decode64(xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDOUT"]).split(" ")
        stderr = xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDERR"]

        expect(stdout[0].strip).to eq("test")
        expect(Base64.decode64(stdout[1]).include?("<ID>#{host_id}</ID>")).to eq(true)
        expect(stderr).to eq("")

        cli_action("onehook delete #{hook_id}")
        cli_action("onehost delete #{host_id}")
    end

    it "check REMOTE attribute works correctly" do
        template = <<-EOF
                    NAME = hook
                    TYPE = state
                    COMMAND = "/$(which printenv)"
                    STATE = INIT
                    RESOURCE = HOST
                    REMOTE = yes
        EOF

        hook_id = cli_create('onehook create', template)

        sleep 1 # Prevent race condition failure

        host_id = cli_create("onehost create -v kvm -i kvm localhost")

        wait_loop(:success => /INIT|MONITORED/, :break => 'ERROR') do
            xml = cli_action_xml("onehost show #{host_id} -x")
            OpenNebula::Host::HOST_STATES[xml['STATE'].to_i]
        end

        wait_hook(hook_id, 0)

        xml = cli_action_xml("onehook show -x #{hook_id}")

        stdout = Base64.decode64(xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDOUT"])

        expect(stdout.include?("SSH_CLIENT")).to eq(true)

        cli_action("onehook delete #{hook_id}")
        cli_action("onehost delete #{host_id}")
    end
end

