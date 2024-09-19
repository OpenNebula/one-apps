require 'sunstone/Utils'

class Sunstone
    class App
        def initialize(sunstone_test)
            @general_tag    = "storage"
            @resource_tag   = "marketplaceapps"
            @datatable      = "dataTableMarketplaceApps"

            @marketplace_datatable_for_app   = 'createMarketPlaceAppFormmarketPlacesTable'
            @marketplace_datatable_for_image = 'createMarketPlaceAppFormmarketPlacesServiceTable'

            @create_form_images_datatable    = 'createMarketPlaceAppFormimagesTable'
            @create_form_templates_datatable = 'createMarketPlaceAppFormtemplatesTable'
            @create_form_vm_datatable        = 'createMarketPlaceAppFormvmsTable'
            @create_form_services_datatable  = 'createMarketPlaceAppFormservicesTable'

            @export_form_ds_datatable = 'exportMarketPlaceAppFormdatastoresTable'

            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
        end

        def navigate_to_marketapp
            @utils.navigate(@general_tag, @resource_tag)
            @utils.wait_element_by_id('marketplaceapps-tabcreate_buttons')
        end

        def download(options)
            navigate_to_marketapp()

            app_datatable = @sunstone_test.get_element_by_css("##{@datatable}")
            app = @utils.find_in_datatable_paginated(2, options[:app_name], app_datatable)

            fail("Not found app: #{options[:app_name]}") if !app

            app.find_element(:name, "selected_items").click

            element = @sunstone_test.get_element_by_id("#{@resource_tag}-tabmain_buttons")
            element.find_element(:class, "fa-cloud-download-alt").click

            @utils.wait_element_by_id(@export_form_ds_datatable)

            xpath_no_template_input = "//*[@id='exportMarketPlaceAppFormWizard']//input[@id='NOTEMPLATE']"
            @sunstone_test.get_element_by_xpath(xpath_no_template_input).click if options[:no_template]

            ds_datatable = @sunstone_test.get_element_by_css("##{@export_form_ds_datatable}")
            ds = @utils.check_exists_datatable(1, options[:ds_name], ds_datatable, 60) {
                # Refresh block
                @sunstone_test.get_element_by_css("#refresh_button_#{@export_form_ds_datatable}").click
                sleep 1
            }

            not_found_msg = "Not found datastore: #{options[:ds_name]}"
            @utils.save_temp_screenshot('download-app', not_found_msg) if !ds

            ds.click # select datastore

            @utils.submit_create(@resource_tag)
        end

        def update(name, new_name, hash)
            navigate_to_marketapp()

            app_datatable = @sunstone_test.get_element_by_css("##{@datatable}")
            app = @utils.find_in_datatable_paginated(2, name, app_datatable)

            @utils.wait_jGrowl

            if app
                app.click

                @utils.update_name(new_name) unless new_name.nil?

                if hash && !hash.empty?
                    @utils.update_attr("marketplaceapp_template_table", hash)
                end
            end
        end

        def delete(name)
            navigate_to_marketapp()

            @utils.delete_resource(name, @general_tag, @resource_tag, @datatable)
        end

        # hash = {
        #     type => '', # App type {image, vm, vmtemplate, service_template}
        #     name => '', # App name
        #     importImages => true, # Do you want to import images too {true, false}
        #     vmId => 0, # VM id to be imported
        #     vmTemplateId => 0, # Template id to be imported
        #     serviceId => 0, # Template id to be imported
        #     mpId => 0, # MarketPlace id where the app will be imported
        #     mpImageId => 0 # MarketPlace id where the images will be imported
        # }
        def create(hash)
            navigate_to_marketapp()

            # click on create app
            @sunstone_test.get_element_by_css("button[href='MarketPlaceApp.create_dialog']").click
            
            @utils.wait_element_by_id('createMarketPlaceAppFormWizard')
            
            if (hash[:type])
                element = @sunstone_test.get_element_by_id("createMarketPlaceAppFormWizard")
                dropdown = element.find_element(:id, "TYPE")
                @sunstone_test.click_option(dropdown, "value", hash[:type])
            end

            xpath_name = "//*[@id='createMarketPlaceAppFormWizard']//*[@id='NAME']"
            xpath_import = "//*[@id='createMarketPlaceAppFormWizard']//*[@id='IMPORT_ALL']"

            @utils.fill_input_by_finder(:xpath, xpath_name, hash[:name])        if hash[:name]
            @sunstone_test.get_element_by_xpath(:xpath, xpath_import).click     if hash[:importImages]
            
            if hash[:imageId]
                datatable = @sunstone_test.get_element_by_css("##{@datatable}")
                img = @utils.find_in_datatable_paginated(0, hash[:imageId].to_s, datatable, true)
                img.click
            end

            if hash[:vmId]
                datatable = @sunstone_test.get_element_by_css("##{@create_form_vm_datatable}")
                vm = @utils.find_in_datatable_paginated(0, hash[:vmId].to_s, datatable, true)
                vm.click
            end

            if hash[:vmTemplateId]
                datatable = @sunstone_test.get_element_by_css("##{@create_form_templates_datatable}")
                template = @utils.find_in_datatable_paginated(0, hash[:vmTemplateId].to_s, datatable, true)
                template.click
            end

            if hash[:serviceId]
                datatable = @sunstone_test.get_element_by_css("##{@create_form_services_datatable}")
                service = @utils.find_in_datatable_paginated(0, hash[:serviceId].to_s, datatable, true)
                service.click
            end

            if hash[:mpId]
                datatable = @sunstone_test.get_element_by_css("##{@marketplace_datatable_for_app}")
                mpApp = @utils.find_in_datatable_paginated(0, hash[:mpId].to_s, datatable, true)
                mpApp.click
            end

            if hash[:mpImageId]
                datatable = @sunstone_test.get_element_by_css("##{@marketplace_datatable_for_image}")
                mpImage = @utils.find_in_datatable_paginated(0, hash[:mpImageId].to_s, datatable, true)
                mpImage.click
            end

            xpath_create = "//*[@id='marketplaceapps-tabform_buttons']//button[contains(@class,'submit_button')]"
            submit_btn = @sunstone_test.get_element_by_xpath(xpath_create)

            submit_btn.click

            @utils.wait_cond({
                :debug => 'to finish submitting',
                :name_screenshot => "wait_error_create_app-#{hash[:name]}"
            }) {
                break if (submit_btn.enabled? || !submit_btn.displayed?)
            }
        end
    end
end
