require 'init_functionality'
require 'flow_helper'

RSpec.describe 'OneFlow upgrade database' do
    include FlowHelper

    prepend_before(:all) do
        @defaults_yaml = File.join(File.dirname(__FILE__), 'defaults.yaml')

        @template = 0
        @flow     = 1
    end

    before(:all) do
        if @main_defaults && @main_defaults[:build_components]
            unless @main_defaults[:build_components].include?('enterprise')
                skip 'only for EE'
            end
        end

        # Only for sqlite DB backend
        if @main_defaults && @main_defaults[:db]
            unless @main_defaults[:db]['BACKEND'] == 'sqlite'
                skip 'only for sqlite DB backend'
            end
        end
    end

    it 'copy database in previous version' do
        @one_test.stop_one
        @one_test.restore_db('spec/functionality/flow/one.db')
    end

    it 'run upgrade' do
        @one_test.stop_one
        @one_test.upgrade_db
        @one_test.start_one

        #Restore serveradmin password
        passwd=File.read('/var/lib/one/.one/oneflow_auth').split(':')[1].chomp
        cli_action("oneuser passwd --sha256 serveradmin #{passwd}")

        start_flow
    end

    it 'check new template' do
        template = cli_action_json("oneflow-template show #{@template} -j")
        template = get_body(template)

        expect(template['custom_attrs']).not_to be_nil
        expect(template['networks']).not_to be_nil
    end

    it 'check new flow' do
        flow = cli_action_json("oneflow show #{@flow} -j")
        flow = get_body(flow)

        expect(flow['custom_attrs']).not_to be_nil
        expect(flow['custom_attrs_values']).not_to be_nil
        expect(flow['networks']).not_to be_nil
        expect(flow['networks_values']).not_to be_nil
    end

    after(:all) do
        stop_flow
    end

    after(:each) do
        FileUtils.rm_r(Dir['/tmp/opennebula_dummy_actions/*'])
    end
end
