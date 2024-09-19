require 'init_functionality'
require 'sunstone_test'
require 'sunstone/Marketplace'

RSpec.describe "Sunstone marketplace tab", :type => 'skip' do

    before(:all) do
        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        @sunstone_test = SunstoneTest.new(@auth)
        @sunstone_test.login
        @marketplace = Sunstone::Marketplace.new(@sunstone_test)
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "should create an OpenNebula marketplace" do
        hash = {
            description: "Test OpenNebula marketplace",
            market_mad: "one"
        }
        @marketplace.create("test_one_mktplc", hash)

        @sunstone_test.wait_resource_create("market", "test_one_mktplc")
        mktplc = cli_action_xml("onemarket show -x test_one_mktplc") rescue nil

        expect(mktplc['MARKET_MAD']).to eql "one"
        expect(mktplc['TEMPLATE/DESCRIPTION']).to eql "Test OpenNebula marketplace"
    end

    it "should create a HTTP Server marketplace" do
        hash = {
            description: "Test HTTP Server marketplace",
            market_mad: "http",
            base_url: "http://frontend.opennebula.org/",
            public_dir: "/var/loca/market-http"
        }
        @marketplace.create("test_http_mktplc", hash)

        @sunstone_test.wait_resource_create("market", "test_http_mktplc")
        mktplc = cli_action_xml("onemarket show -x test_http_mktplc") rescue nil

        expect(mktplc['MARKET_MAD']).to eql "http"
        expect(mktplc['TEMPLATE/DESCRIPTION']).to eql "Test HTTP Server marketplace"
        expect(mktplc['TEMPLATE/BASE_URL']).to eql "http://frontend.opennebula.org/"
        expect(mktplc['TEMPLATE/PUBLIC_DIR']).to eql "/var/loca/market-http"
    end

    it "should create an Amazon S3 marketplace" do
        hash = {
            description: "Test Amazon S3 marketplace",
            market_mad: "s3",
            access_key: "I0PJDPCIYZ665MW88W9R",
            secret_key: "dxaXZ8U90SXydYzyS5ivamEP20hkLSUViiaR",
            bucket: "opennebula-market",
            region: "default"
        }
        @marketplace.create("test_s3_mktplc", hash)

        @sunstone_test.wait_resource_create("market", "test_s3_mktplc")
        mktplc = cli_action_xml("onemarket show -x test_s3_mktplc") rescue nil

        expect(mktplc['MARKET_MAD']).to eql "s3"
        expect(mktplc['TEMPLATE/DESCRIPTION']).to eql "Test Amazon S3 marketplace"
        expect(mktplc['TEMPLATE/ACCESS_KEY_ID']).to eql "I0PJDPCIYZ665MW88W9R"
        expect(mktplc['TEMPLATE/SECRET_ACCESS_KEY']).to eql "dxaXZ8U90SXydYzyS5ivamEP20hkLSUViiaR"
        expect(mktplc['TEMPLATE/BUCKET']).to eql "opennebula-market"
        expect(mktplc['TEMPLATE/REGION']).to eql "default"
    end

    it "should create a LXD marketplace" do
        hash = {
            description: "Test linux container marketplace",
            market_mad: "linuxcontainers"
        }
        @marketplace.create("test_lxd_mktplc", hash)

        mktplc = cli_action_xml("onemarket show -x test_lxd_mktplc") rescue nil
    
        expect(mktplc['MARKET_MAD']).to eql "linuxcontainers"
        expect(mktplc['TEMPLATE/DESCRIPTION']).to eql "Test linux container marketplace"
    end

    it "should create an OpenNebula marketplace with Configuration Attributes" do
        hash = {
            description: "Test OpenNebula marketplace",
            market_mad: "one",
            endpoint: "http://privatemarket.opennebula.org"
        }
        @marketplace.create("test_one_mktplc2", hash)

        @sunstone_test.wait_resource_create("market", "test_one_mktplc2")
        mktplc = cli_action_xml("onemarket show -x test_one_mktplc2") rescue nil

        expect(mktplc['MARKET_MAD']).to eql "one"
        expect(mktplc['TEMPLATE/DESCRIPTION']).to eql "Test OpenNebula marketplace"
        expect(mktplc['TEMPLATE/ENDPOINT']).to eql "http://privatemarket.opennebula.org"
    end

    it "should create a LXD marketplace with Configuration Attributes" do
        hash = {
            description: "Test linux container marketplace",
            market_mad: "linuxcontainers",
            endpoint: "https://images.linuxcontainers.org",
            image_size_mb: "1024",
            filesystem: "ext4",
            format: "raw",
            skip_untested: "yes"
        }
        @marketplace.create("test_lxd_mktplc2", hash)

        @sunstone_test.wait_resource_create("market", "test_lxd_mktplc2")
        mktplc = cli_action_xml("onemarket show -x test_lxd_mktplc2") rescue nil
    
        expect(mktplc['MARKET_MAD']).to eql "linuxcontainers"
        expect(mktplc['TEMPLATE/DESCRIPTION']).to eql "Test linux container marketplace"
        expect(mktplc['TEMPLATE/ENDPOINT']).to eql "https://images.linuxcontainers.org"
        expect(mktplc['TEMPLATE/IMAGE_SIZE_MB']).to eql "1024"
        expect(mktplc['TEMPLATE/FILESYSTEM']).to eql "ext4"
        expect(mktplc['TEMPLATE/FORMAT']).to eql "raw"
        expect(mktplc['TEMPLATE/SKIP_UNTESTED']).to eql "yes"
    end

    it "should delete a marketplace" do
        @marketplace.delete("test_s3_mktplc")

        @sunstone_test.wait_resource_delete("market", "test_s3_mktplc")
        xml = cli_action_xml("onemarket list -x") rescue nil
        if !xml.nil?
            expect(xml['DATASTORE[NAME="test_s3_mktplc"]']).to be(nil)
        end
    end

    it "should create a marketplace in advanced mode" do
        marketplace_template = <<-EOT
            NAME = test-marketplace-advanced
            MARKET_MAD = linuxcontainers
        EOT

        @marketplace.create_advanced(marketplace_template)

        @sunstone_test.wait_resource_create("market", "test-marketplace-advanced")
        marketplace = cli_action_xml("onemarket show -x test-marketplace-advanced") rescue nil

        expect(marketplace['MARKET_MAD']).to eql "linuxcontainers"
    end
end
