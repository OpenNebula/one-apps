#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
require 'init_functionality'
require 'flow_helper'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe 'Terraform operations test' do
    include FlowHelper

    prepend_before(:all) do
        @defaults_yaml = File.join File.dirname(__FILE__), 'defaults.yaml'
    end

    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Create a dummy host
    #   - Prepare environment
    #---------------------------------------------------------------------------
    before(:all) do
        start_flow

        cli_action('onehost create dummy -i dummy -v dummy')

        cli_update('onedatastore update 0', 'TM_MAD=dummy', false)
        cli_update('onedatastore update 1', 'DS_MAD=dummy', false)
    end

    after(:all) do
        stop_flow
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    it 'should check that provider tests works as expected' do
        Dir.chdir('./spec/functionality/terraform/') do
            versions_str = @defaults[:provider_versions].join(%[;])
            expect(system("./terraform_test.sh '#{versions_str}'")).to eq(true)
        end
    end

end
