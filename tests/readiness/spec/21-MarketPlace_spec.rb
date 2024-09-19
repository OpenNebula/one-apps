require 'init'
require 'one-open-uri'
require 'webrick'

require_relative 'market/container'
require_relative 'market/generic'
require_relative 'market/one'
require_relative 'market/s3'

RSpec.describe 'Markets' do
    # creating HTTP marketplace
    # TODO: HTTP should be running before creating a marketplace,
    # otherwise we lose one monitoring cycle and have to wait long
    # time for monitoring
    file = Tempfile.new('market.conf')
    file << "Name       = Test_Market\n"
    file << "MARKET_MAD = http\n"
    file << "BASE_URL   = \"http://localhost:8000/\"\n"
    file << 'PUBLIC_DIR = "/var/tmp"'
    file.flush
    file.close

    system("onemarket create #{file.path}")

    aws_creds = YAML.safe_load(ONE_URI.open('http://services/secrets/auths3.yaml').read)

    # creating S3 marketplace
    file = Tempfile.new('market_s3.conf')
    file << "Name = \"S3Market\"\n"
    file << "MARKET_MAD = \"s3\"\n"
    file << "ACCESS_KEY_ID = \"#{aws_creds['access']}\"\n"
    file << "SECRET_ACCESS_KEY = \"#{aws_creds['secret']}\"\n"
    file << "BUCKET = \"one-marketplace\"\n"
    file << "REGION = \"#{aws_creds['region']}\"\n"
    file << "APP_PREFIX = \"#{rand(36**4).to_s(36)}\""
    file.flush
    file.close

    system('onemarket create ' + file.path)

    market_list = cli_action_xml('onemarket list -x', nil)
    market_list.each('/MARKETPLACE_POOL/MARKETPLACE') do |m|
        market_id  = m['ID']
        market_mad = m['MARKET_MAD']

        context "test marketplace ID #{market_id}" do
            case market_mad
            when 'one'
                market_examples_name = 'OneSysMarket'
            when 'linuxcontainers'
                market_examples_name = 'LinuxContainerMarket'
            when 's3'
                market_examples_name = 'S3'
            when 'turnkeylinux' # could be present in upgrade microenv
                next
            when 'dockerhub'    # same
                next
            else
                market_examples_name = 'GenericMarket'
            end

            it_should_behave_like market_examples_name, market_id
        end
    end
end
