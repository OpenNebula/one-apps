require 'sunstone/Utils'

class Sunstone
    class Template
        def initialize(sunstone_test)
            @general_tag = "templates"
            @resource_tag = "templates"
            @datatable = "dataTableTemplates"
            @datatable_disks = "disk_type"
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
            @disk_cont = 1
            @nic_cont = 1
        end

        def refresh_images
            @utils.navigate("storage", "images")
            @sunstone_test.get_element_by_id("images-tabrefresh_buttons").click
        end

        def navigate_to_vmtemplate_tab_form(name)
            xpath_tab = "
                //*[contains(@id, 'VMTemplateFormTabs')]
                //*[contains(@class, 'tabs-title')]
                //*[starts-with(@id, '#{name}Tabone')]"

            # wait until form tab is loaded
            @utils.wait_cond({ :debug => "#{name} tab on template form" }, 10) {
                element = $driver.find_elements(:xpath, xpath_tab)
                break if element.size > 0 && element[0].displayed?
            }

            tab = @sunstone_test.get_element_by_xpath(xpath_tab)

            tab ? tab.click : fail("Tab form: #{name} not exists")
        end

        def navigate_wizard()
            element = @sunstone_test.get_element_by_id("#{@resource_tag}-tab-wizardForms-label")
            element.click if element.displayed?
        end

        def navigate_create(name)
            @utils.navigate(@general_tag, @resource_tag)
            table = @sunstone_test.get_element_by_id(@datatable)
            if !@utils.find_in_datatable_paginated(2, name, table)
                @utils.navigate_create(@general_tag, @resource_tag)
                self.navigate_wizard()
                return true
            end
            return false
        end

        def navigate_instantiate(name)
            @utils.navigate(@general_tag, @resource_tag)
            table = @sunstone_test.get_element_by_id(@datatable)
            row = @utils.find_in_datatable_paginated(2, name, table)
            if row
                row.click()
                sleep 2
                element = $driver.find_element(:xpath, "//button[@href='Template.instantiate_vms']")
                if element.displayed?
                    element.click
                    sleep 2
                    return true
                end
            end
            return false
        end

        def uncheck_options()
          @utils.navigate(@general_tag, @resource_tag)
          table = @sunstone_test.get_element_by_id(@datatable)
          if table
            trs = table.find_elements(tag_name: "tr")
            trs.each do |tr|
              tds = tr.find_elements(tag_name: "td")
              begin
                tds.each do |td|
                  checks = td.find_elements(:class, "check_item")
                  checks.each do |check|
                    if check.attribute("checked")
                      check.click
                    end
                  end
                end
              rescue StandardError => e
              end
            end
          else
            fail "table not exists"
          end
        end

        def navigate_update(name)
            @utils.navigate(@general_tag, @resource_tag)
            table = @sunstone_test.get_element_by_id(@datatable)
            template = @utils.find_in_datatable_paginated(2, name, table)
            if template
                td = template.find_elements(tag_name: "td")[0]
                td.find_element(:class, "check_item").click

                @sunstone_test.get_element_by_xpath("
                    //*[@id='templates-tabmain_buttons']
                    //button[contains(@href, 'update_dialog')]").click
            else
                fail "Template name: #{name} not exists"
            end
        end

        def create_advanced(template)
            @utils.create_advanced(template, @general_tag, @resource_tag, "VMTemplate")
        end

        def submit()
            @utils.submit_create(@resource_tag)
        end

        def add_general(json)
            @utils.fill_input_by_finder(:id, "NAME", json[:name])               if json[:name]
            @utils.fill_input_by_finder(:id, "MEMORY_GB", json[:mem])           if json[:mem]
            @utils.fill_input_by_finder(:id, "CPU", json[:cpu])                 if json[:cpu]
            @utils.fill_input_by_finder(:id, "MEMORY_COST", json[:memory_cost]) if json[:memory_cost]
            @utils.fill_input_by_finder(:id, "CPU_COST", json[:cpu_cost])       if json[:cpu_cost]
            @utils.fill_input_by_finder(:id, "DISK_COST", json[:disk_cost])     if json[:disk_cost]
            @utils.fill_input_by_finder(:id, "NAME", json[:name])               if json[:name]

            if json[:hypervisor]
                if json[:hypervisor] == "kvm"
                    @sunstone_test.get_element_by_id("kvmRadio").click
                elsif json[:hypervisor] == "vcenter"
                    @sunstone_test.get_element_by_id("vcenterRadio").click
                else
                    @sunstone_test.get_element_by_id("lxcRadio").click
                end
            end

            if json[:memory_max]
                dropdown = @sunstone_test.get_element_by_id("MEMORY_HOT_ADD_ENABLED")
                @sunstone_test.click_option(dropdown, "value", "YES")

                @utils.fill_input_by_finder(:id, "MEMORY_MAX_GB", json[:memory_max])
            else
                dropdown = @sunstone_test.get_element_by_id("MEMORY_HOT_ADD_ENABLED")
                @sunstone_test.click_option(dropdown, "value", "NO")
            end

            if json[:vcpu_max]
                dropdown = @sunstone_test.get_element_by_id("CPU_HOT_ADD_ENABLED")
                @sunstone_test.click_option(dropdown, "value", "YES")

                @utils.fill_input_by_finder(:id, "VCPU_MAX", json[:vcpu_max])
            else
                dropdown = @sunstone_test.get_element_by_id("CPU_HOT_ADD_ENABLED")
                @sunstone_test.click_option(dropdown, "value", "NO")
            end
        end

        def change_storage(name_template)
            navigate_to_vmtemplate_tab_form('storage')

            table = @sunstone_test.get_element_by_css("##{@datatable_disks} .dataTable")
            disk = @utils.check_exists_datatable(1, name_template, table, 10){
                @sunstone_test.get_element_by_id("refresh_button_#{table.attribute('id')}").click
            }
            if disk
                disk.click
                buttons = @sunstone_test.get_element_by_id("templates-tabform_buttons")
                buttons.find_element(:css, "#templates-tabsubmit_button>button").click
            else
                fail "disk name: #{name_template} not exists"
            end
        end

        def add_os(json, update=false)
            if !update
                @disk_cont = 1
            end

            navigate_to_vmtemplate_tab_form('os')

            i = @disk_cont
            if json[:disk]
                json[:disk].each { |disk|
                    xpath_disk_cb = "//*[contains(@class, 'boot-order')]//*[@value='#{disk}']//input"
                    @sunstone_test.get_element_by_xpath(xpath_disk_cb).click
                    i+=1
                }
            end

            if json[:features]
                xpath = "//a[starts-with(@href, '#features')]"
                @sunstone_test.get_element_by_xpath(xpath).click

                xpath = "//input[@wizard_field='IOTHREADS']"
                @utils.fill_input_by_finder(:xpath, xpath, json[:features][:iothreads])
            end
        end

        def add_storage(json, update=false)
            if !update
                @disk_cont = 1
            end

            navigate_to_vmtemplate_tab_form('storage')

            i = @disk_cont
            if json[:image]
                json[:image].each { |name|
                    cb_image = @sunstone_test.get_element_by_xpath("//div[@diskid='#{i}']//Input[@value='image']")
                    cb_image.click

                    table = @sunstone_test.get_element_by_xpath("//div[@diskid='#{i}']//table")
                    tr_table = table.find_elements(tag_name: "tr")
                    tr_table.each { |tr|
                        td = tr.find_elements(tag_name: "td")
                        if td.length > 0
                            tr.click if name.include? td[1].text
                        end
                    }

                    @sunstone_test.get_element_by_id("tf_btn_disks").click
                    i+=1
                }
            end

            if json[:deploy]
              dropdown = @sunstone_test.get_element_by_id("TM_MAD_SYSTEM")
              @sunstone_test.click_option(dropdown, "value", json[:deploy])
            end

            if json[:volatile]
                json[:volatile].each { |disk|
                    cb_volatile = @sunstone_test.get_element_by_xpath("//div[@diskid='#{i}']//Input[@value='volatile']")
                    cb_volatile.click

                    @utils.fill_input_by_finder(:xpath, "//div[@diskid='#{i}']//div[@class='volatile']//Input[@id='SIZE']", disk[:size])

                    if disk[:size_unit]
                        dropdown = @sunstone_test.get_element_by_xpath("//div[@diskid='#{i}']//div[@class='volatile']//select[@class='mb_input_unit']")
                        @sunstone_test.click_option(dropdown, "value", disk[:size_unit])
                    end
                    if disk[:type]
                        dropdown = @sunstone_test.get_element_by_xpath("//div[@diskid='#{i}']//div[@class='volatile']//select[@id='TYPE_KVM']")
                        @sunstone_test.click_option(dropdown, "value", disk[:type])
                    end
                    if disk[:format]
                        dropdown = @sunstone_test.get_element_by_xpath("//div[@diskid='#{i}']//div[@class='volatile']//select[@id='FORMAT_KVM']")
                        @sunstone_test.click_option(dropdown, "value", disk[:format])
                    end

                    if disk[:advanced]
                        xpath = "//div[@diskid='#{i}']/div[@class='volatile']/div[@class='accordion_advanced']/a"
                        @sunstone_test.get_element_by_xpath(xpath).click

                        xpath = "//div[@diskid='#{i}']/div[@class='volatile']//input[@id='IOTHREAD']"
                        @utils.fill_input_by_finder(:xpath, xpath, disk[:advanced][:iothread])
                    end

                    @sunstone_test.get_element_by_id("tf_btn_disks").click
                    i+=1
                }
            end
        end

        def add_network(json, update=false)
            if !update
                @nic_cont = 1
            end

            navigate_to_vmtemplate_tab_form('network')

            i = @nic_cont
            if json[:vnet]
                json[:vnet].each { |vnet|
                    if vnet.is_a? String
                        name = vnet
                    else
                        name = vnet[:name]
                    end

                    div = $driver.find_element(:xpath, "//div[@nicid='#{i}']")
                    # table[0] vnets auto
                    # table[1] vnets
                    table = div.find_elements(tag_name: "table")[1]
                    tr_table = table.find_elements(tag_name: "tr")
                    tr_table.each { |tr|
                        td = tr.find_elements(tag_name: "td")
                        if td.length > 0
                            tr.click if name.include? td[1].text
                        end
                    }

                    if (!vnet.is_a? String)
                        if vnet[:alias]
                            interface_type = div.find_elements(:xpath, "//label[contains(@for, '_interface_type')]")[i - 1]
                            interface_type.click

                            alias_parent = div.find_elements(:xpath, "//select[contains(@id, 'alias_parent')]")[i - 1]
                            alias_parent.click
                            alias_parent.click

                            @sunstone_test.click_option(alias_parent, "value", vnet[:alias]) if vnet[:alias] != "NIC0"
                        end

                        if vnet[:advanced]
                            advanced_options = div.find_elements(:xpath, "//div[contains(@id, 'nic_values')]")[i - 1]
                            advanced_options.click

                            vnet[:advanced].each do |element, value|
                                if value.is_a? String
                                    input = div.find_elements(:xpath, "//input[contains(@id, '#{element.upcase}')]")[i - 1]
                                    input.send_keys(value)
                                end
                            end
                        end
                    end
                    @sunstone_test.get_element_by_id("tf_btn_nics").click
                    i+=1
                }
            end

            if json[:filter]
                @utils.fill_input_by_finder(:id, "DEFAULT_FILTER", json[:filter])
            end

            @nic_cont = i
        end

        def add_user_inputs(inputs)
            navigate_to_vmtemplate_tab_form('context')

            if inputs
                inputs.each_with_index { |input, index|
                    $driver.find_element(:class, "add_user_input_attr").click

                    table = $driver.find_element(:class, "user_input_attrs")
                    tr_table = table.find_elements(tag_name: "tr")
                    input_tr = tr_table[tr_table.length - 2]

                    # NAME
                    input_tr.find_element(:class, "user_input_name").send_keys input[:name]

                    # TYPE
                    dropdown = input_tr.find_element(:class, "user_input_type")
                    @sunstone_test.click_option(dropdown, "value", input[:type])

                    # DESCRIPTION
                    input_tr.find_element(:class, "user_input_description").send_keys input[:desc]

                    # MANDATORY
                    if input[:mand] && input[:mand] == "false"
                        input_tr.find_element(:class, "switch-paddle").click
                    end

                    # DEFAULT VALUE
                    default = input[:default]
                    xpath_user_inputs = "//table[contains(@class, 'user_input_attrs')]/tbody/tr[#{index + 1}]"

                    xpath_input =
                        "#{xpath_user_inputs}//*[@class='user_input_type_right #{input[:type]}' or contains(@class, '#{input[:type]}')]"

                    xpath_min = "#{xpath_input}//*[@class='user_input_params_min']"
                    xpath_max = "#{xpath_input}//*[@class='user_input_params_max']"
                    xpath_options = "#{xpath_input}//*[@class='user_input_params']"
                    xpath_value = "#{xpath_input}//*[@class='user_input_initial']"

                    if default
                        if default[:min]
                            @utils.fill_input_by_finder(:xpath, xpath_min, default[:min].to_s)
                        end
                        if default[:max]
                            @utils.fill_input_by_finder(:xpath, xpath_max, default[:max].to_s)
                        end
                        if default[:options]
                            @utils.fill_input_by_finder(:xpath, xpath_options, default[:options].to_s)
                        end


                        if input[:type] == "boolean"
                            input_tr.find_element(:id, "radio_yes").click if default[:value] == "YES"
                        else
                            @utils.fill_input_by_finder(:xpath, xpath_value, default[:value].to_s) if default[:value]
                        end
                    end
                }
            end
        end

        def fill_user_inputs(inputs, xpath_form = nil)
            inputs.each { |input|
                name = input[:name].upcase
                post = input[:post]
                type = input[:type]

                xpath_form_instantiate = xpath_form || "//*[@id='instantiateTemplateDialogWizard']"
                xpath_field = "#{xpath_form_instantiate}//*[@wizard_field = '#{name}']"
                field = $driver.find_element(:xpath, xpath_field)

                if post[:value]
                    value = post[:value]

                    if field.displayed?
                        if type == "boolean"
                            $driver.find_element(:xpath, xpath_field.concat("[@value='#{value}']")).click
                        else
                            field.clear
                            field.send_keys value
                        end
                    else
                        $driver.execute_script("$('input[wizard_field=#{name}]').val('#{value}')");
                    end
                elsif post[:select]
                    select_field = Selenium::WebDriver::Support::Select.new(field)
                    select_field.deselect_all if select_field.multiple?
                    post[:select].split(',').each { |value|
                        select_field.select_by(:value, value)
                    }
                end
            }
        end

        def add_sched(json)
            navigate_to_vmtemplate_tab_form('actions')

            if json[:actions]
                json[:actions].each { |action|
                    @sunstone_test.get_element_by_id("add_sched_temp_action").click

                    dropdown = @sunstone_test.get_element_by_id("select_new_action")
                    @sunstone_test.click_option(dropdown, "value", action[:action])

                    if action[:relative]
                      add_relative_sched_action(action, dropdown)
                    else
                      add_punctual_sched_action(action)
                    end

                    @sunstone_test.get_element_by_id("add_temp_action_json").click
                    sleep 2
                }
            end
        end

        # Scheduled actions Functions

        def add_relative_sched_action(action, dropdown)
            @sunstone_test.get_element_by_id("relative_time").click
            @utils.fill_input_by_finder(:id, "time_number", action[:date])
            time_unit = @sunstone_test.get_element_by_id("time_unit")
            @sunstone_test.click_option(dropdown, "value", action[:time])
        end

        def add_punctual_sched_action(action)
            # Set schedule action date
            if action[:date]
                @sunstone_test.get_element_by_id("date_input").click
                date = action[:date]
                if date[:day] && date[:month] && date[:year]
                    begin
                    findByClass = @sunstone_test.get_element_by_class("ui-datepicker-title").text
                    findBytext = findByClass === "#{date[:month]} #{date[:year]}"
                    if findBytext
                        days = $driver.find_elements(:class, "ui-state-default");
                        days.each do |day|
                        if day.text === "#{date[:day]}"
                            day.click
                        end
                        end
                    else
                        @sunstone_test.get_element_by_class("ui-datepicker-next").click
                    end
                    end while not findBytext
                end
            end

            # Set schedule action time
            if action[:time]
                @sunstone_test.get_element_by_id("time_input").click
                set_sched_action_hour(action[:time].split(":")[1])
                set_sched_action_minutes(action[:time].split(":")[1])
            end

            if action[:periodic]
                @sunstone_test.get_element_by_id("schedule_type").click
                dropdown = @sunstone_test.get_element_by_id("repeat")
                @sunstone_test.click_option(dropdown, "value", action[:repeat])
                if action[:days_week]
                    action[:days_week].each { |day|
                        @sunstone_test.get_element_by_id("#{day}").click
                    }
                end
                if action[:days_month]
                    @utils.fill_input_by_finder(:id, "days_month_value", action[:days_month])
                end

                if action[:periodic_date]
                    date = action[:periodic_date]
                    @sunstone_test.get_element_by_id("end_type_date").click
                    if date[:day] && date[:month] && date[:year]
                        @sunstone_test.get_element_by_id("end_value_date").click
                        begin
                            findByClass = @sunstone_test.get_element_by_class("ui-datepicker-title").text
                            findBytext = findByClass === "#{date[:month]} #{date[:year]}"
                            if findBytext
                                days = $driver.find_elements(:class, "ui-state-default");
                                days.each do |day|
                                    if day.text === "#{date[:day]}"
                                        day.click
                                    end
                                end
                            else
                                @sunstone_test.get_element_by_class("ui-datepicker-next").click
                            end
                        end while not findBytext
                    end
                end

                if action[:after_time]
                    options = $driver.find_elements(:id, "end_type_n_rep");
                    options.each do |option|
                        if option.attribute("value") === "n_rep"
                            option.click
                            @utils.fill_input_by_finder(:id, "end_value_n_rep", action[:after_time][:day])
                        end
                    end
                end
            end
        end

        def set_sched_action_hour(hour)
            while @sunstone_test.get_element_by_css(".wickedpicker__controls__control:nth-of-type(1) > .wickedpicker__controls__control--hours").text != hour
                @sunstone_test.get_element_by_css(".wickedpicker__controls__control:nth-of-type(1) > .wickedpicker__controls__control-up").click
            end
        end

        def set_sched_action_minutes(minutes)
            while @sunstone_test.get_element_by_css(".wickedpicker__controls__control:nth-of-type(3) > .wickedpicker__controls__control--minutes").text != minutes
                @sunstone_test.get_element_by_css(".wickedpicker__controls__control:nth-of-type(3) > .wickedpicker__controls__control-up").click
            end
        end

        # Fin funciones schedule actions

        def add_numa(topology)
            navigate_to_vmtemplate_tab_form('numa')

            @sunstone_test.get_element_by_id("numa-topology").click

            @utils.fill_input_by_finder(:id, "numa-cores", topology[:cores])     if topology[:cores]
            @utils.fill_input_by_finder(:id, "numa-sockets", topology[:sockets]) if topology[:sockets]
            @utils.fill_input_by_finder(:id, "numa-threads", topology[:threads]) if topology[:threads]

            if topology[:memory_access]
                mem_select = @sunstone_test.get_element_by_id("numa-memory")
                option = Selenium::WebDriver::Support::Select.new(mem_select)
                option.select_by(:value, topology[:memory_access])
            end

            if topology[:pin_policy]
                policy_select = @sunstone_test.get_element_by_id("numa-pin-policy")
                option = Selenium::WebDriver::Support::Select.new(policy_select)
                option.select_by(:value, topology[:pin_policy])
            end

            if topology[:hugepage_size]
                hugepages_select = @sunstone_test.get_element_by_id("numa-hugepages")
                option = Selenium::WebDriver::Support::Select.new(hugepages_select)
                option.select_by(:value, topology[:hugepage_size])
            end
        end

        def delete(name)
            @utils.wait_jGrowl
            @utils.navigate(@general_tag, @resource_tag)
            table = @sunstone_test.get_element_by_id(@datatable)
            row = @utils.find_in_datatable_paginated(2, name, table)
            if row
                td = row.find_elements(tag_name: "td")[0]
                td_input = td.find_element(:class, "check_item")
                check = td.attribute("class")
                td_input.click if check.nil? || check == ""
                @sunstone_test.get_element_by_id("#{@resource_tag}-tabdelete_buttons").click
                $driver.find_element(:xpath, "//div[@id='genericConfirmDialog']//button[@submit='0']").click
            else
                fail "Error delete: Template not found"
            end
            sleep 2
        end

        def update_general(json)
            if json[:mem]
                @utils.fill_input_by_finder(:id, "MEMORY_GB", json[:mem])
            end
            if json[:cpu]
                @utils.fill_input_by_finder(:id, "CPU", json[:cpu])
            end
        end

        def update_storage(json)
            self.delete_storage
            self.add_storage(json, true)
        end

        def delete_storage
            @disk_cont = 1

            navigate_to_vmtemplate_tab_form('storage')

            ul = @sunstone_test.get_element_by_id("template_create_storage_tabs")
            li = ul.find_elements(:class, "tabs-title")
            li.each{ |element|
                element.find_element(:class, "remove-tab").click
                @disk_cont+=1
            }
            @sunstone_test.get_element_by_id("tf_btn_disks").click
        end

        def update_network(json)
            self.delete_network
            self.add_network(json, true)
        end

        def delete_network
            @nic_cont = 1

            navigate_to_vmtemplate_tab_form('network')

            ul = @sunstone_test.get_element_by_id("template_create_network_tabs")
            li = ul.find_elements(:class, "tabs-title")
            li.each{ |element|
                element.find_element(:class, "remove-tab").click
            }
            @sunstone_test.get_element_by_id("tf_btn_nics").click
        end

        def update_user_inputs(inputs)
            self.delete_user_inputs
            self.add_user_inputs(inputs)
        end

        def delete_user_inputs
            navigate_to_vmtemplate_tab_form('context')
            table = $driver.find_element(:class, "user_input_attrs")
            tbody = table.find_element(:tag_name, "tbody")
            trs = tbody.find_elements(:tag_name, "tr")
            trs.each{ |tr|
                tds = tr.find_elements(:tag_name, "td")
                tds[tds.length - 1].find_element(:tag_name, "i").click
            }
        end

        def update_context(json)
            navigate_to_vmtemplate_tab_form('context')

            xpath_template_form = "//*[@id='templates-tab-wizardForms']"

            if json[:configuration]
                xpath_config_tab = "#{xpath_template_form}//a[starts-with(@id, 'netsshTabone')]"
                @sunstone_test.get_element_by_xpath(xpath_config_tab).click

                start_script = json[:configuration][:start_script]

                xpath_start_script = "#{xpath_template_form}//textarea[contains(@class, 'START_SCRIPT')]"
                @utils.fill_input_by_finder(:xpath, xpath_start_script, start_script) if start_script
            end

            if json[:files]
                # TODO if necessary
                xpath_files_tab = "#{xpath_template_form}//a[starts-with(@id, 'filesTabone')]"
                @sunstone_test.get_element_by_xpath(xpath_files_tab).click
            end

            if json[:custom_vars]
                xpath_custom_vars_tab = "#{xpath_template_form}//a[starts-with(@id, 'customTabone')]"
                @sunstone_test.get_element_by_xpath(xpath_custom_vars_tab).click

                xpath_tab_content = "#{xpath_template_form}//div[starts-with(@id, 'customTabone')]"

                # delete all current vars
                xpath_remove_btn = "#{xpath_tab_content}//*[contains(@class, 'remove-tab')]"
                $driver.find_elements(:xpath, xpath_remove_btn).each(&:click)

                xpath_add_btn = "#{xpath_tab_content}//*[contains(@class, 'add_custom_tag')]"

                json[:custom_vars].each_with_index do |(name, value), index|
                    # click to add button
                    @sunstone_test.get_element_by_xpath(xpath_add_btn).click

                    xpath_name_input = "(#{xpath_tab_content}//input[@name='key'])[#{index + 1}]"
                    @utils.fill_input_by_finder(:xpath, xpath_name_input, name.to_s)

                    xpath_value_input = "(#{xpath_tab_content}//textarea[@name='value'])[#{index + 1}]"
                    @utils.fill_input_by_finder(:xpath, xpath_value_input, value.to_s)
                end
            end
        end

        def update_scheduling(json)
            navigate_to_vmtemplate_tab_form('scheduling')

            if json[:expression]
                @utils.fill_input_by_finder(:id, "SCHED_REQUIREMENTS", json[:expression])
            end
        end

        def change_opennebula_manage(image_opennebula_manage,image_opennebula_manage_change)
            refresh_images()
            @utils.navigate(@general_tag, @resource_tag)
            navigate_update(image_opennebula_manage)
            change_storage(image_opennebula_manage_change)
        end
    end
end
