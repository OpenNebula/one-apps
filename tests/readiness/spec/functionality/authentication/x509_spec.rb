
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "x509 Authentication tests" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do
        @key_file  = File.join(File.dirname(__FILE__),'x509_user_key.pem')
        @cert_file = File.join(File.dirname(__FILE__),'x509_user_cert.pem')
    end

    after(:all) do
        ENV['ONE_AUTH'] = nil
    end

    it "should create a x509 user account" do
        cli_action("oneuser create x509_user --x509 --cert #{@cert_file}")
    end

    it "should authenticate using x509 certificates" do
        auth_one = cli_action("echo 'no' | oneuser login x509_user --x509 "\
                     "--cert #{@cert_file} --key #{@key_file} | tail -1").stdout

        file = Tempfile.new('functionality')
        file << auth_one
        file.flush
        file.close

        ENV['ONE_AUTH'] = file.path

        user = cli_action_xml("oneuser show -x")

        expect(user['NAME']).to eq("x509_user")
        expect(user['AUTH_DRIVER']).to eq("x509")
    end
end

