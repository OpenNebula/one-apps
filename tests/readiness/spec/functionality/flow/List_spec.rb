require 'init_functionality'
require 'flow_helper'

RSpec.describe 'OneFlow list' do
    include FlowHelper

    prepend_before(:all) do
        @defaults_yaml = File.join(File.dirname(__FILE__), 'defaults.yaml')
    end

    before(:all) do
        start_flow

        # Create a test user
        @one_testuser = "testuser"
        @one_testuser_pwd = "testuser"
        cli_action("oneuser create #{@one_testuser} #{@one_testuser_pwd}")
    end

    it 'list services for oneadmin' do
        cli_action("oneflow list")
    end

    it 'list services for test-user' do
        cli_action("oneflow list --user #{@one_testuser} --password #{@one_testuser_pwd}")
    end

    ############################################################################
    # FAILING OPERATIONS
    ############################################################################

    it 'list services for nonexist-user' do
        one_nonexist_user = "nonexist-user"
        one_nonexist_user_pwd = "nonexist-user"
        cli_action(
            "oneflow list --user #{@one_nonexist_user} --password #{@one_nonexist_user_pwd}",
            false
        )
    end

    after(:all) do
        stop_flow
    end

    after(:each) do
        FileUtils.rm_r(Dir['/tmp/opennebula_dummy_actions/*'])
    end
end
