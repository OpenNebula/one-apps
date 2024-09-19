require 'init_functionality'
require 'pry'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Hook API test" do

    before(:all) do

        @template = <<-EOF
                        NAME = hook
                        TYPE = api
                        COMMAND = aa.rb
                        CALL = "one.zone.raftstatus"
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

    it "should fails to create a new Hook without a call or with invalid one" do
        template = <<-EOF
                    NAME = hook
                    TYPE = api
                    COMMAND = a.rb
                    CALL = "one.xxxx.info"
        EOF

        cli_create("onehook create", template, false)

        template = <<-EOF
                    NAME = hook
                    TYPE = api
                    COMMAND = a.rb
        EOF

        cli_create("onehook create", template, false)
    end

    #---------------------------------------------------------------------------
    # Check update process (Don't remove mandatory values, override, append... )
    #---------------------------------------------------------------------------

    it "should not update a hook without append option if some mandatory attribute is left" do
        hook_id = cli_create('onehook create', @template)

        tpl = Tempfile.new("")
        tpl.puts "AAAA=bbbb"
        tpl.close

        cli_action("onehook update #{hook_id} #{tpl.path}", false)

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

    it "check $API params is parsed correctly" do
        template = <<-EOF
                    NAME = hook-3
                    TYPE = api
                    COMMAND = "/$(which cat)""
                    CALL = "one.user.passwd"
                    ARGUMENTS = "test $API"
                    ARGUMENTS_STDIN = yes
        EOF

        hook_id = cli_create('onehook create', template)

        sleep 1 # Prevent race condition failure

        cli_action('oneuser passwd new_user abc')

        wait_hook(hook_id, 0)

        xml = cli_action_xml("onehook show -x #{hook_id}")

        stdout = Base64.decode64(xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDOUT"])
                       .split(" ")
        stderr = xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDERR"]

        expect(stdout[0].strip).to eq("test")
        expect(Base64.decode64(stdout[1]).include?("<PARAMETERS>")).to eq(true)
        expect(stderr).to eq("")

        cli_action("onehook delete #{hook_id}")
    end

    it "should get resource template on allocate and delete calls" do
        template_all = <<-EOF
                    NAME = hook-all
                    TYPE = api
                    COMMAND = "/$(which cat)"
                    CALL = "one.user.allocate"
                    ARGUMENTS = "$API"
                    ARGUMENTS_STDIN = yes
        EOF

        template_del = <<-EOF
                    NAME = hook-del
                    TYPE = api
                    COMMAND = "/$(which cat)"
                    CALL = "one.user.delete"
                    ARGUMENTS = "$API"
                    ARGUMENTS_STDIN = yes
        EOF

        hook_all = cli_create('onehook create', template_all)
        hook_del = cli_create('onehook create', template_del)

        # Check allocate call
        user_id = cli_create('oneuser create test-alloc abc')

        wait_hook(hook_all, 0)

        xml = cli_action_xml("onehook show -x -e 0 #{hook_all}")

        stdout = Base64.decode64(xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDOUT"])
        stdout_xml = Nokogiri::XML(Base64.decode64(stdout))

        expect(stdout_xml.xpath("//USER/ID")[0].text.to_i).to eq(user_id)

        # Check delete call
        cli_action("oneuser delete #{user_id}")

        wait_hook(hook_del, 0)

        xml = cli_action_xml("onehook show -x #{hook_del}")

        stdout = Base64.decode64(xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDOUT"])
        stdout_xml = Nokogiri::XML(Base64.decode64(stdout))

        expect(stdout_xml.xpath("//USER/ID")[0].text.to_i).to eq(user_id)

        cli_action("onehook delete #{hook_all}")
        cli_action("onehook delete #{hook_del}")
    end

    it "should get resource template on IMAGE allocate and delete calls" do
        template_all = <<-EOF
                    NAME = hook-all
                    TYPE = api
                    COMMAND = "/$(which cat)"
                    CALL = "one.image.allocate"
                    ARGUMENTS = "$API"
                    ARGUMENTS_STDIN = yes
        EOF

        template_del = <<-EOF
                    NAME = hook-del
                    TYPE = api
                    COMMAND = "/$(which cat)"
                    CALL = "one.image.delete"
                    ARGUMENTS = "$API"
                    ARGUMENTS_STDIN = yes
        EOF

        hook_all = cli_create('onehook create', template_all)
        hook_del = cli_create('onehook create', template_del)

        # Check allocate call
        img_id = cli_create('oneimage create -d default --size 1 --name datablock --type datablock')

        wait_hook(hook_all, 0)

        xml = cli_action_xml("onehook show -x #{hook_all}")

        stdout = Base64.decode64(xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDOUT"])
        stdout_xml = Nokogiri::XML(Base64.decode64(stdout))

        expect(stdout_xml.xpath("//IMAGE/ID")[0].text.to_i).to eq(img_id)

        # Check delete call
        cli_action("oneimage delete #{img_id}")

        wait_hook(hook_del, 0)

        xml = cli_action_xml("onehook show -x #{hook_del}")

        stdout = Base64.decode64(xml["/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{0}]//STDOUT"])
        stdout_xml = Nokogiri::XML(Base64.decode64(stdout))

        expect(stdout_xml.xpath("//IMAGE/ID")[0].text.to_i).to eq(img_id)

        cli_action("onehook delete #{hook_all}")
        cli_action("onehook delete #{hook_del}")
    end

end

