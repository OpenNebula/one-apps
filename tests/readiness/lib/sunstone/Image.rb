require 'sunstone/Utils'

class Sunstone
    class Image
        def initialize(sunstone_test)
            @general_tag = "storage"
            @resource_tag = "images"
            @datatable = "dataTableImages"
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
            @wait = Selenium::WebDriver::Wait.new(:timeout => 30)
        end

        def create(json)
            @utils.navigate(@general_tag, @resource_tag)
            if !@utils.check_exists(2, json[:name], @datatable)
                @utils.navigate_create(@general_tag, @resource_tag)
                if json[:name]
                    @sunstone_test.get_element_by_id("img_name").send_keys json[:name]
                end
                if json[:type]
                    dropdown = @sunstone_test.get_element_by_id("img_type")
                    @sunstone_test.click_option(dropdown, "value", json[:type])
                end
                if json[:path]
                    @sunstone_test.get_element_by_id("path_image").click
                    @sunstone_test.get_element_by_id("img_path").send_keys json[:path]
                elsif json[:size]
                    @sunstone_test.get_element_by_id("datablock_img").click
                    @sunstone_test.get_element_by_id("img_size").send_keys json[:size]
                elsif json[:upload]
                    @sunstone_test.get_element_by_id("upload_image").click
                    element = @sunstone_test.get_element_by_id("file-uploader-input")
                    element.send_keys json[:upload]
                end

                advanced_options = @sunstone_test.get_element_by_xpath("//*[@id='createImageFormWizard']//*[@class='accordion_advanced']/a")
                advanced_options.click unless advanced_options.attribute("class").include?("active")

                if json[:bus]
                    bus_select = @sunstone_test.get_element_by_xpath("//select[@id='img_dev_prefix']")
                    option = Selenium::WebDriver::Support::Select.new(bus_select)
                    option.select_by(:value, json[:bus])
                end

                if json[:driver]
                    driver_select = @sunstone_test.get_element_by_xpath("//select[@id='img_driver']")
                    option = Selenium::WebDriver::Support::Select.new(driver_select)
                    option.select_by(:value, json[:driver])
                end

                @utils.submit_create(@resource_tag)
            end
        end

        def create_dockerfile(json)
            @utils.navigate(@general_tag, @resource_tag)
            if !@utils.check_exists(2, json[:name], @datatable)
              @utils.navigate_create(@general_tag, @resource_tag)

              #tabs
              tabs = @sunstone_test.get_element_by_id("createImageFormTabs")
              tabs.find_element(:xpath, "//a[@data-typesender='docker']").click

              #get wrapper form
              form = @sunstone_test.get_element_by_id("createImageFormDocker")
              

              #fill form
              if json[:name]
                form.find_element(:id, "docker_name").send_keys json[:name]
              end

              if json[:datastore]
                datastore = form.find_element(:id, "docker_datastore")
                datastore_select = datastore.find_element(:xpath, "//select[@class='resource_list_select']")
                option = Selenium::WebDriver::Support::Select.new(datastore_select)
                option.select_by(:value, json[:datastore])
              end

              if json[:context]
                context = form.find_element(:xpath, "//select[@id='docker_context']")
                option = Selenium::WebDriver::Support::Select.new(context)
                option.select_by(:value, json[:context])
              end

              if json[:size]
                form.find_element(:id, "docker_size").send_keys json[:size]
              end

              if json[:dockerfile]
                form.find_element(:xpath, "//*[@id='docker_template']//textarea[@class='ace_text-input']").send_keys json[:dockerfile]
              end

              @utils.submit_create(@resource_tag)
            end
        end

        def create_advanced(template)
            @utils.navigate(@general_tag, @resource_tag)
            @utils.navigate_create(@general_tag, @resource_tag)
            tab = @sunstone_test.get_element_by_id("createImageFormInternalTabs")
            tab.find_element(:id, "advanced_mode").click
            advanced = @sunstone_test.get_element_by_id("createImageFormAdvanced")
            textarea = advanced.find_element(:tag_name, "textarea")
            textarea.clear
            textarea.send_keys template
            @utils.submit_create(@resource_tag)
        end

        def check_persistent()
          @utils.navigate(@general_tag, @resource_tag)
          sleep 2
          datatable = $driver.find_element(:id, 'dataTableImages')
          image = @utils.find_in_datatable(2, "image_updated", datatable)
          if image
            image.click
            sleep 2
            if $driver.find_element(:class, "value_td_persistency").text != 'yes'
              raise "no change image persistent"
            end
          end
        end

        def check(name, hash = {})
            @utils.navigate(@general_tag, @resource_tag)
            img = @utils.check_exists(2, name, @datatable)
            if img
                img.click
                tr_table = []
                @wait.until{
                    tr_table = $driver.find_elements(:xpath, "//div[@id='image_info_tab']//table[@class='dataTable']//tr")
                    !tr_table.empty?
                }
                hash = @utils.check_elements(tr_table, hash)

                tr_table = $driver.find_elements(:xpath, "//div[@id='image_info_tab']//table[@id='image_template_table']//tr")
                hash = @utils.check_elements(tr_table, hash)

                if !hash.empty?
                    fail "Check fail: Not found all keys"
                    hash.each{ |obj| puts "#{obj[:key]} : #{obj[:key]}" }
                end
            end
        end

        def delete(name)
            @utils.delete_resource(name, @general_tag, @resource_tag, @datatable)
        end

        def update(name, new_name, json)
            begin
                @utils.navigate(@general_tag, @resource_tag)
                image = @utils.check_exists(2, name, @datatable)
                if image
                    image.click
                    @sunstone_test.get_element_by_id("image_info_tab-label").click

                    if new_name != ""
                        @utils.update_name(new_name)
                    end

                    if json[:attr] && !json[:attr].empty?
                        @utils.update_attr("image_template_table", json[:attr])
                    end

                    if json[:info] && !json[:info].empty?
                        @utils.update_info("//div[@id='image_info_tab']//table[@class='dataTable']", json[:info])
                    end

                    @sunstone_test.get_element_by_id("#{@resource_tag}-tabback_button").click
                else
                    fail "Image name: #{name} not exists"
                end
            rescue StandardError => e
                @utils.save_temp_screenshot("update-image-#{name}" , e)
            end
        end
    end
end
