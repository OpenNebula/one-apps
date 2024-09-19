require 'init_functionality'
require 'yaml'
require 'flow_helper'

RSpec.describe 'OneFlow Service Endpoint Option' do
    include FlowHelper

    prepend_before(:all) do
        @defaults_yaml = File.join(File.dirname(__FILE__), 'defaults.yaml')
    end

    before(:all) do
        start_flow
        config_file = "#{ONE_ETC_LOCATION}/oneflow-server.conf"
        config = YAML.load_file(config_file)

        @flow_host = config[:host]
        @flow_port = config[:port]

        # UNCOMMENT when nginx reverse proxy is added in the microenv
        # @nginx_host = config[:host]
        # @nginx_port = 80
        # @nginx_path = "/oneflow"
    end

    it 'list service templates without service endpoint' do
        list = cli_action("oneflow list")
    end

    it 'list service templates with oneflow endpoint' do
        list = cli_action("oneflow list --server http://#{@flow_host}:#{@flow_port}")
    end

    it 'list service templates with nginx reverse proxy endpoint' do
        if !@nginx_host.nil? && !@nginx_port.nil?
            list = cli_action("oneflow list --server http://#{@nginx_host}:#{@nginx_port}/#{@nginx_path}")
        end
    end
    
    ############################################################################
    # FAILING OPERATION
    ############################################################################

    it 'list service template with wrong endpoint' do
        wrong_host = "wrong_host"
        wrong_port = 1234
        wrong_path = "wrong_path"
        cli_action("oneflow-template list --server http://#{wrong_host}:#{wrong_port}/#{wrong_path}", false)
    end

    after(:all) do
        stop_flow
    end

    after(:each) do
        FileUtils.rm_r(Dir['/tmp/opennebula_dummy_actions/*'])
    end
end