#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "User main group operations test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        @user_id  = cli_create_user("test_name2", "password::##**")
        @group_id = cli_create("onegroup create new_group")
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    it "should create oneadmin User in the oneadmin Group" do
        xml = cli_action_xml("oneuser show -x 0")

        expect(xml['GID']).to eql('0')
        expect(xml.retrieve_elements('GROUPS/ID').include?('0')).to be(true)

        xml = cli_action_xml("onegroup show -x 0")

        expect(xml['ID']).to eql('0')
        expect(xml.retrieve_elements('USERS/ID').include?('0')).to be(true)
    end

    it "should create a new User in the Users group" do
        xml = cli_action_xml("oneuser show -x #{@user_id}")

        expect(xml['GID']).to eql('1')
        expect(xml.retrieve_elements('GROUPS/ID').include?("1")).to be(true)

        xml = cli_action_xml("onegroup show -x users")

        expect(xml.retrieve_elements('USERS/ID').include?("#{@user_id}")).to be(true)
    end

    it "should change a User's group to an existing one" do
        cli_action("oneuser chgrp #{@user_id} #{@group_id}")

        xml = cli_action_xml("oneuser show -x #{@user_id}")

        expect(xml['GID']).to eql("#{@group_id}")
        expect(xml.retrieve_elements('GROUPS/ID')).to eq(["#{@group_id}"])

        xml = cli_action_xml("onegroup show -x #{@group_id}")

        expect(xml.retrieve_elements('USERS/ID').include?("#{@user_id}")).to be(true)

        xml = cli_action_xml("onegroup show -x 1")

        expect(xml.retrieve_elements('USERS/ID')).to be_nil
    end

    it "should change a User's group to the same one" do
        cli_action("oneuser chgrp #{@user_id} #{@group_id}")

        xml = cli_action_xml("oneuser show -x #{@user_id}")

        expect(xml['GID']).to eql("#{@group_id}")
        expect(xml.retrieve_elements('GROUPS/ID')).to eq(["#{@group_id}"])

        xml = cli_action_xml("onegroup show -x #{@group_id}")

        expect(xml.retrieve_elements('USERS/ID').include?("#{@user_id}")).to be(true)

        xml = cli_action_xml("onegroup show -x 1")

        expect(xml.retrieve_elements('USERS/ID')).to be_nil
    end

    it "Should add a User to a secondary group" do
        cli_action("oneuser addgroup #{@user_id} 1")

        xml = cli_action_xml("oneuser show -x #{@user_id}")
        expect(xml.retrieve_elements('GROUPS/ID')).to eq(["1", "#{@group_id}"])

        xml = cli_action_xml("onegroup show -x #{@group_id}")

        expect(xml.retrieve_elements('USERS/ID').include?("#{@user_id}")).to be(true)

        xml = cli_action_xml("onegroup show -x 1")

        expect(xml.retrieve_elements('USERS/ID').include?("#{@user_id}")).to be(true)
    end

    it "Should not remove User primary group" do
        cli_action("oneuser delgroup #{@user_id} #{@group_id}", false)

    end

    it "Should remove a User from a secondary group" do
        cli_action("oneuser delgroup #{@user_id} 1")
        xml = cli_action_xml("oneuser show -x #{@user_id}")

        expect(xml['GID']).to eql("#{@group_id}")
        expect(xml.retrieve_elements('GROUPS/ID')).to eq(["#{@group_id}"])

        xml = cli_action_xml("onegroup show -x #{@group_id}")

        expect(xml.retrieve_elements('USERS/ID').include?("#{@user_id}")).to be(true)

        xml = cli_action_xml("onegroup show -x 1")

        expect(xml.retrieve_elements('USERS/ID')).to be_nil
    end

    it "Should not add user to a non-existent group" do
        cli_action("oneuser addgroup #{@user_id} 150", false)
        cli_action("oneuser chgrp #{@user_id} 150", false)
    end
end
