require 'sunstone/Utils'

class Sunstone
    class AppvCenter
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
            @export_form_template_datatable = 'exportMarketPlaceAppFormtemplatesTable'

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

            @utils.wait_element_by_id('exportMarketPlaceAppFormWizard')

            xpath_no_template_input = "//*[@id='exportMarketPlaceAppFormWizard']//input[@id='NOTEMPLATE']"
            @sunstone_test.get_element_by_xpath(xpath_no_template_input).click if options[:no_template]

            ds_datatable = @sunstone_test.get_element_by_css("##{@export_form_ds_datatable}")
            ds = @utils.find_in_datatable_paginated(1, options[:ds_name], ds_datatable)

            fail("Not found datastore: #{options[:ds_name]}") if !ds

            ds.click # select datastore

            if options[:template_name]
                xpath_toggle_vmtemplate = "//*[@class='vCenterTemplateSelection']//a[contains(@class, 'toggle')]"
                toggle_vmtemplate = @sunstone_test.get_element_by_xpath(xpath_toggle_vmtemplate)
                toggle_vmtemplate.click if toggle_vmtemplate.attribute('class').include?('active') != true

                template_datatable = @sunstone_test.get_element_by_css("##{@export_form_template_datatable}")
                template = @utils.find_in_datatable_paginated(1, options[:template_name], template_datatable)
                
                fail("Not found template: #{options[:template_name]}") if !template

                template.click # select datastore
            end

            @utils.submit_create(@resource_tag)
        end
    end
end
