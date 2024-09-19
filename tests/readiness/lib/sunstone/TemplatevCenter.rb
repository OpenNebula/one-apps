require 'sunstone/Template'
require 'sunstone/Utils'

class Sunstone
    class TemplatevCenter
        def initialize(sunstone_test)
            @general_tag = "templates"
            @resource_tag = "templates"
            @datatable = "dataTableTemplates"
            @sunstone_test = sunstone_test
            @template = Template.new(sunstone_test)
            @utils = Utils.new(sunstone_test)
        end

        def import(opts, extra_data = nil)
            @utils.navigate(@general_tag, @resource_tag)
            if !@utils.check_exists(2, opts[:host_name], @datatable)
                @utils.navigate_import(@general_tag, @resource_tag)

                xpath_host_table = "//*[@id='templates-tab-wizardForms']//table[contains(@id, 'HostsTable')]"
                host_table = @sunstone_test.get_element_by_xpath(xpath_host_table)
                host = @utils.find_in_datatable_paginated(1, opts[:host_name].to_s, host_table)

                if host
                  host.click
                  @sunstone_test.get_element_by_id("get-vcenter-templates").click
                  sleep 5
                else
                  fail "Host name: #{opts[:host_name]} not exists"
                end

                sleep 1
                xpath_templates_table = "//*[@id='templates-tab-wizardForms']//table[contains(@class, 'vcenter_import_table')]"
                templates_table = @sunstone_test.get_element_by_xpath(xpath_templates_table)
                temp_tr = @utils.find_in_datatable_paginated(1, opts[:template_path].to_s, templates_table)

                if temp_tr
                    tds = temp_tr.find_elements(tag_name: "td")
                    input = tds[0].find_element(tag_name: "input").click

                    if !extra_data.nil?
                        tds[1].find_element(tag_name: "a").click

                        extra_data.each { |data|
                            if data[:key] == "template_name"
                                tds[1].find_element(:class, "#{data[:key]}").clear
                                tds[1].find_element(:class, "#{data[:key]}").send_keys "#{data[:value]}"
                            else
                                tds[1].find_element(:class, "#{data[:key]}").click
                            end
                        }
                    end

                    @sunstone_test.get_element_by_id("import_vcenter_templates").click
                    sleep 40 # Linked clone
                else
                    fail "Template name: #{opts[:template_path]} not exists"
                end
            end
        end


        def update_storage(opts, hash = {})
            @template.navigate_update(opts[:name])
            @template.navigate_to_vmtemplate_tab_form('storage')

            add_storage(hash[:volatile], opts[:num_disks])
            @utils.submit_create(@resource_tag)
        end

        private

        def add_storage(disk, num_disks = 0)
            @sunstone_test.get_element_by_id("tf_btn_disks").click
            div = $driver.find_element(:xpath, "//div[@diskid='#{num_disks+1}']")
            div.find_element(:xpath, "//div[@diskid='#{num_disks+1}']//Input[@value='volatile']").click
            div.find_element(:xpath, "//div[@diskid='#{num_disks+1}']//div[@class='volatile']//Input[@id='SIZE']").send_keys disk[:size]
            if disk[:type]
                dropdown = div.find_element(:xpath, "//div[@diskid='#{num_disks+1}']//div[@class='volatile']//select[@id='TYPE_KVM']")
                @sunstone_test.click_option(dropdown, "value", disk[:type])
            end
            if disk[:format]
                dropdown = div.find_element(:xpath, "//div[@diskid='#{num_disks+1}']//div[@class='volatile']//select[@id='FORMAT_KVM']")
                @sunstone_test.click_option(dropdown, "value", disk[:format])
            end
        end
    end
end
