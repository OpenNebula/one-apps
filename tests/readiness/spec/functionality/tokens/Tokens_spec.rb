#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Tokens operations test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        @user_id  = cli_create_user("test_name2", 'passwordA')
        cli_action("onegroup create groupB")
        cli_action("oneuser addgroup test_name2 groupB")

        cli_action("onetemplate create --name templateGroupUsers")
        cli_action("onetemplate chgrp templateGroupUsers users")
        cli_action("onetemplate chmod templateGroupUsers 640")

        cli_action("onetemplate create --name templateGroupB")
        cli_action("onetemplate chgrp templateGroupB groupB")
        cli_action("onetemplate chmod templateGroupB 640")

        @info = {}
    end

    #---------------------------------------------------------------------------
    # TESTS global token
    #---------------------------------------------------------------------------

    it "should create a global token" do
        as_user("test_name2") {
            cmd = cli_action("echo 'no' | oneuser token-create")

            # The correct output should be something like:
            #
            # ------------------------------------------------------------------
            # File /home/jmelis/.one/one_auth exists, use --force to overwrite.
            # Authentication Token is:
            # test_name2:3f61deb991f63fa1d8fc7f2188cea6c61b31d912
            # ------------------------------------------------------------------

            # Make sure it mentions the success string
            expect(cmd.stdout).to match("Authentication Token is:")

            # Grab the token. Last line, split by ':' and get last element, and
            # strip the newline
            token = cmd.stdout.split("\n")[-1].split(":")[-1].strip

            # Make sure token has 64 chars
            expect(token.length).to be(64)

            # Store the token for later user
            @info[:token] = token
        }
    end

    it "the global token should work" do
        token = @info[:token]

        as_user_token("test_name2", token) do
            # Check oneuser show works
            user = cli_action_xml("oneuser show -x")
            expect(user['NAME']).to eq("test_name2")

            # Check the egid of the token is -1 (global)
            egid = user["LOGIN_TOKEN[TOKEN='#{token}']/EGID"]
            expect(egid.to_i).to be(-1)

            # Check the user can see all the templates
            templates = []
            template_list = cli_action_xml("onetemplate list -x")
            template_list.each('VMTEMPLATE/NAME'){|e| templates << e.text}

            expect(templates).to eq(["templateGroupB", "templateGroupUsers"])

        end
    end

    it "the global token can be set" do
        token = @info[:token]

        as_user("test_name2") do
            cmd = cli_action("oneuser token-set --token #{token}")
            expect(cmd.stdout).to match(/export/)

            auth_file = cmd.stdout.match(/ONE_AUTH=(.*?);/)[1]
            token_auth_file = File.read(auth_file).split(":")[1].strip

            expect(token).to eq(token_auth_file)
        end
    end

    it "the global token can be deleted" do
        token = @info[:token]

        as_user("test_name2") do
            cli_action("oneuser token-delete #{token}")
            user = cli_action_xml("oneuser show -x")

            token_found = user["LOGIN_TOKEN[TOKEN='#{token}']"]
            expect(token_found).to be_nil
        end
    end

    #---------------------------------------------------------------------------
    # TESTS group specific token
    #---------------------------------------------------------------------------

    it "should create a group specific token" do
        as_user("test_name2") {
            cmd = cli_action("echo 'no' | oneuser token-create --group groupB")

            # Make sure it mentions the success string
            expect(cmd.stdout).to match("Authentication Token is:")

            # Grab the token. Last line, split by ':' and get last element, and
            # strip the newline
            token = cmd.stdout.split("\n")[-1].split(":")[-1].strip

            # Make sure token has 64 chars
            expect(token.length).to be(64)

            # Store the token for later user
            @info[:token] = token
        }
    end

    it "should not create a token in a group the user does not belong to" do
        as_user("test_name2") {
            cli_action("echo 'no' | oneuser token-create --group 0", false)
        }
    end

    it "the specific token should work" do
        token = @info[:token]

        as_user_token("test_name2", token) do
            # Check oneuser show works
            user = cli_action_xml("oneuser show -x")
            expect(user['NAME']).to eq("test_name2")

            # Check the egid of the token is 100 (hardcoded first group created)
            egid = user["LOGIN_TOKEN[TOKEN='#{token}']/EGID"]
            expect(egid.to_i).to be(100)

            # Check the user can see all the templates
            templates = []
            template_list = cli_action_xml("onetemplate list -x")
            template_list.each('VMTEMPLATE/NAME'){|e| templates << e.text}

            expect(templates).to eq(["templateGroupB"])

        end
    end

    it "the specific token can be set" do
        token = @info[:token]

        as_user("test_name2") do
            cmd = cli_action("oneuser token-set --token #{token}")
            expect(cmd.stdout).to match(/export/)

            auth_file = cmd.stdout.match(/ONE_AUTH=(.*?);/)[1]
            token_auth_file = File.read(auth_file).split(":")[1].strip

            expect(token).to eq(token_auth_file)

        end
    end

    it "with the specific token resources are created in the same group" do
        token = @info[:token]

        as_user_token("test_name2", token) do
            cli_action("onetemplate create --name templateTestGroup")
            template = cli_action_xml("onetemplate show -x templateTestGroup")
            expect(template['GID'].to_i).to be(100)
        end
    end

    it "should not allow to create a token using a scoped token in other group" do
        token = @info[:token]

        as_user_token("test_name2", token) do
            cli_action("echo 'no' | oneuser token-create --group 1", false)
        end
    end

    it "the specific token can be deleted" do
        token = @info[:token]

        as_user("test_name2") do
            cli_action("oneuser token-delete #{token}")
            user = cli_action_xml("oneuser show -x")

            token_found = user["LOGIN_TOKEN[TOKEN='#{token}']"]
            expect(token_found).to be_nil
        end
    end
end
