require 'sunstone/Utils'

class Sunstone
    class Datastore
        def initialize(sunstone_test)
            @general_tag = "storage"
            @resource_tag = "datastores"
            @datatable = "dataTableDatastores"
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
            @wait = Selenium::WebDriver::Wait.new(:timeout => 10)
        end

        def create(name, hash = []) #hash -> storage_bck, ds_type
            @utils.navigate(@general_tag, @resource_tag)

            if !@utils.check_exists(2, name, @datatable)
                @utils.navigate_create(@general_tag, @resource_tag)

                @sunstone_test.get_element_by_id("name").send_keys "#{name}"

                if hash[:tm]
                    dropdown = @sunstone_test.get_element_by_id("presets")
                    @sunstone_test.click_option(dropdown, "tm", hash[:tm])
                end
                if hash[:type]
                    @sunstone_test.get_element_by_id("#{hash[:type]}_ds_type").click
                end
                @utils.submit_create(@resource_tag)
            end
        end

        def create_advanced(template)
            @utils.create_advanced(template, @general_tag, @resource_tag, "Datastore")
        end

        def check(name, hash = [])
            @utils.navigate(@general_tag, @resource_tag)

            ds = @utils.check_exists(2, name, @datatable)
            if ds
                ds.click
                @sunstone_test.get_element_by_id("#{@resource_tag}-tab")
                tr_table = []
                @wait.until{
                    tr_table = $driver.find_elements(:xpath, "//div[@id='datastore_info_tab']//table[@class='dataTable']//tr")
                    !tr_table.empty?
                }
                hash = @utils.check_elements(tr_table, hash)

                tr_table = $driver.find_elements(:xpath, "//div[@id='datastore_info_tab']//table[@id='datastore_template_table']//tr")
                hash = @utils.check_elements(tr_table, hash)

                if !hash.empty?
                    puts "Check fail: Not Found all keys"
                    hash.each{ |obj| puts "#{obj[:key]} : #{obj[:value]}" }
                    fail
                end
            end
        end

        def update(ds_name, new_name, hash = [])
            @utils.navigate(@general_tag, @resource_tag)
            ds = @utils.check_exists(2, ds_name, @datatable)
            if ds
                ds.click
                @sunstone_test.get_element_by_id("datastore_info_tab")

                if new_name != ""
                    @utils.update_name(new_name)
                end

                if hash[:attrs] && !hash[:attrs].empty?
                    @utils.update_attr("datastore_template_table", hash[:attrs])
                end
            end
        end

        def delete(name)
            @utils.delete_resource(name, @general_tag, @resource_tag, @datatable)
        end
    end
end
