require 'sunstone/Utils'

class Sunstone
    class VNet
        def initialize(sunstone_test)
            @general_tag = "network"
            @resource_tag = "vnets"
            @datatable = "dataTableVNets"
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
            @wait = Selenium::WebDriver::Wait.new(:timeout => 30)
        end

        def create(name, hash, ars)
            @utils.navigate(@general_tag, @resource_tag)

            if !@utils.check_exists(2, name, @datatable)
                @utils.navigate_create(@general_tag, @resource_tag)
                @sunstone_test.get_element_by_id("name").send_keys name

                fill_conf(hash)
            
                fill_ars(ars)

                @utils.submit_create(@resource_tag)
            end
        end

        def create_advanced(template)
            @utils.create_advanced(template, @general_tag, @resource_tag, "VNet")
        end

        def check(name, hash = [], ars = [])
            @utils.navigate(@general_tag, @resource_tag)
            @sunstone_test.refresh_resources("vnets")
            datatable = @sunstone_test.get_element_by_id(@datatable)
            vnet = @utils.find_in_datatable(2, name, datatable)
            if vnet
                vnet.click
                # information
                @sunstone_test.get_element_by_id("#{@resource_tag}-tab")
                tr_table = []
                @wait.until{
                    tr_table = $driver.find_elements(:xpath, "//table[@id='info_vnet_table']//tr")
                    !tr_table.empty?
                }
                hash = @utils.check_elements(tr_table, hash)

                # network_template_table
                tr_table = $driver.find_elements(:xpath, "//div[@id='vnet_info_tab']//table[@id='network_template_table']//tr")
                hash = @utils.check_elements(tr_table, hash)

                # address range
                @sunstone_test.get_element_by_id("vnet_ar_list_tab-label").click
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

        def delete_ar(name, ar_id, force)
            @utils.navigate(@general_tag, @resource_tag)
            vnet = @utils.check_exists(2, name, @datatable)
            if vnet
                vnet.click
                @sunstone_test.get_element_by_id("vnet_ar_list_tab-label").click
                ar = @utils.check_exists(0, ar_id, "ar_list_datatable")
                if ar
                    ar.click
                    @sunstone_test.get_element_by_id("rm_ar_button").click
                    if force
                        @sunstone_test.get_element_by_id("force_rm_ar").click
                    end
                    @sunstone_test.get_element_by_id("generic_confirm_proceed").click
                end
            end
        end

        def update(vnet_name, new_name, hash)
            @utils.navigate(@general_tag, @resource_tag)
            vnet = @utils.check_exists(2, vnet_name, @datatable)
            if vnet
                vnet.click
                @sunstone_test.get_element_by_id("vnet_info_tab")
                if new_name != ""
                    @utils.update_name(new_name)
                end

                if hash[:attrs] && !hash[:attrs].empty?
                    @utils.update_attr("network_template_table", hash[:attrs])
                end
            end
        end

        def add_security_group(vnet_name, security_group_name)
            @utils.navigate(@general_tag, @resource_tag)
            vnet = @utils.check_exists(2, vnet_name, @datatable)
            if vnet
                vnet.click
                @sunstone_test.get_element_by_id("vnet_sg_list_tab-label").click
                @sunstone_test.get_element_by_id("add_secgroup_button").click
                sec_group = @utils.check_exists(1, security_group_name, "add_secgroup")
                if sec_group
                    sec_group.click
                    @sunstone_test.get_element_by_id("submit_secgroups_button").click
                end
            end
        end

        def remove_security_group(vnet_name, security_group_name)
            @utils.navigate(@general_tag, @resource_tag)
            vnet = @utils.check_exists(2, vnet_name, @datatable)
            if vnet
                vnet.click
                @sunstone_test.get_element_by_id("vnet_sg_list_tab-label").click
                sec_group = @utils.check_exists(1, security_group_name, "vnet_sg_list_tabSecurityGroupsTable")
                if sec_group
                    sec_group.click
                    @sunstone_test.get_element_by_id("rm_secgroup_button").click
                    @sunstone_test.get_element_by_id("generic_confirm_proceed").click
                end
            end
        end

        private

        def fill_conf(hash)
            @sunstone_test.get_element_by_id("vnetCreateBridgeTab-label").click
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
            @sunstone_test.get_element_by_id("vnetCreateARTab-label").click
            if !ars.empty?
                @sunstone_test.get_element_by_id("vnet_wizard_ar_tabs")
                i = 0
                ars.each{ |ar|
                    @sunstone_test.get_element_by_id("ar#{i}_ar_type_#{ar[:type]}").click

                    if ar[:type] == "ip6" && ar[:ip6]
                        @sunstone_test.get_element_by_id("ar#{i}_global_prefix").send_keys ar[:ip6]
                    end

                    if ar[:type] == "ip6" || ar[:type] == "ether"
                        @sunstone_test.get_element_by_id("ar#{i}_mac_start").send_keys ar[:mac]
                    else
                        if ar[:ip]
                            @sunstone_test.get_element_by_id("ar#{i}_ip_start").send_keys ar[:ip]
                        end
                    end

                    if ar[:ipam]
                        $driver.find_element(:xpath, "//a[@href='#advanced_section_#{i+1}']//i").click
                        @sunstone_test.get_element_by_id("ar#{i}_ipam_mad").send_keys ar[:ipam]
                    end 

                    @sunstone_test.get_element_by_id("ar#{i}_size").send_keys ar[:size]

                    @sunstone_test.get_element_by_id("vnet_wizard_ar_btn").click
                    i+=1
                }
                $driver.find_element(:xpath, "//a[@id='ar_tabar#{i}']//i").click
            end
        end
    end
end
