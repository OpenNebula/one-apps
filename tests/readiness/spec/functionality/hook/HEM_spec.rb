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

    before(:each) do
        template = <<-EOF
                    NAME = hook-1
                    TYPE = api
                    COMMAND = "/$(which ls) -l"
                    CALL = "one.user.passwd"
        EOF

        @hook_id = cli_create('onehook create', template)
    end

    it "should check that hook are reloaded after UPDATE" do

        tpl = Tempfile.new("")
        tpl.puts 'COMMAND = "/$(which echo) testing"'
        tpl.close

        cli_action("onehook update -a #{@hook_id} #{tpl.path}")

        sleep 2 # Prevent race condition failure

        cli_action('oneuser passwd userA abc')

        wait_hook(@hook_id, 0)

        xml = cli_action_xml("onehook show -x #{@hook_id}")

        stdout = Base64.decode64(xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDOUT"])
        stderr = xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDERR"]

        expect(stdout.strip).to eq("testing")
        expect(stderr).to eq("")

        cli_action("onehook delete #{@hook_id}")
    end

    it "should check that hook remains if deleted other hook for same event" do
        template = <<-EOF
                    NAME = hook-2
                    TYPE = api
                    COMMAND = "/$(which touch) /tmp/test-file"
                    CALL = "one.user.passwd"
        EOF

        hook_id = cli_create('onehook create', template)

        sleep 2 # Prevent race condition failure

        # Trigger hooks
        cli_action('oneuser passwd userA abc')

        # Check both hooks are executed
        wait_hook(@hook_id, 0)
        wait_hook(hook_id, 0)
        expect(system("rm /tmp/test-file")).to eq(true)

        # Delete the
        cli_action("onehook delete #{hook_id}")

        # Trigger hook again
        cli_action('oneuser passwd userA abc')

        # Check hook remains
        wait_hook(@hook_id, 1)

        # Check deleted hooks have not been triggered
        expect(system("rm /tmp/test-file")).to eq(false)

        cli_action("onehook delete #{@hook_id}")
    end

    it "should check that hook are reloaded after DELETE" do

        tpl = Tempfile.new("")
        tpl.puts 'COMMAND = "/$(which touch) /tmp/test-file"'
        tpl.close

        cli_action("onehook update -a #{@hook_id} #{tpl.path}")

        sleep 2 # Prevent race condition failure

        cli_action('oneuser passwd userA abc')

        wait_hook(@hook_id, 0)

        rc = system('ls -l /tmp/test-file')

        expect(rc).to eq(true)

        rc = system('rm /tmp/test-file')

        expect(rc).to eq(true)

        cli_action("onehook delete #{@hook_id}")

        cli_action('oneuser passwd userA abc')

        rc = system('ls -l /tmp/test-file')

        expect(rc).to eq(false)
    end

end
