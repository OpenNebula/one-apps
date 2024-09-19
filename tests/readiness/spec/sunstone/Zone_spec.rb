require 'init_functionality'
require 'sunstone_test'

RSpec.describe "Sunstone zone tab", :type => 'skip' do
    after(:all) do
        @sunstone_test.sign_out
    end

      before(:all) do
        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        # add zone to oned.conf
        `echo "NAME=test\nENDPOINT=http://127.0.0.1:2633/RPC2" > /tmp/new_zones.conf`
        `sed 's/MODE=\"STANDALONE\",/MODE=\"MASTER\",/g' #{ONE_ETC_LOCATION}/oned.conf > /tmp/oned.conf.tmp \
        && cat /tmp/oned.conf.tmp > #{ONE_ETC_LOCATION}/oned.conf`

        @one_test.stop_one
        @one_test.start_one

        @sunstone_test = SunstoneTest.new(@auth)

        cli_action("onezone create /tmp/new_zones.conf")
        @sunstone_test.wait_resource_create("zone", "test")
        @sunstone_test.login
      end

    before(:each) do
        sleep 6
    end

    it 'should change zone' do
        new_zone_name = "test"

        xpath_zones = "//*[@id='zonelector']"
        @sunstone_test.get_element_by_xpath(xpath_zones).click
        sleep 2
        xpath_new_zone = "//*[@id='#{new_zone_name}']"
        @sunstone_test.get_element_by_xpath(xpath_new_zone).click
        sleep 2
        actual_zone = @sunstone_test.get_element_by_xpath(xpath_zones+'/span').text

        expect(actual_zone).to eq(new_zone_name)
    end
end
