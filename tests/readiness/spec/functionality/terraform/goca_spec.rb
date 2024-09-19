#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
require 'init_functionality'
require 'flow_helper'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe 'GOCA operations test' do
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
        cli_update('onedatastore update 1', "DS_MAD=dummy\nDATASTORE_CAPACITY_CHECK=NO", false)
    end

    after(:all) do
        stop_flow
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    it 'should check that GOCA tests pass successfully' do
        goca_src_url = if @defaults[:goca_src_url].nil?
            if (repo_url = @main_defaults[:repo_url]).nil?
                ''
            else
                if (oned_version = %x(oned --version).lines[0]&.split[1]).nil?
                    ''
                else
                    URI.join(repo_url, "goca-src-#{oned_version}.tar.gz").to_s
                end
            end
        else
             @defaults[:goca_src_url]
        end

        skip('no GOCA source (empty)') if goca_src_url.empty?

        http_code = %x(curl -sI -o /dev/null -w '%{http_code}' '#{goca_src_url}').strip

        skip("no GOCA source (#{http_code})") if http_code != '200'

        Dir.chdir('./spec/functionality/terraform/') do
            expect(system("./goca_test.sh '#{goca_src_url}'")).to eq(true)
        end
    end

end
