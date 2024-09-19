require 'sunstone/Utils'

class Sunstone
    class VMGroup
        def initialize(sunstone_test)
            @general_tag = "templates"
            @resource_tag = "vmgroup"
            @datatable = "dataTableVMGroup"
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
            @wait = Selenium::WebDriver::Wait.new(:timeout => 10)
        end

        def create_for_service(name, roles)
          @utils.navigate(@general_tag, @resource_tag)
          if !@utils.check_exists(2, name, @datatable)
            @utils.navigate_create(@general_tag, @resource_tag)
            @sunstone_test.get_element_by_id("vm_group_name").send_keys "#{name}"
            i = 0
            roles[:roles].each{ |rol|
                tab = @sunstone_test.get_element_by_id("vmgroup-tab")
                internal_tab = tab.find_element(:id,"role#{i}Tab")
                internal_tab.find_element(:id, "role_name").send_keys "#{rol[:name]}"
                internal_tab.find_element(:xpath, "//Input[@value='#{rol[:affinity]}' and @name='protocol_role#{i}']").click
                if rol[:hosts]
                  table = internal_tab.find_element(:id,"table_hosts_role#{i}")
                  tr_table = table.find_elements(tag_name: 'tr')
                  tr_table.each { |tr|
                      td = tr.find_elements(tag_name: "td")
                      if td.length > 0
                          tr.click if rol[:hosts].include? td[0].text
                      end
                  }
                end
                i+=1
                if i < roles[:roles].length
                    tab.find_element(:id, "tf_btn_roles").click
                end
            }
            @utils.submit_create(@resource_tag)
        end
        end

        def create(name, roles, affinity = [], anti_affinity = [])
            @utils.navigate(@general_tag, @resource_tag)

            if !@utils.check_exists(2, name, @datatable)
                @utils.navigate_create(@general_tag, @resource_tag)

                @sunstone_test.get_element_by_id("vm_group_name").send_keys "#{name}"
                i = 0
                roles[:roles].each{ |rol|
                    tab = @sunstone_test.get_element_by_id("role#{i}Tab")
                    tab.find_element(:id, "role_name").send_keys "#{rol[:name]}"

                    tab.find_element(:xpath, "//Input[@value='#{rol[:affinity]}' and @name='protocol_role#{i}']").click

                    table = @sunstone_test.get_element_by_id("table_hosts_role#{i}")
                    tr_table = table.find_elements(tag_name: 'tr')
                    tr_table.each { |tr|
                        td = tr.find_elements(tag_name: "td")
                        if td.length > 0
                            tr.click if rol[:hosts].include? td[0].text
                        end
                    }
                    i+=1
                    if i < roles[:roles].length
                        @sunstone_test.get_element_by_id("tf_btn_roles").click
                    end
                }
                dropdown = @sunstone_test.get_element_by_id("list_roles_select")
                affinity.each{ |affined|
                    affined.each{ |rol|
                        @sunstone_test.click_option(dropdown, "value", rol)
                    }
                    @sunstone_test.get_element_by_id("tf_btn_host_affined").click
                }

                anti_affinity.each{ |anti_affined|
                    anti_affined.each{ |rol|
                        @sunstone_test.click_option(dropdown, "value", rol)
                    }
                    @sunstone_test.get_element_by_id("tf_btn_host_anti_affined").click
                }

                @utils.submit_create(@resource_tag)
            end
        end

        def create_advanced(template)
            @utils.create_advanced(template, @general_tag, @resource_tag, "VMGroup")
        end

        # Hash parameter can have this attributes:
        #  - :info, :attr, :groups, :quotas, :auth
        def check(name, hash, affinity = [], anti_affinity = [])
            @utils.navigate(@general_tag, @resource_tag)
            @sunstone_test.get_element_by_id(@datatable)
            vmgrp = @utils.check_exists(2, name, @datatable)
            if vmgrp
                vmgrp.click
                @sunstone_test.get_element_by_id("vm_group_info_tab")
                tr_table = []
                roles_copy = hash[:roles][0 .. hash[:roles].length]
                @wait.until{
                    table = $driver.find_elements(:xpath, "//div[@id='vm_group_info_tab']//table[@class='policies_table dataTable']")[0]
                    tr_table = table.find_elements(tag_name: "tr")
                    !tr_table.empty?
                }
                hash[:roles].each { |rol|
                    table = $driver.find_elements(:xpath, "//div[@id='vm_group_info_tab']//table[@class='policies_table dataTable']")[0]
                    tr_table = table.find_elements(tag_name: 'tr')
                    tr_table.each { |tr|
                        td = tr.find_elements(tag_name: "td")
                        if td.length > 0 && td[0].text != "There is no data available"
                            if rol[:name] == td[0].text && rol[:affinity] == td[3].text
                                roles_copy.delete(rol)
                                break
                            end
                        end
                    }
                }

                if !roles_copy.empty?
                    fail "Roles not found"
                end

                affinity_copy = []
                affinity.each { |names|
                    affinity_copy.push(names.join(","))
                }

                anti_affinity_copy = []
                anti_affinity.each { |names|
                    anti_affinity_copy.push(names.join(","))
                }

                table = $driver.find_elements(:xpath, "//div[@id='vm_group_info_tab']//table[@class='policies_table dataTable']")[1]
                tr_table = table.find_elements(tag_name: 'tr')
                tr_table.each { |tr|
                    td = tr.find_elements(tag_name: "td")
                    if td.length > 0 && td[0].text != "There is no data available"
                        if td[1].text == "AFFINED"
                            if affinity_copy.include? td[0].text
                                affinity_copy.delete(td[0].text)
                            end
                        elsif td[1].text == "ANTI_AFFINED"
                            if anti_affinity_copy.include? td[0].text
                                anti_affinity_copy.delete(td[0].text)
                            end
                        end
                    end
                }

                if !affinity_copy.empty?
                    fail "Check fail affinity roles"
                end

                if !anti_affinity_copy.empty?
                    fail "Check fail anti_affinity roles"
                end
            else
                fail "VMGroup name: #{name} not exists"
            end
        end

        def delete(name)
            @utils.delete_resource(name, @general_tag, @resource_tag, @datatable)
        end

        def update(name, affinity = [], anti_affinity = [])
            @utils.navigate(@general_tag, @resource_tag)
            @sunstone_test.get_element_by_id(@datatable)
            vmgrp = @utils.check_exists(2, name, @datatable)
            if vmgrp
                td = vmgrp.find_elements(tag_name: "td")[0]
                td.find_element(:class, "check_item").click

                span = @sunstone_test.get_element_by_id("#{@resource_tag}-tabmain_buttons")
                buttons = span.find_elements(:tag_name, "button")
                buttons[0].click

                self.delete_affinities

                dropdown = @sunstone_test.get_element_by_id("list_roles_select")
                affinity.each{ |affined|
                    affined.each{ |rol|
                        @sunstone_test.click_option(dropdown, "value", rol)
                    }
                    @sunstone_test.get_element_by_id("tf_btn_host_affined").click
                }

                anti_affinity.each{ |anti_affined|
                    anti_affined.each{ |rol|
                        @sunstone_test.click_option(dropdown, "value", rol)
                    }
                    @sunstone_test.get_element_by_id("tf_btn_host_anti_affined").click
                }

                @utils.submit_create(@resource_tag)
            else
                fail "VMGroup name: #{name} not exists"
            end
        end

        def delete_affinities
            @sunstone_test.get_element_by_id("tf_btn_host_affined")
            divs = $driver.find_elements(:class, "group_role_content")
            if divs.length > 0
                divs.each{ |div|
                    i = div.find_element(:tag_name, "i").click
                }
            end
        end
    end
end
