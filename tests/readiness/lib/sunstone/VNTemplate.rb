require 'sunstone/Utils'

class Sunstone
    class VNTemplate
        def initialize(sunstone_test)
            @general_tag = "network"
            @resource_tag = "vnets-templates"
            @datatable = "dataTableVNTemplate"
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
            @wait = Selenium::WebDriver::Wait.new(:timeout => 30)
        end

        def navigate_vntemplate_datatable
            @utils.navigate(@general_tag, @resource_tag)
        end

        def get_vntemplate_from_datatable(name)
            navigate_vntemplate_datatable()
            table = @sunstone_test.get_element_by_id(@datatable)
    
            vntemplate = @utils.check_exists_datatable(2, name, table, 60) {
                # Refresh block
                @sunstone_test.get_element_by_css("#vnets-templates-tabrefresh_buttons>button").click
                sleep 1
            }

            vntemplate
        end

        def navigate_vntemplate(name)
            begin
                get_vntemplate_from_datatable(name).click
            rescue StandardError => e
                @utils.save_temp_screenshot("navigate-to-vntemplate-#{name}", e)
            end
        end

        def create(name, hash, ars)
            navigate_vntemplate_datatable()
            table = @sunstone_test.get_element_by_id(@datatable)

            if !@utils.find_in_datatable_paginated(2, name, table)
                @utils.navigate_create(@general_tag, @resource_tag)
                @sunstone_test.get_element_by_id("name").send_keys name

                fill_conf(hash)

                remove_ars()
                fill_ars(ars)

                @utils.submit_create(@resource_tag)
            end
        end

        def create_advanced(template)
            @utils.create_advanced(template, @general_tag, @resource_tag, "VNTemplate")
        end

        def check(name, hash = [], ars = [])
            navigate_vntemplate_datatable()

            @sunstone_test.refresh_resources("vnets-templates")

            table = @sunstone_test.get_element_by_id(@datatable)
            vntemplate = @utils.find_in_datatable_paginated(2, name, table)
            if vntemplate
                vntemplate.click
                # information
                @sunstone_test.get_element_by_id("#{@resource_tag}-tab")
                tr_table = []
                @wait.until{
                    tr_table = $driver.find_elements(:xpath, "//table[@id='info_vnet_table']//tr")
                    !tr_table.empty?
                }
                hash = @utils.check_elements(tr_table, hash)

                # network_template_table
                tr_table = $driver.find_elements(:xpath, "//div[@id='vnet_template_info_tab']//table[@id='vntemplate_template_table']//tr")
                hash = @utils.check_elements(tr_table, hash)

                # address range
                @sunstone_test.get_element_by_id("vnet_template_ar_list_tab-label").click
                @wait.until{
                    $driver.find_element(:xpath, "//div[@id='ar_list_datatable_wrapper']//table[@id='ar_list_datatable']").displayed?
                }
                tr_table = $driver.find_elements(:xpath, "//div[@id='ar_list_datatable_wrapper']//table[@id='ar_list_datatable']//tr")
                ars.each{ |ar|
                    tr_table.each { |tr|
                        td = tr.find_elements(tag_name: "td")
                        if td.length > 0
                            if ar[:IP] == td[2].text
                                tr.click
                                tables = $driver.find_elements(:xpath, "//div[@id='ar_show_info']//table[@class='dataTable']")
                                tables.each{ |table|
                                    tr_table = table.find_elements(tag_name: 'tr')
                                    tr_table.each { |tr|
                                        td = tr.find_elements(tag_name: "td")
                                        if td.length > 0
                                            if ar[(td[0].text).to_sym] && ar[(td[0].text).to_sym] != td[1].text
                                                puts "Check fail: #{ar[(td[0].text).to_sym]} : #{ar[(td[0].text).to_sym]}"
                                                fail
                                                break
                                            elsif ar[(td[0].text).to_sym] && ar[(td[0].text).to_sym] == td[1].text
                                                ars.delete(ar)
                                            end
                                        end
                                    }
                                }
                                break
                            end
                        end
                    }
                }

                if !hash.empty?
                    puts "Check fail: Not Found all keys"
                    hash.each{ |obj| puts "#{obj[:key]} : #{obj[:value]}" }
                    fail
                end
                if !ars.empty?
                    puts "Check fail: Not Found all address ranges"
                    ars.each{ |ar| puts "#{ar[:IP]}" }
                    fail
                end
            end
        end

        def delete(name)
            @utils.delete_resource(name, @general_tag, @resource_tag, @datatable)
        end

        def update(vntemplate_name, new_name, hash)
            navigate_vntemplate_datatable()

            table = @sunstone_test.get_element_by_id(@datatable)
            vntemplate = @utils.find_in_datatable_paginated(2, vntemplate_name, table)
            if vntemplate
                vntemplate.click
                @sunstone_test.get_element_by_id("vnet_template_info_tab")
                if new_name != ""
                    @utils.update_name(new_name)
                end

                if hash[:attrs] && !hash[:attrs].empty?
                    @utils.update_attr("network_template_table", hash[:attrs])
                end
            end
        end

        def instantiate(vntemplate_name, json)
            fail 'Dataform should be includes an address range' if !json[:arange]

            navigate_vntemplate(vntemplate_name)
            sleep 3

            xpath_instantiate_btn = "
                //*[@id='vnets-templates-tabmain_buttons']
                //button[@href='VNTemplate.instantiate_vnets']"
            @sunstone_test.get_element_by_xpath(xpath_instantiate_btn).click

            @utils.wait_element_by_id('instantiateVNTemplateDialogWizard')

            xpath_instantiate_form = "//form[@id='instantiateVNTemplateDialogWizard']"

            # Fill vnet name
            xpath_vnet_name = "#{xpath_instantiate_form}//*[@id='vnet_name']"
            @utils.fill_input_by_finder(:xpath, xpath_vnet_name, json[:name]) if json[:name]

            # Select Address Range
            xpath_ar_datatable = "#{xpath_instantiate_form}//table[@id='ar_list_datatable']"
            ar_datatable = @sunstone_test.get_element_by_xpath(xpath_ar_datatable)

            arange = @utils.find_in_datatable(0, json[:arange], ar_datatable)

            fail("Not found address range: #{json[:arange]}") if !arange

            arange.click

            # Fill Network Configuration - Context
            fill_vnet_context(json[:context], xpath_instantiate_form) if json[:context]

            xpath_submit_btn = "//*[@id='vnets-templates-tabsubmit_button']//button[@href='submit']"
            @sunstone_test.get_element_by_xpath(xpath_submit_btn).click
        end

        def updateAR(vntemplate_name, new_ar)
            navigate_vntemplate_datatable()

            table = @sunstone_test.get_element_by_id(@datatable)
            vntemplate = @utils.find_in_datatable_paginated(2, vntemplate_name, table)
            if vntemplate
                vntemplate.click
                # Wait
                @utils.wait_element_by_id('vnet_template_ar_list_tab')
                
                # Go to Addresses tab
                @sunstone_test.get_element_by_id("vnet_template_ar_list_tab-label").click
                # Locate AR that we want to modify
                table = @sunstone_test.get_element_by_id("ar_list_datatable")
                ar = @utils.find_in_datatable_paginated(0, new_ar['id'], table)
                if ar 
                    # Click on the AR
                    ar.click
                    # Click on update button
                    @sunstone_test.get_element_by_id("update_ar_button").click
                    # Fill new size
                    xpath_input = "input[id='update_ar_size']"
                    @utils.fill_input_by_finder(:xpath, xpath_input, new_ar['size'])
                    # Click update button
                    @sunstone_test.get_element_by_id("submit_ar_button").click
                end
            end
        end 

        private

        def fill_vnet_context(context, xpath_form = '')
            # Open Context section
            xpath_context_accordion = "//*[@class='accordion_advanced']/a[contains(., 'Context')]"
            context_section = @sunstone_test.get_element_by_xpath(xpath_context_accordion)
            context_section.click if context_section && context_section.displayed?

            context[:custom_attrs].each { |attr|
                next if attr['key'] && attr['value']
                # Click add button
                xpath_add_btn = "#{xpath_form}//a[contains(@class, 'custom_tag')]"
                @sunstone_test.get_element_by_xpath(xpath_add_btn).click

                xpath_key_input = "(#{xpath_form}//*[@class='custom_tag_key'])[last()]"
                @utils.fill_input_by_finder(:xpath, xpath_key_input, attr[:key])

                xpath_value_input = "(#{xpath_form}//*[@class='custom_tag_value'])[last()]"
                @utils.fill_input_by_finder(:xpath, xpath_value_input, attr[:value])
            }
        end

        def fill_conf(hash)
            @sunstone_test.get_element_by_id("vntemplateCreateBridgeTab-label").click
            if hash[:bridge]
                @sunstone_test.get_element_by_id("bridge").send_keys hash[:bridge]
            end
            if hash[:mode]
                dropdown = @sunstone_test.get_element_by_id("network_mode")
                @sunstone_test.click_option(dropdown, "value", hash[:mode])
            end
            if hash[:phydev]
                @sunstone_test.get_element_by_id("phydev").send_keys hash[:phydev]
            end
            if hash[:mac_spoofing]
                @sunstone_test.get_element_by_id("mac_spoofing").click
            end
            if hash[:ip_spoofing]
                @sunstone_test.get_element_by_id("ip_spoofing").click
            end
            if hash[:automatic_vlan]
                dropdown = @sunstone_test.get_element_by_id("automatic_vlan_id")
                @sunstone_test.click_option(dropdown, "value", hash[:automatic_vlan])
                if hash[:automatic_vlan] == ""
                    @sunstone_test.get_element_by_id("manual_id").send_keys hash[:vlan_id]
                end
            end
            if hash[:mtu]
                @sunstone_test.get_element_by_id("mtu").send_keys hash[:mtu]
            end
        end

        def fill_ars(ars)
            @sunstone_test.get_element_by_id("vntemplateCreateARTab-label").click
            if !ars.empty?
                @sunstone_test.get_element_by_id("vnet_wizard_ar_btn").click
                @sunstone_test.get_element_by_id("vnet_wizard_ar_tabs")
                i = 1
                ars.each{ |ar|
                    @sunstone_test.get_element_by_id("ar#{i}_ar_type_#{ar[:type]}").click

                    if ar[:type] == "ip6" && ar[:ip6]
                        @sunstone_test.get_element_by_id("ar#{i}_global_prefix").send_keys ar[:ip6]
                    end

                    if ar[:type] == "ip6" || ar[:type] == "ether"
                        @sunstone_test.get_element_by_id("ar#{i}_mac_start").send_keys ar[:mac]
                    else
                        @sunstone_test.get_element_by_id("ar#{i}_ip_start").send_keys ar[:ip]
                    end

                    @sunstone_test.get_element_by_id("ar#{i}_size").send_keys ar[:size]

                    @sunstone_test.get_element_by_id("vnet_wizard_ar_btn").click
                    i+=1
                }
                $driver.find_element(:xpath, "//a[@id='ar_tabar#{i}']//i").click
            end
        end

        def remove_ars
            @sunstone_test.get_element_by_id("vntemplateCreateARTab-label").click
            sleep 1

            tabs = @sunstone_test.get_element_by_id('vnet_wizard_ar_tabs')
            aranges_tabs = tabs.find_elements(:class, 'remove-tab')

            aranges_tabs.each do |tab|
                tab.click
            end
        end
    end
end
