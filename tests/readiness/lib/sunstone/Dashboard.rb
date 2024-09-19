
require 'rspec'
require 'sunstone/Utils'

class Sunstone
    class Dashboard
        def initialize(sunstone_test)
            @general_tag = "dashboard"
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
        end

        def get_sunstone_server_conf()
            @utils.get_sunstone_server_conf
        end

        def navigate()
            $driver.find_element(:id, "li_#{@general_tag}-tab").click
        end
        
        def check_meter_threshold_values(meter_id)
            navigate()
            meter = @sunstone_test.get_element_by_id("dashboard_host_#{meter_id}_meter")

            meter_values = {
                min: meter.attribute("min").to_i,
                low: meter.attribute("low").to_i,
                high: meter.attribute("high").to_i
            }
            
            return meter_values
        end
    end
end
