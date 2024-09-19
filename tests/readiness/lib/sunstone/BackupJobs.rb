require 'sunstone/Utils'

class Sunstone
    class Backupjobs
        def initialize(sunstone_test)
            @general_tag = "storage"
            @resource_tag = "backupjob"
            @datatable = "dataTableBackupJob"
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
            @wait = Selenium::WebDriver::Wait.new(:timeout => 10)
        end

        def click_dropdown_option(dropdown_id, option_value)
            dropdown = @sunstone_test.get_element_by_id(dropdown_id)
            @sunstone_test.click_option(dropdown, "value", option_value)
          end

        def create(name, hash = [])
            @utils.navigate(@general_tag, @resource_tag)

            if !@utils.check_exists(2, name, @datatable)
                @utils.navigate_create(@general_tag, @resource_tag)

                @sunstone_test.get_element_by_id("name").send_keys "#{name}"

                if hash[:priority]
                    @sunstone_test.get_element_by_id("priority").send_keys "#{hash[:priority]}" 
                end

                if hash[:fsFreeze]
                    click_dropdown_option("fsFreeze", hash[:fsFreeze])
                end

                if hash[:mode]
                    click_dropdown_option("mode", hash[:mode])
                end

                if hash[:keepLast]
                    @sunstone_test.get_element_by_id("keepLast").send_keys "#{hash[:keepLast]}" 
                end

                if hash[:backupVolatile]
                    click_dropdown_option("backupVolatile", hash[:backupVolatile])
                end

                @utils.submit_create(@resource_tag)
            end
        end

        def delete(name)
            @utils.delete_resource(name, @general_tag, @resource_tag, @datatable)
        end
        
    end
end