require 'sunstone/Utils'
require 'sunstone/Flow'

class Sunstone
    class CloudView
        def initialize(sunstone_test)
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
            @flow = Flow.new(sunstone_test)
        end

        def navigate
            wait_element 1
            @sunstone_test.get_element_by_id("userselector").click
            $driver.find_element(:class, "fa-eye").click
            ul = $driver.find_element(:class, "submenu")
            li = ul.find_elements(:tag_name, "li")
            li.each{ |element|
                if element.text == "cloud"
                    element.click
                    break
                end
            }
        end

        def navigate_resource_list(list_name, add_click = false)
            xpath_tab = "
                //*[contains(@class, 'menu provision-header')]
                //a[contains(@class, '#{list_name}_list_button')]"

            @sunstone_test.get_element_by_xpath(xpath_tab).click

            # wait until list tab is loaded
            xpath_add_btn = "
                //*[contains(@class, 'provision_#{list_name}_list_section')]
                //*[contains(@class, 'provision_create_')]"

            @utils.wait_cond({ :debug => "#{list_name} tab on cloud view" }, 10) {
                element = $driver.find_elements(:xpath, xpath_add_btn)

                if element.size > 0 && element[0].displayed?
                    element[0].click if add_click # click add button
                    break
                end
            }
        end

        def navigate_resource_detail(list_name, resource_name)
            begin
                navigate_resource_list(list_name)

                xpath_resource = "
                    //table[contains(@class, 'provision_#{list_name}_table')]
                    //li[@class='provision-title' and contains(., '#{resource_name}')]"
                
                @sunstone_test.get_element_by_xpath(xpath_resource).click
                
                sleep 2
            rescue StandardError => e
                @utils.save_temp_screenshot("cloud-view-navigate-to-#{resource_name}" , e)
            end
        end

        def change_flow_role_cardinality(service_name, role_name, new_cardinality)
            navigate_resource_detail('flows', service_name)

            xpath_cardinality_btn = "
                //*[@class='provision_info_flow']
                //li[@class='provision-title' and contains(., '#{role_name}')]
                /following-sibling::*[@class='provision-bullet-item-buttons']
                /button[contains(@class, 'cardinality')]"

            @sunstone_test.get_element_by_xpath(xpath_cardinality_btn).click

            xpath_cardinality_input = "
                //*[@class='provision_info_flow']
                //*[@class='cardinality_slider_div']
                //*[@class='visor']"

            @utils.fill_input_by_finder(:xpath, xpath_cardinality_input, new_cardinality.to_s)

            xpath_cardinality_submit = "
                //*[@class='provision_info_flow']
                //*[@class='cardinality_slider_div']
                /following-sibling::*[contains(@class, 'provision_change_cardinality_button') and @role_id='#{role_name}']"

            @sunstone_test.get_element_by_xpath(xpath_cardinality_submit).click
        end

        def instantiate_flow_template(template_name, service)
            navigate_resource_list('flows', true)

            xpath_form_create_flow = "//form[@id='provision_create_flow']"
            select_template_by_name(template_name, xpath_form_create_flow)

            @flow.fill_instantiate_service_form(service, true)

            xpath_btn_submit = "#{xpath_form_create_flow}//button[@type='submit']"
            @sunstone_test.get_element_by_xpath(xpath_btn_submit).click
        end

        def instantiate_template(vm_name, json)
            @sunstone_test.get_element_by_id("provision_dashboard")
            $driver.find_element(:class, "provision_create_vm_button").click
            wait_element 3

            if vm_name 
                @sunstone_test.get_element_by_id("vm_name").clear()
                @sunstone_test.get_element_by_id("vm_name").send_keys vm_name
            end

            $driver.find_element(:class, "provision-title").click
            wait_element 3

            div = $driver.find_element(:class, "mb_input")
            input = div.find_element(:class, "visor")
            input.clear
            input.send_keys [:control, 'a'], :delete
            input.send_keys json[:mem]

            if json[:disk] && json[:disk_unit]
                div = $driver.find_element(:class, "diskSlider")
                input = div.find_element(:class, "visor")
                input.clear
                input.send_keys [:control, 'a'], :delete
                input.send_keys json[:disk]

                dropdown = div.find_element(:class, "mb_input_unit")
                @sunstone_test.click_option(dropdown, "value", json[:disk_unit])
            end

            if json[:vnet]
                $driver.find_element(:class, "provision_add_network_interface").click
                wait_element 2

                div = $driver.find_element(:class, "provision_network_selector")
                table = div.find_elements(:class, "dataTable")

                wait_element 1
                # table[0]: vnets auto
                # table[1]: vnets
                vnet = @utils.check_exists_datatable(1, json[:vnet], table[1])
                if vnet
                    vnet.click
                    if json[:force_ipv4]
                        $driver.find_element(:class, "manual_ip4").send_keys json[:force_ipv4]
                    end
                else
                    fail "Network name: #{json[:vnet]} not exists"
                end
            end

            if json[:vmgroup]
                $driver.find_element(:class, "provision_add_vmgroup").click
                wait_element 7

                div = @sunstone_test.get_element_by_id("vmgroup_section_tables")
                table = div.find_element(:class, "dataTable")
                wait_element 7

                vmgroup = @utils.check_exists_datatable(1, json[:vmgroup], table)
                if vmgroup
                    vmgroup.click
                else
                    fail "VMGroup name: #{json[:vmgroup]} not exists"
                end

                dropdown = $driver.find_element(:class, "role_table_section")
                wait_element 7
                @sunstone_test.click_option(dropdown, "value", json[:role])
            end

            form = @sunstone_test.get_element_by_id("provision_create_vm")
            form.find_element(:class, "success").click
            wait_element 2
        end

        def provision_dashboard
            $driver.find_element(:class, "provision_dashboard_button").click
        end

        def storage(name, attach = nil, resize = nil)
            navigate_resource_detail('vms', name)
            @sunstone_test.get_element_by_id("vm_storage_tab-label").click

            attach_disk(attach) if attach
            
            resize_disk(resize) if resize
        end

        def network(name, attach = {})
            navigate_resource_detail('vms', name)
            @sunstone_test.get_element_by_id("vm_network_tab-label").click

            if !attach.empty?
                attach_nic(attach)
            end
        end

        def snapshot(name, hash = {})
            navigate_resource_detail('vms', name)
            @sunstone_test.get_element_by_id("vm_snapshot_tab-label").click

            if !hash.empty?
                vm_snapshot(hash)
            end
        end

        def detach_storage(name, hash = {})
            navigate_resource_detail('vms', name)
            @sunstone_test.get_element_by_id("vm_storage_tab-label").click

            if !hash.empty?
                detach_disk(hash)
            end
        end

        def detach_network(name, hash = {})
            navigate_resource_detail('vms', name)
            @sunstone_test.get_element_by_id("vm_network_tab-label").click

            if !hash.empty?
                detach_nic(hash)
            end
        end

        def capacity(name, hash = {})
            navigate_resource_detail('vms', name)
            @sunstone_test.get_element_by_id("vm_capacity_tab-label").click

            if !hash.empty?
                capacity_resize(hash)
            end
        end

        def delete_snapshot(name, hash = {})
            navigate_resource_detail('vms', name)
            @sunstone_test.get_element_by_id("vm_snapshot_tab-label").click
            if !hash.empty?
                delete_snap(hash)
            end
        end

        def terminate(name)
            navigate_resource_detail('vms', name)
            wait_element 1
            $driver.find_element(:class, "provision_terminate_confirm_button").click

            $driver.find_element(:class, "provision_terminate_button").click
        end

        def save_as(name, hash = {})
            navigate_resource_detail('vms', name)
            wait_element 1
            $driver.find_element(:class, "provision_save_as_template_confirm_button").click
            if !hash.empty?
                $driver.find_element(:class, "provision_snapshot_name").send_keys hash[:name]
                if hash[:description]
                    $driver.find_element(:class, "provision_snapshot_description").send_keys hash[:description]
                end
                $driver.find_element(:class, "provision_save_as_template_button").click
            end
        end

        def get_dashboard_data(id = "")
          rtn = false
          if id
            wait_element 2
            context = $driver.find_element(:id, "provision_quotas_dashboard")
            element = context.find_element(:id, id)
            if element.text
              parse = element.text.split(" / ")
              if parse[1]
                rtn = parse[1]
              end
            end
          end
          return rtn
        end

        def open_remote_connection(vm_name, action, sunstone_tab)
            actions = ['wfile', 'guac_vnc', 'guac_ssh', 'guac_rdp', 'vmrc']

            fail "Action should be: #{actions.join(', ')}" if !actions.include?(action)

            navigate_resource_detail('vms', vm_name)

            xpath_vm_section = "//*[contains(@class, 'provision_vms_list_section')]"
            xpath_refresh_btn = "#{xpath_vm_section}//a[contains(@class, 'provision_refresh_info')]"
            xpath_state_running = "#{xpath_vm_section}//*[@class='provision-title' and contains(., 'RUNNING')]"

            @utils.wait_cond({ :debug => "VM state is't running" }, 10) {
                @sunstone_test.get_element_by_xpath(xpath_refresh_btn).click
                
                # break if vm is running
                @sunstone_test.get_element_by_xpath(xpath_state_running) != false 
            }

            xpath_remotes_btn = "#{xpath_vm_section}//*[contains(@class, 'provision_remote_button')]"
            remotes_btn = @sunstone_test.get_element_by_xpath(xpath_remotes_btn)
            @utils.hover_element(remotes_btn)

            xpath_action_btn = "#{xpath_vm_section}//a[@class='provision_#{action}_button']"
            @sunstone_test.get_element_by_xpath(xpath_action_btn).click

            # Waiting until number of tabs is more than 1
            wait_args = { :debug => 'Guacamole VNC tab',
                :name_screenshot => 'remote-action-tab' }

            @utils.wait_cond(wait_args, 30) {
                $driver.window_handles.length != 1
            }

            # Loop through until we find a new tab handle
            $driver.window_handles.each do |handle|
                next if handle == sunstone_tab
                $driver.switch_to.window handle
            end

            @utils.wait_cond({ :debug => "remote connection tab isn't opening" }, 60) do
                # break if title is the name of vm
                $driver.title == vm_name
            end
        end

        private

        def select_template_by_name(name, xpath_form = '')
            xpath_wrapper = "#{xpath_form}//*[contains(@id, 'templates_table_wrapper')]"
            wrapper = @sunstone_test.get_element_by_xpath(xpath_wrapper)

            # if already selected, it's needed to click on edit button
            xpath_edit_btn = "#{xpath_form}//*[@class='selected_template']"
            @sunstone_test.get_element_by_xpath(xpath_edit_btn).click if !wrapper

            xpath_template = "#{xpath_wrapper}//*[@title='#{name}']"
            @sunstone_test.get_element_by_xpath(xpath_template).click

            sleep 5
        end

        def attach_disk(hash)
            @sunstone_test.get_element_by_id("attach_disk").click

            div = @sunstone_test.get_element_by_id("disk_type")
            table = div.find_element(:tag_name, "table")

            disk = @utils.check_exists_datatable(0, "#{hash[:id]}", table)

            if disk
                disk.click
                @sunstone_test.get_element_by_id("attach_disk_button").click
            else
                fail "Disk id: #{hash[:id]} not exists"
            end
        end

        def resize_disk(hash)
            wait_element 2
            div = @sunstone_test.get_element_by_id("tab_storage_form")
            table = div.find_element(:tag_name, "table")
            wait_element 2

            disk = @utils.check_exists_datatable(1, "#{hash[:id]}", table)
            begin
                disk.find_element(:class, "disk_resize").click
            rescue
                @utils.save_temp_screenshot('resize-fail', 'error while resizing disk')
            end

            div = @sunstone_test.get_element_by_id("diskSlider_resize")
            dropdown = div.find_element(:class, "mb_input_unit")
            @sunstone_test.click_option(dropdown, "value", "MB")
            input = div.find_element(:class, "visor")
            input.clear
            input.send_keys [:control, 'a'], :delete
            input.send_keys hash[:size]

            div = @sunstone_test.get_element_by_id("diskResizeVMDialogForm")
            div.find_element(:class, "success").click
        end

        def attach_nic(hash)
            wait_element 2
            @sunstone_test.get_element_by_id("attach_nic").click

            div = @sunstone_test.get_element_by_id("attachNICVMDialogForm")
            tables = div.find_elements(:tag_name, "table")

            # table[0]: vnets auto
            # table[1]: vnets
            # table[2]: sg

            nic = @utils.check_exists_datatable(0, "#{hash[:id]}", tables[1])

            if nic
                nic.click
                @sunstone_test.get_element_by_id("attach_nic_button").click
            else
                not_found_msg = "Network id: #{hash[:id]} not exists"
                @utils.save_temp_screenshot('attach-nic', not_found_msg)
            end
        end

        def vm_snapshot(hash)
            wait_element 3
            @sunstone_test.get_element_by_id("take_snapshot").click

            input = @sunstone_test.get_element_by_id("snapshot_name")
            input.clear
            input.send_keys hash[:name]

            div = @sunstone_test.get_element_by_id("snapshotVMDialog")
            div.find_element(:class, "success").click
        end

        def detach_disk(hash)
            wait_element 2
            div = @sunstone_test.get_element_by_id("tab_storage_form")
            table = div.find_element(:tag_name, "table")
            wait_element 2

            disk = @utils.check_exists_datatable(1, "#{hash[:id]}", table)

            disk.find_element(:class, "detachdisk").click
            @sunstone_test.get_element_by_id("generic_confirm_proceed").click
        end

        def detach_nic(hash)
            wait_element 2
            div = @sunstone_test.get_element_by_id("tab_network_form")
            table = div.find_element(:tag_name, "table")
            wait_element 2

            nic = @utils.check_exists_datatable(1, "#{hash[:id]}", table)

            nic.find_element(:class, "detachnic").click

            @sunstone_test.get_element_by_id("generic_confirm_proceed").click
        end

        def capacity_resize(hash)
            @sunstone_test.get_element_by_id("resize_capacity").click

            div = @sunstone_test.get_element_by_id("resizeVMDialogForm")

            wrapper = div.find_element(:class, "mb_input")
            input = wrapper.find_element(:class, "visor")
            input.clear
            input.send_keys hash[:mem]

            wrapper = div.find_element(:class, "cpu_input")
            input = wrapper.find_element(:tag_name, "input")
            input.clear
            input.send_keys hash[:cpu]

            wrapper = div.find_element(:class, "vcpu_input")
            input = wrapper.find_element(:tag_name, "input")
            input.clear
            input.send_keys hash[:vcpu]

            @sunstone_test.get_element_by_id("resize_capacity_button").click
        end

        def delete_snap(hash)
            wait_element 2
            div = @sunstone_test.get_element_by_id("snapshot_form")
            table = div.find_element(:tag_name, "table")
            wait_element 1

            snap = @utils.check_exists_datatable(1, "#{hash[:name]}", table)
            snap.find_element(:class, "snapshot_delete").click
        end

        def wait_element(secs = 2)
            sleep secs
        end
    end
end
