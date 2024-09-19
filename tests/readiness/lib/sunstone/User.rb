require 'sunstone/Utils'

class Sunstone
    class User
        def initialize(sunstone_test)
            @general_tag = "system"
            @resource_tag = "users"
            @datatable = "dataTableUsers"
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
            @wait = Selenium::WebDriver::Wait.new(:timeout => 10)
        end

        def create_user(name_passwd, hash)
            begin
                hash = { :secondary => [] }.merge!(hash) # secondary isn't required

                @utils.navigate(@general_tag, @resource_tag)

                if !@utils.check_exists(2, name_passwd, @datatable)
                    @utils.navigate_create(@general_tag, @resource_tag)

                    @utils.fill_input_by_finder(:id, 'createUserForm_username', name_passwd)
                    @utils.fill_input_by_finder(:id, 'createUserForm_pass', name_passwd)
                    @utils.fill_input_by_finder(:id, 'createUserForm_confirm_password', name_passwd)

                    xpath_form = "//*[@id='createUserFormWizard']"

                    # Select main group
                    xpath_main_group_dd = "#{xpath_form}//*[contains(@class, 'main_group_div')]/select"
                    main_group_dropdown = @sunstone_test.get_element_by_xpath(xpath_main_group_dd)

                    main_group_dd_object = Selenium::WebDriver::Support::Select.new(main_group_dropdown)

                    main_group_dd_object.options.each { |option|
                        next unless option.text.include? hash[:primary]

                        main_group_dd_object.select_by(:text, option.text)
                    }

                    # Select secondary groups
                    hash[:secondary].each do |secondary_group_name|
                        xpath_secondary_group = "//table[contains(@id, 'user-creation-one')]
                                                //tr[contains(., '#{secondary_group_name}')]"

                        secondary_group_row = @sunstone_test.get_element_by_xpath(xpath_secondary_group)

                        secondary_group_row.click
                    end

                    @utils.submit_create(@resource_tag)
                end
            rescue StandardError => e
                @utils.save_temp_screenshot('create-user' , e)
            end
        end

        # Hash parameter can have this attributes:
        #  - :info, :attr, :groups, :quotas, :auth
        def check(name, hash = {})
            @utils.navigate(@general_tag, @resource_tag)
            user = @utils.check_exists(2, name, @datatable)

            if user
                user.click
                sleep 1

                hash.each do |key, value|
                    self.method("check_#{key}").call(value)
                end
            end
        end

        def update(name, hash = {})
            @utils.navigate(@general_tag, @resource_tag)
            user = @utils.check_exists(2, name, @datatable)
            if user
                @utils.wait_jGrowl
                user.click
                @sunstone_test.get_element_by_id("user_info_tab")
                if hash[:info] && !hash[:info].empty?
                    @utils.update_info("//div[@id='user_info_tab']//table[@class='dataTable']", hash[:info])
                end
                if hash[:attr] && !hash[:attr].empty?
                    @utils.update_attr("user_template_table", hash[:attr])
                end
                if hash[:groups]
                    update_groups hash[:groups]
                end
                if hash[:quotas]
                    sleep 4
                    @sunstone_test.get_element_by_id("user_quotas_tab-label").click
                    @sunstone_test.get_element_by_id("edit_quotas_button").click
                    hash[:quotas].each do |key, value|
                        self.method("update_#{key}_quotas").call(value)
                    end
                    @sunstone_test.get_element_by_id("submit_quotas_button").click
                end
            end
        end

        def delete(name)
            @utils.delete_resource(name, @general_tag, @resource_tag, @datatable)
        end

        def disable(name)
            @utils.navigate(@general_tag, @resource_tag)
            user = @utils.check_exists(2, name, @datatable)

            if user
                user.click
            end

            xpath = "//button[@href='User.disable']"

            message_error =  "Can't open user view"
            @utils.wait_cond({ :debug => message_error }, 10){
                @sunstone_test.get_element_by_xpath(xpath).displayed?
            }

            @sunstone_test.get_element_by_xpath(xpath).click
        end

        def enable(name)
            @utils.navigate(@general_tag, @resource_tag)
            user = @utils.check_exists(2, name, @datatable)

            if user
                user.click
            end

            xpath = "//button[@href='User.enable']"

            message_error =  "Can't open user view"
            @utils.wait_cond({ :debug => message_error }, 10){
                @sunstone_test.get_element_by_xpath(xpath).displayed?
            }

            @sunstone_test.get_element_by_xpath(xpath).click
        end

        private

        def check_info(info)
            tr_table = $driver.find_elements(:xpath, "//div[@id='user_info_tab']//table[@class='dataTable']//tr")
            info = @utils.check_elements(tr_table, info)

            if !info.empty?
                info.each{ |obj| puts "#{obj[:key]} : #{obj[:value]}" }
                fail "Check fail info: Not Found all keys"
            end
        end

        def check_attr(attrs)
            tr_table = $driver.find_elements(:xpath, "//div[@id='user_info_tab']//table[@id='user_template_table']//tr")
            attrs = @utils.check_elements(tr_table, attrs)

            if !attrs.empty?
                attrs.each{ |obj| puts "#{obj[:key]} : #{obj[:value]}" }
                fail "Check fail attributes: Not Found all keys"
            end
        end

        def check_groups(groups)
            @sunstone_test.get_element_by_id("user_groups_tab-label").click
            @sunstone_test.get_element_by_id("Form_change_second_grp")
            primary_grp = $driver.find_element(:xpath, "//form[@id='Form_change_second_grp']//h6[@class='show_labels']/a").text
            fail "Failed to check primary group" if primary_grp != groups[:primary]

            groups[:secondary].each { |secondary_grp|
                if !@utils.check_exists(1, secondary_grp, "user_groups_tabGroupsTable")
                    fail "Failed to check secondary group #{secondary_grp}"
                end
            }
        end

        def check_quotas(quotas)
            @sunstone_test.get_element_by_id("user_quotas_tab-label").click
            if !$driver.find_element(:xpath, "//div[@id='user_quotas_tab']//p").text.include? "There are no quotas defined"
                quotas.each { |quota|
                    value_quota = $driver.find_element(:xpath, "//div[@quota_name='#{quota[:key]}']//progress").attribute("value")
                    fail "Failed to check quota #{quota[:key]} : #{quota[:value]}" if value_quota != quota[:value]
                }
            else
                fail "Quotas not defined"
            end
        end

        def check_auth(auth)
            @sunstone_test.get_element_by_id("user_auth_tab-label").click
            tr_table = $driver.find_elements(:xpath, "//div[@id='user_auth_tab']//table[@id='dataTable']//tr")
            auth = @utils.check_elements(tr_table, auth)

            if !auth.empty?
                auth.each{ |obj| puts "#{obj[:key]} : #{obj[:value]}" }
                fail "Check fail attributes: Not Found all keys"
            end
        end

        def update_groups(groups)
            @utils.wait_element_by_id('user_groups_tab-label')

            @sunstone_test.get_element_by_id("user_groups_tab-label").click
            @sunstone_test.get_element_by_id("user_groups_tab")
            @sunstone_test.get_element_by_id("update_group").click
            if groups[:primary]
                @sunstone_test.get_element_by_id("choose_primary_grp")
                options = $driver.find_elements(:xpath, "//div[@id='choose_primary_grp']//option")
                options.each{ |opt| opt.click if opt.text.include? groups[:primary] }
            end

            if groups[:secondary]
                groups[:secondary].each { |group|
                    select_grp = @utils.check_exists(1, group, "user_groups_edit")
                    if select_grp
                        check = select_grp.find_elements(tag_name: "td")[0].attribute("class")
                        select_grp.click if check.nil? || check == ""
                    else
                        fail "Group name not found: #{group}"
                    end
                }
            end
            $driver.find_element(:xpath, "//div[@class='form_buttons row']//button[@type='submit']").click
        end

        def update_vm_quotas(quotas)
            # 0: VMs, 1: CPU, 2: Mem, 3: Disks
            containers = $driver.find_elements(:class, "quotabar_container")

            quotas.each do |key, value|
                case key
                when :vms
                    container = containers[0] # VMs
                when :running_vms
                    container = containers[1] # Running VMs
                when :cpu
                    container = containers[2] # CPU
                when :running_cpu
                    container = containers[3] # Running CPU
                when :mem
                    container = containers[4] # Mem
                when :running_mem
                    container = containers[5] # Running Mem
                when :disks
                    container = containers[6] # Disks
                end

                container.find_element(:class, "quotabar_edit_btn").click
                input = container.find_element(:tag_name, "input")
                input.clear
                input.send_keys quotas[key]
            end
        end

        def add_quota (name_table, quotas)
            quotas_div = $driver.find_element(:class, "quotas")
            table = quotas_div.find_element(:class, "#{name_table}_quota_table")
            
            @sunstone_test.get_element_by_id("#{name_table}_add_quota_btn").click
            
            dropdown = nil
            message_error =  "Not found resource_list_select in #{name_table}"
            @utils.wait_cond({ :debug => message_error }, 10){
                dropdown = table.find_element(:class, "resource_list_select")
            }

            @sunstone_test.click_option(dropdown, "value", quotas[:id])

            quotas[:limits].each do |key, value|
                img_div = table.find_element(:class, key)
                img_div.find_element(:class, "quotabar_edit_btn").click
                input = img_div.find_element(:tag_name, "input")
                input.clear
                input.send_keys value
            end
        end

        def update_img_quotas(quotas)
            add_quota("image", quotas)
        end

        def update_vnet_quotas(quotas)
            add_quota("network", quotas)
        end

        def update_ds_quotas(quotas)
            add_quota("ds", quotas)
        end

    end

end
