require 'init_functionality'
require 'pry'

#-------------------------------------------------------------------------------
#---------------------------------------------------------------------------

RSpec.describe "Hook Execution test" do

    #---------------------------------------------------------------------------
    # Check execution process
    #---------------------------------------------------------------------------

    before(:all) do
        wait_loop {
            system('grep "Hooks successfully loaded" /var/log/one/onehem.log')
        }

        cli_action('oneuser create userA abc')
    end

    it "should execute a hook and check the STDOUT and STDERR" do
        template = <<-EOF
                    NAME = hook-1
                    TYPE = api
                    COMMAND = "/$(which ls) -l"
                    CALL = "one.user.passwd"
        EOF

        hook_id = cli_create('onehook create', template)

        sleep 1 # Prevent race condition failure

        cli_action('oneuser passwd userA abc')

        wait_hook(hook_id, 0)

        xml = cli_action_xml("onehook show -x #{hook_id}")

        stdout = xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDOUT"]
        stderr = xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDERR"]

        expect(stdout).to_not eq(nil)
        expect(stdout).to_not eq("")
        expect(stderr).to eq("")

        cli_action("onehook delete #{hook_id}")
    end

    it "should execute a hook which fails and check the STDOUT and STDERR" do
        template = <<-EOF
                    NAME = hook-2
                    TYPE = api
                    COMMAND = "/$(which ls) -l"
                    ARGUMENTS = noexists
                    CALL = "one.user.passwd"
        EOF

        hook_id = cli_create('onehook create', template)

        sleep 1 # Prevent race condition failure

        cli_action('oneuser passwd userA abc')

        wait_hook(hook_id, 0)

        xml = cli_action_xml("onehook show -x #{hook_id}")

        stdout = xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDOUT"]
        stderr = Base64.decode64(xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDERR"])

        expect(stdout).to eq("")
        expect(stderr.include?("noexists")).to eq(true)

        cli_action("onehook delete #{hook_id}")
    end

    it "should execute a hook passing params through STDIN" do
        template = <<-EOF
                    NAME = hook-3
                    TYPE = api
                    COMMAND = "/$(which cat)"
                    CALL = "one.user.passwd"
                    ARGUMENTS = "test output"
                    ARGUMENTS_STDIN = yes
        EOF

        hook_id = cli_create('onehook create', template)

        sleep 1 # Prevent race condition failure

        cli_action('oneuser passwd userA abc')

        wait_hook(hook_id, 0)

        xml = cli_action_xml("onehook show -x #{hook_id}")

        stdout = Base64.decode64(xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDOUT"])
        stderr = xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDERR"]

        expect(stdout.strip).to eq("test output")
        expect(stderr).to eq("")

        cli_action("onehook delete #{hook_id}")
    end

    it "should retry a hook execution" do
        template = <<-EOF
                    NAME = hook-4
                    TYPE = api
                    COMMAND = "/$(which ls) -l"
                    CALL = "one.user.passwd"
        EOF

        hook_id = cli_create('onehook create', template)

        sleep 1 # Prevent race condition failure

        cli_action('oneuser passwd userA abc')

        wait_hook(hook_id, 0)

        cli_action("onehook retry #{hook_id} 0")

        wait_hook(hook_id, 1)

        xml = cli_action_xml("onehook show -x #{hook_id}")

        stdout = xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{1}]//STDOUT"]
        stderr = xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{1}]//STDERR"]

        expect(stdout).to_not eq("")
        expect(stdout).to_not eq(nil)
        expect(stderr).to eq("")

        cli_action("onehook delete #{hook_id}")
    end

    it "should check log retention of hook executions" do
        template = <<-EOF
                    NAME = hook-5
                    TYPE = api
                    COMMAND = "/$(which ls) -l"
                    CALL = "one.user.passwd"
        EOF

        hook_id = cli_create('onehook create', template)

        25.times do
            cli_action('oneuser passwd userA abc')
        end

        wait_hook(hook_id, 24)

        xml = cli_action_xml("onehook show -x #{hook_id}")

        # 10 is the default number of LOG_RETENTION value in oned.conf
        expect(xml.to_hash["HOOK"]["HOOKLOG"]["HOOK_EXECUTION_RECORD"].size).to eq(20)

        cli_action("onehook delete #{hook_id}")
    end

end
