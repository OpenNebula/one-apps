#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
# ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

private_keys = ['ssh_rsa', 'ssh_rsa_openssh'] # pem and openssh

RSpec.describe 'SSH Authentication tests' do
    private_keys.each do |private_key|
        key_file = File.join(File.dirname(__FILE__), private_key)
        username = private_key

        it "should create a SSH user account with private key #{private_key}" do
            key_one = cli_action("oneuser key -k #{key_file}").stdout

            cmd = "oneuser create #{username} --ssh #{key_one}"
            cli_action(cmd)
        end

        it "should authenticate using private SSH key #{private_key}" do
            auth_one = cli_action("echo 'no' | oneuser login #{username} --ssh "\
                                  "-k #{key_file} | tail -1").stdout

            file = Tempfile.new('functionality')
            file << auth_one
            file.flush
            file.close

            ENV['ONE_AUTH'] = file.path

            user = cli_action_xml('oneuser show -x')

            expect(user['NAME']).to eq(username)
            expect(user['AUTH_DRIVER']).to eq('ssh')

            ENV['ONE_AUTH'] = nil
        end
    end
end
