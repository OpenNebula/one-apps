require 'init_functionality'
require 'sunstone_test'
require 'sunstone/CloudView'

RSpec.describe "Cloud View Dashboard test", :type => 'skip' do
    
    new_user = {
      username: "oneadmin2",
      password: "opennebula"
    }
    pass = true
    @datastore = false
    @network = false
    @disk = false

    def register_user_with_quotas(new_user)
      rtn = false
      begin
        cli_create_user(new_user[:username], new_user[:password])
        file = Tempfile.new('quotas_for_dashboard_cloud_view')
        quota_file = <<-EOT
        VM=[
          SYSTEM_DISK_SIZE = 2048
        ]
        NETWORK = [
          ID = 1,
          LEASES = 25
        ]
        DATASTORE = [
          ID = 2,
          IMAGES = 2024,
          SIZE = 2048
        ]
        EOT

        file << quota_file
        file.flush
        cli_action("oneuser quota #{new_user[:username]} #{file.path}")
        file.close
        file.unlink
        user_xml = cli_action_xml("oneuser show #{new_user[:username]} -x")
        if user_xml["DATASTORE_QUOTA/DATASTORE/SIZE"] && user_xml["NETWORK_QUOTA/NETWORK/LEASES"] && user_xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE"]
          @datastore = user_xml["DATASTORE_QUOTA/DATASTORE/SIZE"]
          @network = user_xml["NETWORK_QUOTA/NETWORK/LEASES"]
          @disk = user_xml["VM_QUOTA/VM/SYSTEM_DISK_SIZE"]
          rtn = true
        else
          raise "no quota data"
        end
      rescue Exception => e
        raise "Invalid quotas"
      end
    end

    before(:all) do
      test = pass ? register_user_with_quotas(new_user) : true
      if test
        @auth = {
            :username => new_user[:username],
            :password => new_user[:password]
        }
        @sunstone_test = SunstoneTest.new(@auth)
        @sunstone_test.login
        @cloudView = Sunstone::CloudView.new(@sunstone_test)
        @cloudView.navigate
        pass = false
      end
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
      @sunstone_test.sign_out
    end

    it "Check user Check quotas" do
      datastore_dashboard = @cloudView.get_dashboard_data("provision_dashboard_datastore_str");
      system_dashboard = @cloudView.get_dashboard_data("provision_dashboard_system_disk_str");
      ips_dashboard = @cloudView.get_dashboard_data("provision_dashboard_ips_str");
      if datastore_dashboard
        expect(@datastore).to eql datastore_dashboard
      end
      if system_dashboard
        expect(@disk).to eql system_dashboard
      end
      if ips_dashboard
        expect(@network).to eql ips_dashboard
      end
    end
end
