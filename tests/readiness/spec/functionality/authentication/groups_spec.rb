
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
LDAP_DUMMY_GROUP_FILE='/tmp/ldap_dummy.groups'

RSpec.describe "Group management in authentication drivers tests" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    def set_driver_groups(*gids)
        group_fd = File.open(LDAP_DUMMY_GROUP_FILE, 'w+')
        group_fd << gids.join(' ')
        group_fd.close
    end

    #---------------------------------------------------------------------------
    # Replace LDAP driver with a dummy one. groups
    #---------------------------------------------------------------------------
    before(:all) do
        @one_test.stop_one()

        @dummy = "#{File.dirname(__FILE__)}/ldap_dummy/authenticate"
        @ldap  = "#{ONE_VAR_LOCATION}/remotes/auth/ldap/authenticate"

        FileUtils.cp(@ldap, "#{@ldap}.orig")
        FileUtils.cp(@dummy, @ldap)

        @one_test.start_one()

        @gid1 = cli_create("onegroup create group1")
        @gid2 = cli_create("onegroup create group2")
        @gid3 = cli_create("onegroup create group3")
        @gid4 = cli_create("onegroup create group4")

        @file = Tempfile.new('functionality')
        @file << 'vicentin:atope'
        @file.flush
        @file.close

        ENV['ONE_AUTH'] = @file.path

    end

    after(:all) do
        ENV['ONE_AUTH'] = nil
        FileUtils.cp("#{@ldap}.orig",@ldap)
    end

    #---------------------------------------------------------------------------
    # Replace LDAP driver with a dummy one. groups
    #---------------------------------------------------------------------------
    it "should create user in multiple groups" do
        set_driver_groups(@gid1, @gid2, @gid3)
        cli_action("oneuser show")

        xml = cli_action_xml("oneuser show -x vicentin")
        expect(xml.retrieve_elements('GROUPS/ID')).to match_array ["100", "101",
                                                                   "102"]
    end

    it "should update user group list" do
        set_driver_groups(@gid1, @gid3, @gid4)
        xml = cli_action_xml("oneuser show -x vicentin")
        expect(xml.retrieve_elements('GROUPS/ID')).to match_array ["100", "102",
                                                                   "103"]
        set_driver_groups(@gid1)
        xml = cli_action_xml("oneuser show -x vicentin")
        expect(xml.retrieve_elements('GROUPS/ID')).to match_array ["100"]

        set_driver_groups(@gid1, @gid2, @gid3, @gid4)
        xml = cli_action_xml("oneuser show -x vicentin")
        expect(xml.retrieve_elements('GROUPS/ID')).to match_array ["100", "101",
                                                                   "102", "103"]
    end

    it "should remove the main group from user and add a new one" do
        set_driver_groups(@gid2, @gid3, @gid4)
        xml = cli_action_xml("oneuser show -x vicentin")
        expect(xml.retrieve_elements('GROUPS/ID')).to match_array ["101", "102",
                                                                   "103"]
        expect(xml['GID']).to eql("#{@gid2}")
    end

    #---------------------------------------------------------------------------
    # Tokens
    #---------------------------------------------------------------------------
    it "tokens for ldap have a max expiration time of 86400 seconds" do
        now = Time.now.to_i

        cli_action(" echo 'no' | oneuser token-create --time -1")
        cli_action(" echo 'no' | oneuser token-create --time 100000")

        user_xml = cli_action_xml("oneuser show -x")

        user_xml.each('LOGIN_TOKEN/EXPIRATION_TIME') do |e|
            expect(e.text.to_i - now).to be <= 86400+10
            expect(e.text.to_i - now).to be  > 86400-10
        end

        now = Time.now.to_i
        cmd = cli_action("echo 'no' | oneuser token-create --time 100")


        token      = cmd.stdout.split("\n")[-1].split(":")[-1].strip
        user_xml   = cli_action_xml("oneuser show -x")
        expiration = user_xml["LOGIN_TOKEN[TOKEN='#{token}']/EXPIRATION_TIME"].to_i

        expect(expiration - now).to be <= 100+10
        expect(expiration - now).to be  > 100-10
    end
end

