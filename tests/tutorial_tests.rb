require 'rspec'
require_relative 'lib/init' # Load CLI libraries. These issue opennebula commands to mimic admin behavior
require_relative 'lib/image'

# Establish some configuration
VM_TEMPLATE = 'base'
APP_IMAGE_PATH = '/opt/one-apps/export/service_example.qcow2'
APP_IMAGE_NAME = 'service_example'

APP_CONTEXT_PARAMS = {
    :DB_NAME => 'dbname',
    :DB_USER => 'username',
    :DB_PASSWORD => 'upass',
    :DB_ROOT_PASSWORD => 'arpass'
}

describe 'Appliance Certification' do
    before(:all) do
        @info = {} # Used to pass info across tests

        if !CLIImage.list('-l NAME').include?(APP_IMAGE_NAME)
            CLIImage.create(APP_IMAGE_NAME, 1, "--path #{APP_IMAGE_PATH}")
        end

        options = "--context #{app_context(APP_CONTEXT_PARAMS)} --disk #{APP_IMAGE_NAME}"

        # Create a new VM by issuing onetemplate instantiate VM_TEMPLATE
        @info[:vm] = VM.instantiate(VM_TEMPLATE, true, options)
    end

    after(:all) do
        @info[:vm].terminate_hard
    end

    it 'mysql is installed' do
        cmd = 'which mysql'

        execution = @info[:vm].ssh(cmd)

        expect(execution.exitstatus).to eq(0)
    end

    it 'mysql service is running' do
        cmd = 'systemctl is-active mysql'
        start_time = Time.now
        timeout = 30

        loop do
            result = @info[:vm].ssh(cmd)
            break if result.success?

            if Time.now - start_time > timeout
                raise "MySQL service did not become active within #{timeout} seconds"
            end

            sleep 1
        end
    end

    it 'check oneapps motd' do
        cmd = 'cat /etc/motd'

        execution = @info[:vm].ssh(cmd)

        pp execution.stdout

        expect(execution.exitstatus).to eq(0)
        expect(execution.stdout).to include('All set and ready to serve')
    end

    it 'can connect as root with defined password' do
        pass = APP_CONTEXT_PARAMS[:DB_ROOT_PASSWORD]
        cmd = "mysql -u root -p#{pass} -e ''"

        execution = @info[:vm].ssh(cmd)
        expect(execution.success?).to be(true)
    end

    it 'database exists' do
        pass = APP_CONTEXT_PARAMS[:DB_ROOT_PASSWORD]
        db = APP_CONTEXT_PARAMS[:DB_NAME]

        cmd = "mysql -u root -p#{pass} -e 'USE #{db};'"

        execution = @info[:vm].ssh(cmd)
        expect(execution.success?).to be(true)
    end

    it 'can connect as user with defined password' do
        user = APP_CONTEXT_PARAMS[:DB_USER]
        pass = APP_CONTEXT_PARAMS[:DB_PASSWORD]

        cmd = "mysql -u #{user} -p#{pass} -e ''"

        execution = @info[:vm].ssh(cmd)
        expect(execution.success?).to be(true)
    end
end

# generate context section for app testing based on app input
def app_context(app_context_params)
    params = [%(SSH_PUBLIC_KEY=\\"\\$USER[SSH_PUBLIC_KEY]\\"), 'NETWORK="YES"']

    app_context_params.each do |key, value|
        params << "ONEAPP_#{key}=\"#{value}\""
    end

    return params.join(',')
end
