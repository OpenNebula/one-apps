require 'sunstone/Utils'
require 'sunstone/Template'

class Sunstone
    class Flow
        def initialize(sunstone_test)
            @services_general_tag = "instances"
            @services_resource_tag = "oneflow-services"
            @services_datatable = "dataTableService"

            @roles_datatable = "datatable_roles_service_roles_tab"

            @templates_general_tag = "templates"
            @templates_resource_tag = "oneflow-templates"
            @templates_datatable = "dataTableServiceTemplates"

            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
            @template = Template.new(sunstone_test)
        end

        def get_sunstone_server_conf()
          @utils.get_sunstone_server_conf()
        end

        def navigate_service_dt
            dataTableService = "//*[@id='dataTableServiceContainer']"
            if !@sunstone_test.get_element_by_xpath(dataTableService)
                @utils.navigate(@services_general_tag, @services_resource_tag)
                sleep 1
            end
        end

        def navigate_template_dt
            dataTableServiceTemplates = "//*[@id='dataTableServiceTemplatesContainer']"
            if !@sunstone_test.get_element_by_xpath(dataTableServiceTemplates)
                @utils.navigate(@templates_general_tag, @templates_resource_tag)
                sleep 1
            end
        end

        def select_by_column(data, column, datatable, fail_message = "data: #{data.to_s}, not exists")
            row = @utils.check_exists(column, data.to_s, datatable)
            row ? row.click : (fail fail_message.to_s) 
        end

        def select_by_column_with_reload(data, column, datatable, reload = "", fail_message = "data: #{data.to_s}, not exists", time = 5)
            sleep 1
            row = @utils.check_exists(column, data.to_s, datatable)
            if row
                row.click
            else
                @utils.save_temp_screenshot("select_by_column_with_reload_tryN#{time}")
                if time > 0 && reload != ''
                    element = $driver.find_element(:id, reload)
                    element.click if element.displayed?
                    self.select_by_column_with_reload(data, column, datatable, reload, fail_message, time-1)
                else
                    fail fail_message.to_s
                end
            end
        end

        def navigate_create
            ## Open dialog
            xpath_dg_button = "//button[@data-toggle='oneflow-templates-tabcreate_buttons_flatten']"
            @sunstone_test.get_element_by_xpath(xpath_dg_button).click
            
            ## Click on create template button
            xpath_create_button = "//li/a[@href='ServiceTemplate.create_dialog']"
            @sunstone_test.get_element_by_xpath(xpath_create_button).click

            sleep 1
        end
        
        def navigate_instantiate
            ## Open dialog
            xpath_dg_button = "//button[@data-toggle='oneflow-templates-tabcreate_buttons_flatten']"
            @sunstone_test.get_element_by_xpath(xpath_dg_button).click
            
            ## Click on instantiate template button
            xpath_instantiate_button = "//li/a[@href='ServiceTemplate.instantiate_dialog']"
            @sunstone_test.get_element_by_xpath(xpath_instantiate_button).click

            sleep 1
        end

        def navigate_create_instantiate(service="", role_name="", vmgroup_name="")
          self.navigate_service_dt
          xpath_create_btn = "//button[@href ='Service.create_dialog']"
          @sunstone_test.get_element_by_xpath(xpath_create_btn).click
          @utils.wait_element_by_id('service_create')

          svc_tmp_datatable = @sunstone_test.get_element_by_css("#service_create")
          @utils.find_in_datatable_paginated(3, service, svc_tmp_datatable).click

          @utils.wait_element_by_xpath('//div[@class="instantiate_wrapper"]')
          
          xpath_dropdown = "//select[@data-role='#{role_name}']"
          dropdown = @sunstone_test.get_element_by_xpath(xpath_dropdown)
          @sunstone_test.click_option_by_text(dropdown, vmgroup_name)

          xpath_create_svc_btn = "//span[@id='oneflow-services-tabsubmit_button']/button"
          @sunstone_test.get_element_by_xpath(xpath_create_svc_btn).click
        end

        def fill_instantiate_service_form(service, cloudview = false)
            xpath_instantiate_form = if cloudview
              "//form[@id='provision_create_flow']"
            else
              "//*[@form-panel-id='instantiateServiceTemplateForm']"
            end

            xpath_input_service_name = if cloudview
              "#{xpath_instantiate_form}//input[@id='flow_name']"
            else
              "#{xpath_instantiate_form}//input[@id='service_name']"
            end

            @utils.fill_input_by_finder(:xpath, xpath_input_service_name, service[:info][:name]) if service[:info][:name]

            service[:roles].each_with_index { |role, index|
                if role[:inputs]
                    xpath_wrapper = if cloudview
                        "#{xpath_instantiate_form}//*[@id='provision_create_flow_role_#{index}']"
                    else
                        "#{xpath_instantiate_form}//*[@id='user_input_role_#{index}']"
                    end

                    @utils.wait_element_by_xpath(xpath_wrapper)

                    @template.fill_user_inputs(role[:inputs], xpath_wrapper) 
                end
            } if service[:roles]
        end

        def fill_service_template_info(info)
            fail "Services needs a name at least" if !info || !info[:name]

            xpath_name = "//*[@id='createServiceTemplateFormWizard']//input[@id='service_name']"
            xpath_description = "//*[@id='createServiceTemplateFormWizard']//textarea[@id='description']"
            xpath_advance_service_parameter = "//*[@id='createServiceTemplateFormWizard']//*[contains(text(),'service parameters')]"

            begin
              @utils.fill_input_by_finder(:xpath, xpath_name, info[:name]) if info[:name]
              @utils.fill_input_by_finder(:xpath, xpath_description, info[:description]) if info[:description]
              if info[:automatic_deletion]
                @sunstone_test.get_element_by_xpath(xpath_advance_service_parameter).click
                @sunstone_test.get_element_by_id('automatic_deletion').click
              end
            rescue StandardError => e
              return
            end
        end

        def fill_network_configuration(network, index)
            xpath_row_info = "//*[@class='accordion_advanced']//tr[contains(@id, 'network')]"

            xpath_name = "(#{xpath_row_info}//*[contains(@class, 'service_network_name')])[#{index}]"
            @utils.fill_input_by_finder(:xpath, xpath_name, network[:name]) if network[:name]

            xpath_description = "(#{xpath_row_info}//*[contains(@class, 'service_network_description')])[#{index}]"
            @utils.fill_input_by_finder(:xpath, xpath_description, network[:description]) if network[:description]

            if network[:type]
                xpath_type = "(#{xpath_row_info}//*[contains(@class, 'service_network_type')])[#{index}]"
                type_select = @sunstone_test.get_element_by_xpath(xpath_type)
                option = Selenium::WebDriver::Support::Select.new(type_select)
                option.select_by(:value, network[:type])
            end

            if network[:network_id]
                xpath_network_id = "(#{xpath_row_info}//*[contains(@class, 'service_network_id')])[#{index}]"
                network_select = @sunstone_test.get_element_by_xpath(xpath_network_id)
                option = Selenium::WebDriver::Support::Select.new(network_select)
                option.select_by(:value, network[:network_id])
            end

            xpath_extra = "(#{xpath_row_info}//*[contains(@class, 'service_network_extra')])[#{index}]"
            @utils.fill_input_by_finder(:xpath, xpath_extra, network[:extra]) if network[:extra]
        end

        def fill_service_template_networks(networks = nil)
            return if networks.nil? || networks.length == 0

            xpath_network_configuration_btn = "//*[@class='accordion_advanced']/a[contains(., 'Network')]"
            network_configuration_btn = @sunstone_test.get_element_by_xpath(xpath_network_configuration_btn)

            xpath_add_network_btn = "//*[@class='accordion_advanced']//*[contains(@class, 'add_service_network')]"
            add_network_btn = @sunstone_test.get_element_by_xpath(xpath_add_network_btn)
            
            # Open network configuration if content is closed
            if add_network_btn == false
                network_configuration_btn.click
                # Looking for button again
                add_network_btn = @sunstone_test.get_element_by_xpath(xpath_add_network_btn)
            end

            networks.each_with_index { |network, index|
                add_network_btn.click
                self.fill_network_configuration(network, index + 1)
            }
        end

        def fill_service_template_leases_actions()
            accordion = nil
            begin
                xpath = "//div[@class='accordion_advanced']//a[contains(text(), 'Service Scheduled Actions')]"
                accordion = @sunstone_test.get_element_by_xpath(xpath)
                accordion.click
            rescue StandardError => e
                fail "cannot find schedule actions form"
            end

            begin
                xpath_table = "//table[@id='sched_service_create_actions_table']"
                @utils.wait_element_by_xpath(xpath_table)
                xpath_leases_btn = "//button[@id='leases_btn']"
                @sunstone_test.get_element_by_xpath(xpath_leases_btn).click
                accordion.click
            rescue StandardError => e
                fail "cannot find leases button"
            end
        end

        def fill_clone_dialog(name, mode = "none")
            xpath_input_name = "//form[@id='cloneServiceTemplateDialogForm']//input[@type='text']"
            @utils.fill_input_by_finder(:xpath, xpath_input_name, name) if name
            
            ## mode recursive:
            ##      "none"      => only service template
            ##      "templates" => Copy all vms template too
            ##      "all"       => Copy all images too
            if mode != "none"
                xpath_cb_vms = "//form[@id='cloneServiceTemplateDialogForm']//input[@id='clone-vms']"
                @sunstone_test.get_element_by_xpath(xpath_cb_vms).click
                if mode == "all"
                    sleep 1
                    xpath_cb_images = "//form[@id='cloneServiceTemplateDialogForm']//input[@id='clone-images']"
                    @sunstone_test.get_element_by_xpath(xpath_cb_images).click
                end
            end
        end

        #----------------------------------------------------------------------
        #----------------------------------------------------------------------

        def fill_template_role_info(id_role, template_role, xpath_role)
            fail "Role template needs a name at least" if !template_role || !template_role[:name]

            xpath_name = "#{xpath_role}//input[@id='role_name']"
            @utils.fill_input_by_finder(:xpath, xpath_name, template_role[:name]) if template_role[:name]

            xpath_cardinality = "#{xpath_role}//input[@id='cardinality']"
            @utils.fill_input_by_finder(:xpath, xpath_cardinality, template_role[:cardinality]) if template_role[:cardinality]

            if template_role[:template_vm_id]
                self.select_by_column_with_reload(
                    template_role[:template_vm_id],
                    0,
                    "roleTabTemplates#{id_role}",
                    "refresh_button_roleTabTemplates#{id_role}",
                    "Vm template id: #{template_role[:template_vm_id].to_s} not exists")
            else
                fail "Role template needs a template vm"
            end
        end

        def fill_template_role_networks(id_role, networks, xpath_role)
            return if networks.nil? || networks.length == 0

            xpath_accordion_btn, xpath_accordion_content = self.open_role_accordion_content(xpath_role, 'network')

            networks.each { |network|
                xpath_network_cb = "#{xpath_accordion_content}//input[starts-with(@id, '#{id_role}Tab') and @value='#{network[:name]}']"
                network_cb = @sunstone_test.get_element_by_xpath(xpath_network_cb)
                network_cb.click
    
                if network[:alias]
                    data_index = network_cb.attribute('data-index')
    
                    xpath_alias_network = "#{xpath_accordion_content}//input[starts-with(@id, '#{id_role}Tab') and @value='#{network[:alias]}']"
                    alias_data_index = @sunstone_test.get_element_by_xpath(xpath_alias_network).attribute('data-index')
                
                    xpath_alias_cb = "#{xpath_accordion_content}//input[starts-with(@id, 'alias_#{id_role}Tab_#{data_index}_name')]"
                    @sunstone_test.get_element_by_xpath(xpath_alias_cb).click
    
                    xpath_parent_select = "#{xpath_accordion_content}//select[starts-with(@id, 'parent_#{id_role}Tab_#{data_index}_name')]"
                    parent_select = @sunstone_test.get_element_by_xpath(xpath_parent_select)
                    option = Selenium::WebDriver::Support::Select.new(parent_select)
                    option.select_by(:value, alias_data_index)
                end
            }
        end

        def fill_template_role_elasticity(id_role, elasticity = {}, xpath_role)
            return if elasticity.nil? || elasticity.empty?
            
            self.open_role_accordion_content(xpath_role, 'elasticity')

            xpath_min_vms = "#{xpath_role}//input[@id='min_vms']"
            @utils.fill_input_by_finder(:xpath, xpath_min_vms, elasticity[:min_vms]) if elasticity[:min_vms]

            xpath_max_vms = "#{xpath_role}//input[@id='max_vms']"
            @utils.fill_input_by_finder(:xpath, xpath_max_vms, elasticity[:max_vms]) if elasticity[:max_vms]

            xpath_cooldown = "#{xpath_role}//input[@id='cooldown']"
            @utils.fill_input_by_finder(:xpath, xpath_cooldown, elasticity[:cooldown]) if elasticity[:cooldown]

            # TODO elasticity_policies = elasticity[:elasticity_policies] || []
            # TODO scheduled_policies = elasticity[:scheduled_policies] || []
        end

        def open_role_accordion_content(xpath_base = '', accordion_title)
            xpath_role_accordion_btn = "#{xpath_base}//*[@class='accordion_advanced']/a[contains(., '#{accordion_title}')]"
            role_accordion_btn = @sunstone_test.get_element_by_xpath(xpath_role_accordion_btn)

            xpath_accordion_content = "#{xpath_role_accordion_btn}/following-sibling::*[@class='content']"
            role_accordion_content = @sunstone_test.get_element_by_xpath(xpath_accordion_content)

            begin
                # Click to open accordion if content is closed
                if role_accordion_content == false
                    role_accordion_btn.click
                end
            rescue Selenium::WebDriver::Error::ElementClickInterceptedError
                $driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
                role_accordion_btn.click
            end

            return xpath_role_accordion_btn, xpath_accordion_content
        end

        def create_template(template)
            fail "Service template needs at least one role" if !template[:roles]

            self.navigate_template_dt
            self.navigate_create

            self.fill_service_template_info(template[:info])
            self.fill_service_template_networks(template[:networks])
            self.fill_service_template_leases_actions if template[:leases]
            
            ## add number of roles
            Array.new(template[:roles].length-1).each do
                @sunstone_test.get_element_by_id("tf_btn_roles").click
                sleep 0.5
            end
            
            template[:roles].each_with_index do |role, index|
                id = "role#{index}"

                # click on role tab
                role_tab = @sunstone_test.get_element_by_xpath("//a[@id='#{id}']")

                begin
                    role_tab.click
                rescue Selenium::WebDriver::Error::ElementClickInterceptedError
                    $driver.execute_script("window.scrollTo(0, 300);")
                    role_tab.click
                end

                xpath_role_content = "//div[@id='#{id}Tab']"

                self.fill_template_role_info(id, role, xpath_role_content)
                self.fill_template_role_networks(id, role[:networks], xpath_role_content)
                self.fill_template_role_elasticity(id, role[:elasticity], xpath_role_content)
            end
            sleep 1

            ## Submit template
            xpath_btn_submit = "//span[@id='oneflow-templates-tabsubmit_button']/button"
            @sunstone_test.get_element_by_xpath(xpath_btn_submit, true).click
        end

        def create_and_instantiate(service_template, service_name)
          create_template(service_template)
          @sunstone_test.wait_resource_create("flow-template", service_name, 180)
          instantiate_template(service_name, service_template)
          @sunstone_test.wait_resource_create("flow", service_name, 120)
          navigate_service_dt()
          table = @sunstone_test.get_element_by_id("dataTableService")
          service = @utils.find_in_datatable_paginated(4, service_name, table)
          if service
            service.click
          else
            fail "service: #{opts[:host_name]} not exists"
          end
        end

        def add_charters_service(service_name)
          navigate_service_dt()
          table = @sunstone_test.get_element_by_id("dataTableService")
          service = @utils.find_in_datatable_paginated(4, service_name, table)
          if service
            service.click
            actionsTab = @sunstone_test.get_element_by_id("service_sched_action_tab-label")
            if actionsTab
              actionsTab.click
              sleep 5
              sched_xpath = '//*[@class="sched_place"]//button[@id="leases_btn"]'
              charter_button = @sunstone_test.get_element_by_xpath(sched_xpath)
              if charter_button
                charter_button.click
                sleep 5
                button_confirm = @sunstone_test.get_element_by_id("generic_confirm_proceed")
                if button_confirm
                  button_confirm.click
                  sleep 10
                end
              else
                fail "cannot find charter button"
              end
            else
              fail "cannot find tab Actions"
            end
          else
            fail "service: #{opts[:host_name]} not exists"
          end
        end

        def delete_template(template_name, type='none')
            self.navigate_template_dt
            self.refresh_template_dt_until_row(template_name.to_s).click

            @utils.wait_element_by_xpath("//div[@id='oneflow-templates-tab']/div[@class='sunstone-info']")

            xpath_btn_delete = "//span[@id='oneflow-templates-tabdelete_buttons']/button"
            @sunstone_test.get_element_by_xpath(xpath_btn_delete).click

            index = 2
            case type
            when 'all'
                index = 0
            when 'templates'
                index = 1
            end
            button = "//div[@id='genericConfirmDialog']//button[@submit='#{index.to_s}']"
            @sunstone_test.get_element_by_xpath(button).click
        end

        def refresh_table()
          xpath_btn_refresh = "//span[@id='oneflow-templates-tabrefresh_buttons']/button"
          @sunstone_test.get_element_by_xpath(xpath_btn_refresh).click
          sleep 5
        end

        def instantiate_template(template_name, service)
            self.navigate_template_dt
            refresh_table()
            self.select_by_column(template_name.to_s, 4, @templates_datatable, "Service template with name: #{template_name.to_s}, not exists")
            sleep 1
            self.navigate_instantiate
            sleep 1
            self.fill_instantiate_service_form(service)
            sleep 1
            ## Submit service
            xpath_btn_submit = "//span[@id='oneflow-templates-tabsubmit_button']/button"
            @sunstone_test.get_element_by_xpath(xpath_btn_submit).click
        end

        def clone_template(name, newName, mode)
            self.navigate_template_dt
            self.select_by_column(name.to_s, 4, @templates_datatable, "Service template with name: #{name.to_s}, not exists")

            sleep 1
            ## Click clone button
            xpath_btn_clone_dg = "//button[@href='ServiceTemplate.clone_dialog']"
            @sunstone_test.get_element_by_xpath(xpath_btn_clone_dg).click

            sleep 1
            ## Fill dialog
            self.fill_clone_dialog(newName, mode)

            sleep 1
            ## Clone template button
            xpath_btn_clone_action = "//form//button[@id='template_clone_button']"
            @sunstone_test.get_element_by_xpath(xpath_btn_clone_action).click
        end

        def get_nics_in_role_dt(service_name, role_name, vm_id)
            self.navigate_service_dt
            self.select_by_column(service_name.to_s, 4, @services_datatable, "Service with name: #{service_name.to_s}, not exists")

            # waiting service detail view
            @utils.wait_element_by_id('service_roles_tab-label')

            xpath_roles_tab = "//*[@id='service_roles_tab-label']"
            @sunstone_test.get_element_by_xpath(xpath_roles_tab).click
            self.select_by_column(role_name.to_s, 1, @roles_datatable, "Role with name: #{role_name.to_s}, not exists")

            xpath_vms_dt = "//*[@id='datatable_vms_service_roles_tab_#{role_name}']"
            xpath_ul_to_hover = "#{xpath_vms_dt}//ul[@class='dropdown-menu-css']"
            xpath_ips_dropdown = "#{xpath_ul_to_hover}//li[contains(@class,'menu-hide')]"
            
            wait_loop(:timeout => 1000, :success => true) {
                condition = true
                begin
                    @utils.wait_element_by_xpath(xpath_ul_to_hover)
                    column = @sunstone_test.get_element_by_xpath(xpath_ul_to_hover)
        
                    @utils.hover_element(column)

                    @utils.wait_element_by_xpath(xpath_ips_dropdown)
                rescue
                    condition = false
                end
                condition
            }

            return @sunstone_test.get_element_by_xpath(xpath_ips_dropdown).text
        end

        def check_charters_dialog(service_name)
          self.navigate_service_dt
          self.select_by_column(service_name.to_s, 4, @services_datatable, "Service with name: #{service_name.to_s}, not exists")

          # waiting service detail view
          @utils.wait_element_by_id('service_sched_action_tab-label')

          xpath_actions_tab = "//*[@id='service_sched_action_tab-label']"
          @sunstone_test.get_element_by_xpath(xpath_actions_tab).click

          xpath_charters_table = "//div[@id='service_sched_action_tab']/table/tbody/tr[2]/td"
          table = @sunstone_test.get_element_by_xpath(xpath_charters_table)
          if table.attribute("innerHTML") == ""
            fail "there is no charter in the service"
          end
        end

        def if_empty_datatable()
          table = @sunstone_test.get_element_by_id("dataTableService")
          begin
            table.find_element(:class,"dataTables_empty")
          rescue
          end
        end

        def remove_roles(name, delete_roles)
            fail "delete_roles must be an array" if !delete_roles.kind_of?(Array)

            self.navigate_template_dt
            self.refresh_template_dt_until_row(name.to_s).click

            sleep 1
            ## Click update button
            xpath_btn_update_dg = "//button[@href='ServiceTemplate.update_dialog']"
            @sunstone_test.get_element_by_xpath(xpath_btn_update_dg).click

            delete_roles.each do |role_to_delete|
                xpath_delete_role = "//span[@id='role_name_text'][contains(text(),#{role_to_delete})]/../../i"
                @utils.wait_element_by_xpath(xpath_delete_role)
                @sunstone_test.get_element_by_xpath(xpath_delete_role).click
            end

            ##save template
            xpath_btn_update_submit = "//span[@id='oneflow-templates-tabsubmit_button']/button"
            @sunstone_test.get_element_by_xpath(xpath_btn_update_submit).click
        end

        def get_vnc_button(service_name, role_name)
            self.navigate_service_dt
            self.select_by_column(service_name.to_s, 4, @services_datatable, "Service with name: #{service_name.to_s}, not exists")

            # waiting service detail view
            @utils.wait_element_by_id('service_roles_tab-label')

            xpath_roles_tab = "//*[@id='service_roles_tab-label']"
            @sunstone_test.get_element_by_xpath(xpath_roles_tab).click
            self.select_by_column(role_name.to_s, 1, @roles_datatable, "Role with name: #{role_name.to_s}, not exists")

            # waiting vms datatable loaded
            xpath_vnc_btn = "(//*[@id='datatable_vms_service_roles_tab_#{role_name}']//button[contains(@class, 'vnc')])[1]"
            @utils.wait_cond({ :debug => "vms role datatable" }, 90) {
                vm_row = $driver.find_elements(:xpath, xpath_vnc_btn)
                break if vm_row.size > 0
            }

            # select vnc button
            vnc_button = @sunstone_test.get_element_by_xpath(xpath_vnc_btn)
        end

        #
        # Refresh the Service Templates datatable 3 times (by default) or until it 
        # find the template provided
        #
        # @param [String] Name of Service template to find on the table
        # @param [Int] Number of tries to look
        #
        # @returns Service template row
        #
        def refresh_template_dt_until_row(template_name, tries=5)
            self.navigate_template_dt

            @utils.wait_element_by_id(@templates_datatable)
            row = nil
            begin
                row = @utils.check_exists(4, template_name, @templates_datatable)
                if !row
                    xpath_refresh_btn = "//*[@href='ServiceTemplate.refresh']"
                    @sunstone_test.get_element_by_xpath(xpath_refresh_btn).click

                    sleep 0.5
                    
                    row = refresh_template_dt_until_row(template_name, tries-1) unless tries > 0
                end
            rescue Selenium::WebDriver::Error::StaleElementReferenceError
                fail "Can't find template '#{template_name}' in services template datatable" if (tries == 0)
                
                row = refresh_template_dt_until_row(template_name, tries-1)
            end

            row
        end

    end
end
