require 'sunstone/Utils'

class Sunstone
   class Zone
      def initialize(sunstone_test, one_test)
        # add zone to oned.conf
        `echo "NAME=zone_flow\nENDPOINT=http://127.0.0.1:2633/RPC2\nONEFLOW_ENDPOINT=pepe/RPC2" > /tmp/new_flow_zone.conf`
        `sed 's/MODE=\"STANDALONE\",/MODE=\"MASTER\",/g' #{ONE_ETC_LOCATION}/oned.conf > /tmp/oned.conf.tmp \
        && cat /tmp/oned.conf.tmp > #{ONE_ETC_LOCATION}/oned.conf`
        one_test.stop_one
        one_test.start_one
        @utils = Utils.new(sunstone_test)
        @sunstone_test = sunstone_test
      end

      def change_zone(zone_name = "")
        xpath_zones = "//*[@id='zonelector']"
        @sunstone_test.get_element_by_xpath(xpath_zones).click
        sleep 2
        xpath_new_zone = "//*[@id='#{zone_name}']"
        menu_element = @sunstone_test.get_element_by_xpath(xpath_new_zone)
        if menu_element
          menu_element.click
        else
          fail "non-existent zone"
        end
        sleep 2
        actual_zone = @sunstone_test.get_element_by_xpath(xpath_zones+'/span').text
      end
   end
end
