require 'init_functionality'
require 'sunstone_test'
require 'sunstone/Support'
require 'one-open-uri'
require 'yaml'

begin
    require 'zendesk_api'
rescue LoadError
    raise "Missing zendesk_api gem"
end

if RUBY_VERSION < "2.1"
    require 'scrub_rb'
end

SUPPORTPATH = "/tmp/support.yaml"
RSpec.describe "Support test", :type => 'skip' do
  before(:all) do
    user = @client.one_auth.split(":")
    @auth = {
      :username => user[0],
      :password => user[1]
    }

    # Take support credentials and create Zendesk Client
    open(SUPPORTPATH, 'w') do |file|
      file.write(ONE_URI.open("http://services/secrets/support.yaml").read)
    end
    begin
      @support_conf = YAML::load(File.read(SUPPORTPATH))
    rescue Exception => e
      raise "Unable to read '#{SUPPORTPATH}'. Invalid YAML syntax:\n" + e.message
    end
    if(!@support_conf.nil?)
      @client_zendesk = ZendeskAPI::Client.new do |config|
        config.url = "https://opennebula.zendesk.com/api/v2"
        config.username = @support_conf['email']
        config.password = @support_conf['pass']
        config.retry = true
      end
    end
    if @support_conf.nil? || @client_zendesk.current_user.nil? || @client_zendesk.current_user.id.nil?
      raise "Zendesk account credentials are incorrect"
    end


    @sunstone_test = SunstoneTest.new(@auth, false)
    @sunstone_test.login
    @support = Sunstone::Support.new(@sunstone_test)
    @support_one_last_version = '0'
  end

  before(:each) do
    sleep 6
  end

  after(:all) do
    @sunstone_test.sign_out
  end
  
  it "Officially Supported" do
    @support.officially_supported()
  end

  it "Officially Version" do
    latest_version_git = @support.find_latest_version()
    latest_version = @support.find_latest_version()
    front_version = @support.get_front_version()
    if(front_version && latest_version[:version])
      expect(front_version).to be >= latest_version[:version]
    end
  end

  it "Login" do
    opts = {
        email: @support_conf['email'],
        pass: @support_conf['pass']
    }
    @support.login(opts)
  end

  it "Create request" do
    opts = {
        subject: "Jenkins Test",
        version: "5.6.0",
        description: "Testing...",
        severity: "severity_3"
    }
    @support.request(opts)
  end

  it "Check request" do
    opts = {
        subject: "Jenkins Test"
    }
    @support.check_request(opts)
  end

  it "Delete requests" do
    zrequests = @client_zendesk.requests({:status => "new,open,pending"})
    zrequests.each { |zrequest|
      zrequest.solved = true
      zrequest.save!
    }
  end
end
