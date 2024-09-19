require 'sunstone/Utils'

class Sunstone
    class ImagevCenter
        def initialize(sunstone_test)
            @general_tag = "storage"
            @resource_tag = "images"
            @datatable = "dataTableImages"
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
            @wait = Selenium::WebDriver::Wait.new(:timeout => 60)
        end

        def import(opts)
            @utils.navigate(@general_tag, @resource_tag)
            if !@utils.check_exists(2, opts[:cluster], @datatable)
                @utils.navigate_import(@general_tag, @resource_tag)

                # Reset form
                @sunstone_test.get_element_by_xpath("
                    //*[@id='images-tabreset_button']
                    //button[contains(@class, reset_button)]").click

                tab = @sunstone_test.get_element_by_id("images-tab-wizardForms")

                table = tab.find_element(:class, "dataTable")
                host = @utils.find_in_datatable(1, opts[:cluster], table, '#HostsTableone1_next')
                if host
                    host.click
                else
                    fail "Host name: #{opts[:cluster]} not exists"
                end

                dropdown = @sunstone_test.get_element_by_id("vcenter_datastore")
                @sunstone_test.click_option(dropdown, "value", "#{opts[:datastore]}(IMG)")

                @sunstone_test.get_element_by_id("get-vcenter-images").click

                table_vcenter = false

                @wait.until {
                    begin
                        table_vcenter = tab.find_element(:class, "vcenter_import_table")
                        table_vcenter.displayed?
                    rescue Selenium::WebDriver::Error::StaleElementReferenceError
                    end
                }

                image = @utils.find_in_datatable_paginated(1, opts[:image_path], table_vcenter)

                fail("Not found image: #{opts[:image_path]}") if !image

                image.click
                @sunstone_test.get_element_by_id("import_vcenter_images").click
                sleep 7
            end
        end

    end
end
