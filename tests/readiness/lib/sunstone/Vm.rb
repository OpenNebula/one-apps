require 'sunstone/Utils'

class Sunstone

    class Vm

        def initialize(sunstone_test)
            @general_tag = "instances"
            @resource_tag = "vms"
            @datatable = "dataTableVms"
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
        end

        def get_sunstone_server_conf()
          @utils.get_sunstone_server_conf()
        end

        def navigate_create
            if !$driver.find_element(:id, "#{@resource_tag}-tabcreate_buttons").displayed?
                @utils.navigate(@general_tag, @resource_tag)
            end
            element = @sunstone_test.get_element_by_id("#{@resource_tag}-tabcreate_buttons")
            element.find_element(:class, "action_button").click if element.displayed?
            @sunstone_test.get_element_by_id("vm_create_wrapper")
            sleep 0.5
        end

        def navigate_vm_datatable
            @utils.navigate(@general_tag, @resource_tag)
        end

        def get_vm_from_datatable(name)
            navigate_vm_datatable()
            table = @sunstone_test.get_element_by_id(@datatable)

            @utils.wait_element_by_id('vms-tabrefresh_buttons')

            vm = @utils.check_exists_datatable(2, name, table, 60) {
                # Refresh block
                @sunstone_test.get_element_by_css("#vms-tabrefresh_buttons>button").click
                sleep 1
            }

            vm
        end

        def navigate_vm(name)
            begin
                vm = get_vm_from_datatable(name)
                vm.click
            rescue StandardError => e
                @utils.save_temp_screenshot("navigate-to-vm-#{name}", e)
            end
        end

        def navigate_to_vm_detail_tab(name)
            xpath_tab = "
                //*[contains(@id, 'vms-tab-panelsTabs')]
                //*[contains(@class, 'tabs-title')]
                //*[starts-with(@id, 'vm_#{name}')]"

            # wait until form tab is loaded
            @utils.wait_cond({ :debug => "#{name} tab on vm detail" }, 10) {
                element = $driver.find_elements(:xpath, xpath_tab)
                break if element.size > 0 && element[0].displayed?
            }

            tab = @sunstone_test.get_element_by_xpath(xpath_tab)

            tab ? tab.click : fail("Tab on detail vm view: #{name} not exists")
        end

        def navigate_instantiate(template_name)
            self.navigate_create

            table = @sunstone_test.get_element_by_id('vm_create')

            template = @utils.check_exists_datatable(1, template_name, table, 60) {
                # Refresh block
                @sunstone_test.get_element_by_css('#refresh_button_vm_create').click
                sleep 1
            }

            template.click

            # waiting info template
            @utils.wait_cond({ :debug => "vm info" }, 60) {
                template_info = $driver.find_elements(:xpath, "//*[contains(@class, 'template-row')]")
                break if template_info.size > 0
            }
        end

        def change_instantiation_host(host_name)
            host_section_xpath = '//a[contains(string(), "Deploy VM in a specific Host")]'
            @sunstone_test.get_element_by_xpath(host_section_xpath).click

            
            table = @sunstone_test.get_element_by_xpath(host_section_xpath + '/parent::div/div//table')

            host = @utils.check_exists_datatable(1, host_name, table, 60) {
                # Refresh block
                @sunstone_test.get_element_by_xpath(host_section_xpath + '/parent::div/div//a').click
                sleep 1
            }

            host.click
        end

        def check_instantiation_empty_datastores()
            datastores_section_xpath = '//a[contains(string(), "Deploy VM in a specific Datastore")]'
            @sunstone_test.get_element_by_xpath(datastores_section_xpath).click
            
            table = @sunstone_test.get_element_by_xpath(datastores_section_xpath + '/parent::div/div//table')
            ds_empty = @sunstone_test.get_element_by_xpath(datastores_section_xpath + '/parent::div/div//td[contains(@class, "dataTables_empty")]')
            fail "Datastores expected to be empty" unless ds_empty
        end

        def check_instantiation_empty_vnets()
            network_section_xpath = '//*[contains(@id, "createVMFormWizard")]//div[@class="accordion_advanced"]/a[contains(string(), "Network")]'
            @sunstone_test.get_element_by_xpath(network_section_xpath).click
            @sunstone_test.get_element_by_xpath(network_section_xpath + '/parent::div//a[contains(@class, "provision_add_network_interface")]').click
            
            vnets_empty = @sunstone_test.get_element_by_xpath(network_section_xpath + '/parent::div/div//div[@class="no_auto"]//div[contains(@id,"vnet_nics_section")]//td[contains(@class, "dataTables_empty")]')
            fail "Networks expected to be empty" unless vnets_empty
        end

        def get_sunstone_config()
          YAML.load(File.read("#{ONE_ETC_LOCATION}/sunstone-server.conf"))
        end

        def check_leases(template, configure)
          rtn = false
          if template && configure
            template.each do |sched_action|
              if sched_action && sched_action["ACTION"] && configure[sched_action["ACTION"]]
                conf_action = configure[sched_action["ACTION"]]
                if sched_action["TIME"].to_i > conf_action["time"].to_i
                  rtn = true
                else
                  rtn = false
                  break
                end
              else
                rtn = false
                break
              end
            end
          else
            fail('Error: cannot find data of template or sunstone configure')
          end
          return rtn
        end

        def add_leases()
            xpath_button_leases = "//button[contains(@class, 'leases') and contains(@class, 'button')]"
            button_leases = @sunstone_test.get_element_by_xpath(xpath_button_leases)
            button_leases.nil? ? fail('Error: cannot find vnc button') : button_leases.click
            xpath_leases_modal = "//div[@id='addLeasesDialog']"
            leases_modal = @sunstone_test.get_element_by_xpath(xpath_leases_modal)
            sleep 2
            if leases_modal.nil?
              fail('Error: cannot find modal leases')
            else
              button_confirm_add_leases = leases_modal.find_element(:xpath, "//button[@id='generic_confirm_proceed']")
              button_confirm_add_leases.nil? ? fail('Error: cannot find confirm leases button') : button_confirm_add_leases.click
              sleep 2
            end
        end

        def fill_instantiate_fields(json)
            xpath_form = "//*[@id='createVMFormWizard']"
            xpath_vm_name_input = xpath_form + "//input[@id='vm_name']"
            @utils.fill_input_by_finder(:xpath, xpath_vm_name_input, json[:name]) if json[:name]

            # update template memory
            if json[:mem]
                # select memory in GB
                xpath_mem_unit = xpath_form + "//*[contains(@class, 'mb_input_wrapper')]//select[@class='mb_input_unit']"
                mem_select = @sunstone_test.get_element_by_xpath(xpath_mem_unit)
                option = Selenium::WebDriver::Support::Select.new(mem_select)
                option.select_by(:value, "GB")

                xpath_mem_value = xpath_form + "//*[contains(@class, 'mb_input')]//input[contains(@class, 'visor')]"
                @utils.fill_input_by_finder(:xpath, xpath_mem_value, json[:mem])
            end

            # update template cpu
            xpath_cpu_value = xpath_form + "//div[@class='cpu_input']//input"
            @utils.fill_input_by_finder(:xpath, xpath_cpu_value, json[:cpu]) if json[:cpu]

            # update template vcpu
            xpath_vcpu_value = xpath_form + "//div[@class='vcpu_input']//input"
            @utils.fill_input_by_finder(:xpath, xpath_vcpu_value, json[:vcpu]) if json[:vcpu]
        end

        def fill_os_booting(json, order=true)
            if json[:os]
                xpath_os_accordion = "//*[@class='accordion_advanced']/a[contains(., 'Booting')]"
                os_advanced = @sunstone_test.get_element_by_xpath(xpath_os_accordion)
                os_advanced.click if os_advanced && os_advanced.displayed?

                xpath_os_table = "//table[contains(@class, 'boot-order-instantiate')]"

                # disable all
                all_cbs = $driver.find_elements(:xpath, "#{xpath_os_table}//tr//input")
                all_cbs.each { |disk_cb|
                    disk_cb.click if disk_cb && disk_cb.attribute('checked') == 'true'
                }

                json[:os].each_with_index { |disk, final_position|
                    xpath_disk_row = "#{xpath_os_table}//tr[@value='#{disk}']"

                    xpath_disk_cb = "#{xpath_disk_row}//input"
                    @sunstone_test.get_element_by_xpath(xpath_disk_cb).click

                    # Sort disks by index
                    next unless order

                    loop do
                        # refresh disks list
                        all_disks = $driver.find_elements(:xpath, "#{xpath_os_table}//tr")

                        # get disk row position
                        disk_position = all_disks.index { |disk_row| disk_row.attribute('value') == disk }

                        break if !disk_position.nil? && disk_position == final_position

                        if disk_position > final_position
                            xpath_btn_up = "#{xpath_disk_row}//*[contains(@class, 'boot-order-instantiate-up')]"
                            btn_up = @sunstone_test.get_element_by_xpath(xpath_btn_up).click
                        else
                            xpath_btn_down = "#{xpath_disk_row}//*[contains(@class, 'boot-order-instantiate-down')]"
                            btn_down = @sunstone_test.get_element_by_xpath(xpath_btn_down).click
                        end
                    end
                }
            end
        end

        def instantiate(json)
            self.fill_instantiate_fields(json)
            self.fill_os_booting(json)

            @utils.submit_create(@resource_tag)
        end

        def add_network(json, nic_cont)
            if json[:vnet]
                xpath_network_accordion = "//*[@class='accordion_advanced']/a[contains(., 'Network')]"
                vnet_advanced = @sunstone_test.get_element_by_xpath(xpath_network_accordion)
                vnet_advanced.click if vnet_advanced && vnet_advanced.displayed?

                json[:vnet].each { |vnet|
                    @sunstone_test.get_element_by_class("provision_add_network_interface").click

                    name = vnet.is_a?(String) ? vnet : vnet[:name]

                    section_nic = vnet_advanced.find_elements(:xpath, "//div[@class='no_auto']")[nic_cont]

                    # table[0] Vnets
                    # table[1] Security Groups
                    table = section_nic.find_elements(tag_name: "table")[0]

                    vnet_row = @utils.check_exists_datatable(1, name, table, 10)
                    vnet_row.click

                    if !vnet.is_a? String
                        if vnet[:alias] && vnet[:alias] != 'NIC0'
                            interface_type = section_nic.find_elements(:xpath, "//label[contains(@for, '_interface_type')]")[nic_cont]
                            interface_type.click

                            alias_parent = section_nic.find_elements(:xpath, "//select[contains(@id, 'alias_parent')]")[nic_cont]
                            option = Selenium::WebDriver::Support::Select.new(alias_parent)
                            option.select_by(:value, vnet[:alias])
                        end

                        if vnet[:rdp] == 'yes'
                            rdp_button = section_nic.find_elements(:xpath, "//label[contains(@for, '_rdp')]")[nic_cont]
                            rdp_button.click
                        end

                        if vnet[:ssh] == 'yes'
                            ssh_button = section_nic.find_elements(:xpath, "//label[contains(@for, '_ssh')]")[nic_cont]
                            ssh_button.click
                        end
                    end

                    nic_cont += 1
                }
            end
        end

        def check(num_col, compare, hash=[])
            @utils.navigate(@general_tag, @resource_tag)
            tmpl = @utils.check_exists(num_col, compare, @datatable)
            if tmpl
                tmpl.click

                navigate_to_vm_detail_tab('template')

                pre = $driver.find_elements(:xpath, "//div[@id='vm_template_tab']//pre")[1]
                hash = @utils.check_elements_raw(pre, hash)

                if !hash.empty?
                    fail "Check fail: Not Found all keys"
                    hash.each{ |obj| puts "#{obj[:key]} : #{obj[:value]}" }
                end
            end
        end

        def snapshot(vm_name, hash = {})
            navigate_vm(vm_name)
            navigate_to_vm_detail_tab('snapshot')

            if !hash.empty?
                sleep 3
                vm_snapshot(hash)
            end
        end

        def disk_snapshot(vm_name, hash = {})
            navigate_vm(vm_name)
            navigate_to_vm_detail_tab('storage')

            if !hash.empty?
                sleep 3
                disk_snapshot_funct(hash)
            end
        end

        def snapshot_rename(vm_name, hash = {})
            navigate_vm(vm_name)
            navigate_to_vm_detail_tab('storage')

            if !hash.empty?
                sleep 3
                disk_snapshot_rename(hash)
            end
        end

        def check_vm_states(vm_name, possible_states = [])
            navigate_vm(vm_name)

            @utils.wait_element_by_id('vm_info_tab-label')

            xpath_refresh_btn = "//*[@id='vms-tabrefresh_buttons']/button"

            @utils.wait_cond({ :debug => 'vm header states' }, 60) do |current_time|
                @sunstone_test.get_element_by_xpath(xpath_refresh_btn).click

                vm_tab = @sunstone_test.get_element_by_id('vms-tab')
                info_header_state = vm_tab.find_element(:class, 'resource-info-header-small')


                exist = possible_states.include? info_header_state.text()

                return exist if (current_time == 60 || exist == true)
            end
        end

        def add_labels(name_vm, arr_labels = [])
            navigate_vm(name_vm)
            sleep 2

            span = @sunstone_test.get_element_by_id("vms-tablabels_buttons")
            span.find_element(:tag_name, "button").click

            div = @sunstone_test.get_element_by_id("vms-tabLabelsDropdown")
            arr_labels.each { |label|
                sleep 1
                input = div.find_element(:class, "newLabelInput")
                input.clear
                input.send_keys label
                $driver.action.send_keys(:enter).perform # enter
            }

            sleep 10
            span.find_element(:tag_name, "button").click
        end

        def change_permission(vm_name, permissions)
            navigate_vm(vm_name)

            xpath_permission_table = "//table[contains(@class, 'vm_permissions_table')]/tbody[1]"

            if permissions[:owner]
                xpath_owner = "#{xpath_permission_table}/tr[1]//input"
                change_permission_row(permissions[:owner], xpath_owner)
            end

            if permissions[:group]
                xpath_group = "#{xpath_permission_table}/tr[2]//input"
                change_permission_row(permissions[:group], xpath_group)
            end

            if permissions[:other]
                xpath_other = "#{xpath_permission_table}/tr[3]//input"
                change_permission_row(permissions[:other], xpath_other)
            end
        end

        private

        def change_permission_row(permission_row, xpath_inputs)
            # permission_row should be a string with 3 characters combination: 'uma'
            # u: user permission
            # m: manage permission
            # a: admin permission
            # -: disabled the permission in position of char. eg: '---' disable all

            ['u', 'm', 'a'].each do |permission_char|
                xpath_permission_cb = "#{xpath_inputs}[contains(@class, '_#{permission_char}')]"

                permission_cb = false

                @utils.wait_cond({ :debug => "permission cb #{permission_char}" }, 10) {
                    permission_cb = @sunstone_test.get_element_by_xpath(xpath_permission_cb)
                }

                # check if permission char exists in the row. eg 'a' exists in 'u-a'
                char_exists_in_row = permission_row.include?(permission_char)

                check_it   = char_exists_in_row && !permission_cb.attribute('checked')
                uncheck_it = !char_exists_in_row && permission_cb.attribute('checked')

                if check_it || uncheck_it
                    permission_cb.click

                    # waiting until vm detail view is reloading
                    sleep 5
                end
            end
        end

        def vm_snapshot(name)
            xpath_btn_take_snap = "//*[@id='snapshot_form']//button[@id='take_snapshot']"
            btn_take_snap = @sunstone_test.get_element_by_xpath(xpath_btn_take_snap)
            btn_take_snap.click if btn_take_snap.enabled?

            @utils.wait_element_by_id("snapshotVMDialog")
            xpath_snapshot_name = "//*[@id='snapshotVMDialog']//input[@id='snapshot_name']"
            @utils.fill_input_by_finder(:xpath, xpath_snapshot_name, name)

            xpath_success = "//*[@id='snapshotVMDialog']//button[@type='submit']"
            @sunstone_test.get_element_by_xpath(xpath_success).click
        end

        def disk_snapshot_funct(snap_name)
            xpath_btn_take_snap = "//*[@id='tab_storage_form']//a[@href='VM.disk_snapshot_create']"
            btn_take_snap = @sunstone_test.get_element_by_xpath(xpath_btn_take_snap)
            btn_take_snap.click if btn_take_snap.enabled?

            @utils.wait_element_by_id("diskSnapshotVMDialogForm")
            xpath_snapshot_name = "//*[@id='diskSnapshotVMDialogForm']//input[@id='snapshot_name']"
            @utils.fill_input_by_finder(:xpath, xpath_snapshot_name, snap_name)

            xpath_success = "//*[@id='diskSnapshotVMDialogForm']//button[@type='submit']"
            @sunstone_test.get_element_by_xpath(xpath_success).click
        end

        def disk_snapshot_rename(snap_rename)
            xpath_open_control = "//*[@id='tab_storage_form']//tr[@disk_id='0']//td[@class='open-control']"
            @sunstone_test.get_element_by_xpath(xpath_open_control).click

            xpath_snapshot_id = "//*[@id='tab_storage_form']//input[@snapshot_id='0']"
            @sunstone_test.get_element_by_xpath(xpath_snapshot_id).click

            xpath_button_rename = "//*[@id='tab_storage_form']//button[contains(@class, 'disk_snapshot_rename')]"
            @sunstone_test.get_element_by_xpath(xpath_button_rename).click

            @utils.wait_element_by_id("diskSnapshotRenameVMDialogForm")
            xpath_snapshot_name = "//*[@id='diskSnapshotRenameVMDialogForm']//input[@id='snapshot_new_name']"
            @utils.fill_input_by_finder(:xpath, xpath_snapshot_name, snap_rename)

            xpath_success = "//*[@id='diskSnapshotRenameVMDialogForm']//button[@type='submit']"
            @sunstone_test.get_element_by_xpath(xpath_success).click
        end

        public

        def get_nics_vm(name_vm)
            rtn = []
            name_vm_with_id = "#{name_vm}"

            navigate_vm(name_vm_with_id)
            navigate_to_vm_detail_tab('network')

            datatable = @sunstone_test.get_element_by_css(".nics_table tbody")
            if(datatable)
                rtn = datatable.find_elements(tag_name: "tr")
            end
            return rtn
        end

        def get_nics_from_vm_dt(name_vm)
            navigate_vm_datatable

            row_vm = get_vm_from_datatable(name_vm)

            # (7) seven is the column number in vms datatable
            column = row_vm.find_elements(tag_name: 'td')[7]

            @utils.hover_element(column)

            return column.find_element(:class, 'menu-hide').text
        end

        def find_network_checkboxes(template_name)
            navigate_instantiate(template_name)

            vnet_advanced = @sunstone_test.get_element_by_xpath("(//a[contains(@class, 'accordion_advanced_toggle')])[1]")
            vnet_advanced.click if vnet_advanced && vnet_advanced.displayed?

            @sunstone_test.get_element_by_class("provision_add_network_interface").click

            return {
                # interface type (nic/nic alias)
                :interface_type => $driver.find_elements(:xpath, "(//*[contains(@id, 'interface_type_section')])").size > 0,

                # network selection (automatic)
                :net_selection => $driver.find_elements(:xpath, "(//*[contains(@id, 'network_selection')])").size > 0,

                # RDP connection (on/off)
                :rdp_connection => $driver.find_elements(:xpath, "(//*[contains(@id, 'rdp_wrapper')])").size > 0,

                # SSH connection (on/off)
                :ssh_connection => $driver.find_elements(:xpath, "(//*[contains(@id, 'ssh_wrapper')])").size > 0
            }
        end

        def hot_resize(name_vm, value, xpath_input)
            navigate_vm(name_vm)
            navigate_to_vm_detail_tab('capacity')

            @sunstone_test.get_element_by_id('resize_capacity').click

            @utils.fill_input_by_finder(:xpath, xpath_input, value)

            @sunstone_test.get_element_by_id('resize_capacity_button').click
        end

        def resize_memory(name_vm, value)
            xpath_memory_input = '//*[@id="resizeVMDialogForm"]/div[2]/div/div/div/div[1]/input[2]'
            hot_resize(name_vm, value, xpath_memory_input)
        end

        def resize_vcpu(name_vm, value)
            xpath_vcpu_input = '//*[@id="resizeVMDialogForm"]/div[3]/div[2]/div/input'
            hot_resize(name_vm, value, xpath_vcpu_input)
        end

        ########################################################################
        # REMOTE ACTIONS FUNCTIONS
        ########################################################################

        def get_remote_buttons(name_vm)
            navigate_vm(name_vm)
            sleep 2

            ## Open remote buttons dropdown pane if not open
            xpath_remotes_buttons = "//button[@data-toggle='vms-tabvmsremote_buttons']"
            remotes_buttons = @sunstone_test.get_element_by_xpath(xpath_remotes_buttons)
            remotes_buttons.click if remotes_buttons.attribute('aria-expanded') === "false"

            sleep 0.5
            $driver.find_elements(:xpath, "//*[@id='vms-tabvmsremote_buttons']//a").map { |button|
                button.attribute('href').split('.').last if button.displayed?
            }
        end

        def open_remote_connection(vm_name, action, sunstone_tab)
            actions = ['save_virt_viewer', 'guac_vnc', 'guac_ssh', 'guac_rdp', 'startvmrc']

            fail "Action should be: #{actions.join(', ')}" if !actions.include?(action)

            navigate_vm(vm_name)
            navigate_to_vm_detail_tab('info')

            xpath_refresh_btn = "//*[@id='vms-tabrefresh_buttons']/button"
            xpath_state_running = "//*[@id='lcm_state_value' and contains(., 'RUNNING')]"

            @utils.wait_cond({ :debug => "VM state is't running" }, 10) do
                @sunstone_test.get_element_by_xpath(xpath_refresh_btn).click

                # break if vm is running
                @sunstone_test.get_element_by_xpath(xpath_state_running) != false
            end

            @sunstone_test.get_element_by_xpath("//*[@id='vmsremote_buttons']").click

            @utils.wait_element_by_id('vms-tabvmsremote_buttons')

            xpath_action_btn = "//*[@id='vms-tabvmsremote_buttons']//*[@href='VM.#{action}']"
            @sunstone_test.get_element_by_xpath(xpath_action_btn).click

            # Waiting until number of tabs is more than 1
            wait_args = { :debug => "#{action} action tab",
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

        ########################################################################
        # VM ACTIONS
        ########################################################################

        def terminate_hard(vm_name)
            navigate_vm(vm_name)

            @utils.wait_element_by_id('vm_info_tab-label')

            xpath_terminate_btn = "//button[@data-toggle='vms-tabvmsdelete_buttons']"
            @sunstone_test.get_element_by_xpath(xpath_terminate_btn).click

            @utils.wait_element_by_id('vms-tabvmsdelete_buttons')

            xpath_terminate_hard = "//ul[@id='vms-tabvmsdelete_buttons']/li/a[@href='VM.terminate_hard']"
            @sunstone_test.get_element_by_xpath(xpath_terminate_hard).click

            @utils.wait_element_by_id('confirm_tip')

            xpath_confirm = "//button[@id='confirm_proceed']"
            @sunstone_test.get_element_by_xpath(xpath_confirm).click

        end

        def terminate(vm_name)
            navigate_vm(vm_name)

            @utils.wait_element_by_id('vm_info_tab-label')

            xpath_terminate_btn = "//button[@data-toggle='vms-tabvmsdelete_buttons']"
            @sunstone_test.get_element_by_xpath(xpath_terminate_btn).click

            @utils.wait_element_by_id('vms-tabvmsdelete_buttons')

            xpath_terminate_hard = "//ul[@id='vms-tabvmsdelete_buttons']/li/a[@href='VM.terminate']"
            @sunstone_test.get_element_by_xpath(xpath_terminate_hard).click

            @utils.wait_element_by_id('confirm_tip')

            xpath_confirm = "//button[@id='confirm_proceed']"
            @sunstone_test.get_element_by_xpath(xpath_confirm).click
        end

        def resume(vm_name)
            navigate_vm(vm_name)

            @utils.wait_element_by_id('vm_info_tab-label')

            xpath_resume_btn = "//button[@href='VM.resume']"
            @sunstone_test.get_element_by_xpath(xpath_resume_btn).click
        end

        def stop(vm_name)
            navigate_vm(vm_name)

            @utils.wait_element_by_id('vm_info_tab-label')

            xpath_stop_btns = "//button[@data-toggle='vms-tabvmsstop_buttons']"
            @sunstone_test.get_element_by_xpath(xpath_stop_btns).click

            @utils.wait_element_by_id('vms-tabvmsstop_buttons')

            xpath_stop_btn = "//ul[@id='vms-tabvmsstop_buttons']/li/a[@href='VM.stop']"
            @sunstone_test.get_element_by_xpath(xpath_stop_btn).click
        end

        def suspend(vm_name)
            navigate_vm(vm_name)

            @utils.wait_element_by_id('vm_info_tab-label')

            xpath_stop_btns = "//button[@data-toggle='vms-tabvmsstop_buttons']"
            @sunstone_test.get_element_by_xpath(xpath_stop_btns).click

            @utils.wait_element_by_id('vms-tabvmsstop_buttons')

            xpath_suspend_btn = "//ul[@id='vms-tabvmsstop_buttons']/li/a[@href='VM.suspend']"
            @sunstone_test.get_element_by_xpath(xpath_suspend_btn).click
        end

        def undeploy(vm_name)
            navigate_vm(vm_name)

            @utils.wait_element_by_id('vm_info_tab-label')

            xpath_stop_btns = "//button[@data-toggle='vms-tabvmsstop_buttons']"
            @sunstone_test.get_element_by_xpath(xpath_stop_btns).click

            @utils.wait_element_by_id('vms-tabvmsstop_buttons')

            xpath_undeploy_btn = "//ul[@id='vms-tabvmsstop_buttons']/li/a[@href='VM.undeploy']"
            @sunstone_test.get_element_by_xpath(xpath_undeploy_btn).click
        end

        def deploy(vm_name, host_name)
            navigate_vm(vm_name)

            @utils.wait_element_by_id('vm_info_tab-label')

            xpath_planification_btn = "//button[@data-toggle='vms-tabvmsplanification_buttons']"
            @sunstone_test.get_element_by_xpath(xpath_planification_btn).click

            @utils.wait_element_by_id('vms-tabvmsplanification_buttons')

            xpath_deploy_btn = "//*[@id='vms-tabvmsplanification_buttons']//*[@href='VM.deploy']"
            @sunstone_test.get_element_by_xpath(xpath_deploy_btn).click

            @utils.wait_element_by_id('deployVMDialog')

            xpath_host_table = "//*[@id='deployVMDialog']//table[@id='deploy_vm']"
            host_table = @sunstone_test.get_element_by_xpath(xpath_host_table)

            host = @utils.check_exists_datatable(1, host_name, host_table, 10) {
                # Refresh block
                @sunstone_test.get_element_by_id('refresh_button_deploy_vm').click
                sleep 1
            }

            host.click

            xpath_submit_btn = "//*[@id='deployVMDialog']//button[@id='deploy_vm_proceed']"
            submit_btn = @sunstone_test.get_element_by_xpath(xpath_submit_btn)
            submit_btn.click
        end

    end

end
