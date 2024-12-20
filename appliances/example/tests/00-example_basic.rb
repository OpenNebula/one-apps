require_relative '../../lib/community/app_handler' # Loads the library to handle VM creation and destruction

# You can put any title you want, this will be where you group your tests
describe 'Appliance Certification' do
    # This is a library that takes care of creating and destroying the VM for you
    # The VM is instantiated with your APP_CONTEXT_PARAMS passed
    # "onetemplate instantiate base --context SSH_PUBLIC_KEY=\\\"\\$USER[SSH_PUBLIC_KEY]\\\",NETWORK=\"YES\",ONEAPP_DB_NAME=\"dbname\",ONEAPP_DB_USER=\"username\",ONEAPP_DB_PASSWORD=\"upass\",ONEAPP_DB_ROOT_PASSWORD=\"arpass\" --disk service_example"
    include_context('vm_handler')

    # if the mysql command exists in $PATH, we can assume it is installed
    it 'mysql is installed' do
        cmd = 'which mysql'

        # use @info[:vm] to test the VM running the app
        @info[:vm].ssh(cmd).expect_success
    end

    # Use the systemd cli to verify that mysql is up and runnig. will fail if it takes more than 30 seconds to run
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

    # Check if the service framework from one-apps reports that the app is ready
    it 'check oneapps motd' do
        cmd = 'cat /etc/motd'

        execution = @info[:vm].ssh(cmd)

        # you can use pp to help with logging.
        # This doesn't verify anything, but helps with inspections
        # In this case, we display the motd you get when connecting to the app instance via ssh
        pp execution.stdout

        expect(execution.exitstatus).to eq(0)
        expect(execution.stdout).to include('All set and ready to serve')
    end

    # use mysql CLI to verify root password
    it 'can connect as root with defined password' do
        pass = APP_CONTEXT_PARAMS[:DB_ROOT_PASSWORD]
        cmd = "mysql -u root -p#{pass} -e ''"

        execution = @info[:vm].ssh(cmd)
        expect(execution.success?).to be(true)
    end

    # use mysql CLI to verify that the database has been created
    it 'database exists' do
        pass = APP_CONTEXT_PARAMS[:DB_ROOT_PASSWORD]
        db = APP_CONTEXT_PARAMS[:DB_NAME]

        cmd = "mysql -u root -p#{pass} -e 'USE #{db};'"

        execution = @info[:vm].ssh(cmd)
        expect(execution.success?).to be(true)
    end

    # use mysql CLI to verify that the user credentials
    it 'can connect as user with defined password' do
        user = APP_CONTEXT_PARAMS[:DB_USER]
        pass = APP_CONTEXT_PARAMS[:DB_PASSWORD]

        cmd = "mysql -u #{user} -p#{pass} -e ''"

        execution = @info[:vm].ssh(cmd)
        expect(execution.success?).to be(true)
    end
end

# Example run
# rspec -f d tutorial_tests.rb
# Appliance Certification
# "onetemplate instantiate base --context SSH_PUBLIC_KEY=\\\"\\$USER[SSH_PUBLIC_KEY]\\\",NETWORK=\"YES\",ONEAPP_DB_NAME=\"dbname\",ONEAPP_DB_USER=\"username\",ONEAPP_DB_PASSWORD=\"upass\",ONEAPP_DB_ROOT_PASSWORD=\"arpass\" --disk service_example"
#   mysql is installed
#   mysql service is running
# "\n" +
# "    ___   _ __    ___\n" +
# "   / _ \\ | '_ \\  / _ \\   OpenNebula Service Appliance\n" +
# "  | (_) || | | ||  __/\n" +
# "   \\___/ |_| |_| \\___|\n" +
# "\n" +
# " All set and ready to serve 8)\n" +
# "\n"
#   check oneapps motd
#   can connect as root with defined password
#   database exists
#   can connect as user with defined password

# Finished in 1 minute 25.9 seconds (files took 0.22136 seconds to load)
# 6 examples, 0 failures
