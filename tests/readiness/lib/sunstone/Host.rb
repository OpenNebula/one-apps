require 'sunstone/Utils'

class Sunstone
    class Host
        def initialize(sunstone_test)
            @general_tag = "infrastructure"
            @resource_tag = "hosts"
            @datatable = "dataTableHosts"
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
            @wait = Selenium::WebDriver::Wait.new(:timeout => 180)
        end

        def navigate_host_datatable
            @utils.navigate(@general_tag, @resource_tag)
        end

        def get_host_from_datatable(name)
            navigate_host_datatable()
            table = @sunstone_test.get_element_by_id(@datatable)
    
            host = @utils.check_exists_datatable(2, name, table, 60) {
                # Refresh block
                @sunstone_test.get_element_by_css("#hosts-tabrefresh_buttons>button").click
                sleep 1
            }

            host
        end

        def create(json = {})
            navigate_host_datatable

            if !@utils.check_exists(2, json[:name], @datatable)
                @utils.navigate_create(@general_tag, @resource_tag)
                dropdown = @sunstone_test.get_element_by_id("host_type_mad")
                @sunstone_test.click_option(dropdown, "value", json[:type])
                @sunstone_test.get_element_by_id("name").send_keys json[:name]
                if json[:vmmad]
                    @sunstone_test.get_element_by_name("custom_vmm_mad").send_keys json[:vmmad]
                end
                if json[:immad]
                    @sunstone_test.get_element_by_name("custom_im_mad").send_keys json[:immad]
                end
                @utils.submit_create(@resource_tag)
            end
        end

        def check(name, arr = [])
            navigate_host_datatable
            
            host = @utils.check_exists(2, name, @datatable)
            if host
                host.click
                div = @sunstone_test.get_element_by_id("host_info_tab")
                table = div.find_elements(:class, "dataTable")
                tr_table = table[0].find_elements(tag_name: 'tr')
                arr = @utils.check_elements(tr_table, arr)
                if !arr.empty?
                    fail "Check fail: Not Found all keys"
                    arr.each{ |obj| puts "#{obj[:key]} : #{obj[:key]}" }
                end
            end
        end

        def delete(name)
            @utils.delete_resource(name, @general_tag, @resource_tag, @datatable)
        end

        def validate_max_CPU(total_cpu="")
          rtn = false
          if !total_cpu.nil? || !total_cpu.empty?
            table = @sunstone_test.get_element_by_id("host_info_tab")
            tableInfo = table.find_elements(tag_name: "table")
            if tableInfo[1]
              tds = tableInfo[1].find_elements(tag_name:"td")

              if tds && tds.kind_of?(Array) && tds[3] && tds[3].text
                total = tds[3].text.split(" / ");
                if total && total.kind_of?(Array) && total[1]
                  value = total[1].split(" (")
                  if value[0] && value[0] === total_cpu
                    rtn = true;
                  end
                end
              end
            end
          end
          return rtn
        end

        def update_in_monitoring(json={})
          sleep 2
          rtn = false
          table = @sunstone_test.get_element_by_id("host_info_tab")
          tableInfo = table.find_elements(tag_name: "table")
          if tableInfo[0]
            tds = tableInfo[0].find_elements(tag_name:"td")
            if tds && tds.kind_of?(Array) && tds[9] && tds[9].text
              if tds[9].text === "MONITORED"
                input = @sunstone_test.get_element_by_id("textInput_reserved_cpu_hosts")
                input.clear()
                input.send_keys json[:max_cpu]
                # MEMORY
                input = @sunstone_test.get_element_by_id("textInput_reserved_mem_hosts")
                input.clear()
                input.send_keys json[:max_mem]
                #SEND
                @sunstone_test.get_element_by_id("update_reserved_hosts").click
                rtn =  true
              else
                placeRefresh = @sunstone_test.get_element_by_id("hosts-tabrefresh_buttons")
                placeRefresh.find_element(tag_name: "button").click
              end
            end
          end
          return rtn
        end

        def update(name, new_name, json = {})
            navigate_host_datatable

            host = @utils.check_exists(2, name, @datatable)
            if host
                @utils.wait_jGrowl
                host.click
                @sunstone_test.get_element_by_id("host_info_tab-label")
                if new_name
                    @utils.update_name(new_name)
                end
                if json[:cluster]
                    span = @sunstone_test.get_element_by_id("#{@resource_tag}-tabmain_buttons")
                    buttons = span.find_elements(:tag_name, "button")
                    buttons[0].click
                    tr = @utils.check_exists(1, json[:cluster], "confirm_with_select")
                    if tr
                        tr.click
                    else
                        fail "Cluster name: #{json[:cluster]} not exists"
                    end
                end
                @utils.wait_jGrowl
                @sunstone_test.get_element_by_id("confirm_with_select_proceed").click
                if json[:max_cpu] || json[:max_mem]
                  @wait.until{
                    update_in_monitoring(json)
                  }
                end
            else
                fail "Host name: #{name} not exists"
            end
        end
    end
end
