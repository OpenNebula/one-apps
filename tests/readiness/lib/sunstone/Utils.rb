require 'securerandom'
require 'sunstone_test'

class TableNotFound < StandardError
end

class Sunstone

    class Utils

        def initialize(sunstone_test)
            @sunstone_test = sunstone_test
        end

        def navigate_create(general, resource)
            if !$driver.find_element(:id, "#{resource}-tabcreate_buttons").displayed?
                navigate(general, resource)
            end
            if ( !$driver.find_element(:id, "#{resource}-tabcreate_buttons").displayed? )
                element = $driver.find_element(:xpath, "//button[@data-toggle='#{resource}-tabcreate_buttons_flatten']")
                element.click if element.displayed?
                a = $driver.find_element(:xpath, "//ul[@id='#{resource}-tabcreate_buttons_flatten']//a[contains(@class, 'create_dialog_button')]")
                a.click if a.displayed?
            else
                element = @sunstone_test.get_element_by_id("#{resource}-tabcreate_buttons")
                element.find_element(:class, "create_dialog_button").click if element.displayed?
            end
            sleep 1
        end

        def navigate_import(general, resource)
            if !$driver.find_element(:id, "#{resource}-tabcreate_buttons").displayed?
                navigate(general, resource)
            end
            if ( !$driver.find_element(:id, "#{resource}-tabcreate_buttons").displayed? )
                element = $driver.find_element(:xpath, "//button[@data-toggle='#{resource}-tabcreate_buttons_flatten']")
                element.click if element.displayed?
                a = $driver.find_element(:xpath, "//ul[@id='#{resource}-tabcreate_buttons_flatten']//a[contains(@class, 'create_dialog_button') and contains(@href, 'import')]")
                a.click if a.displayed?
            else
                element = @sunstone_test.get_element_by_id("#{resource}-tabcreate_buttons")
                element.find_elements(:class, "create_dialog_button")[1].click if element.displayed?
            end
            # element = @sunstone_test.get_element_by_id("#{resource}-tabcreate_buttons")
            # element.find_elements(:class, "create_dialog_button")[1].click if element.displayed?
            sleep 1
        end

        def navigate(general, resource)
            sleep 0.2
            if !$driver.find_element(:id, "#{resource}-tabcreate_buttons").displayed?
                @sunstone_test.get_element_by_id("menu-toggle").click if !$driver.find_element(:id, "li_#{general}-top-tab").displayed?
                sleep 0.5
                @sunstone_test.get_element_by_id("li_#{general}-top-tab").click if !$driver.find_element(:id, "li_#{resource}-tab").displayed?
                sleep 1
                @sunstone_test.get_element_by_xpath("//li[@id='li_#{resource}-tab']/a").click
                sleep 1
            end
        end

        def get_sunstone_server_conf()
            begin
                YAML.load(File.read("#{ONE_ETC_LOCATION}/sunstone-server.conf"))
            rescue StandardError => e
            end
        end

        def submit_create(resource)
            element = @sunstone_test.get_element_by_id("#{resource}-tabsubmit_button")
            element.find_element(:class, "submit_button").click if element.displayed?
            sleep 2
            self.wait_jGrowl
        end

        def create_advanced(template, general_tag, resource_tag, form_tag)
            self.navigate(general_tag, resource_tag)
            self.navigate_create(general_tag, resource_tag)
            tab = @sunstone_test.get_element_by_id("#{resource_tag}-tabFormTabs")
            tab.find_element(:id, "advanced_mode").click
            advanced = @sunstone_test.get_element_by_id("create#{form_tag}FormAdvanced")
            textarea = advanced.find_element(:tag_name, "textarea")
            textarea.clear
            textarea.send_keys template

            self.submit_create(resource_tag)
        end

        # num_col: datatable column number (0: id, 1: name...)
        # compare: element to compare
        # datatable: datatable DOM id
        #
        # return: tr with match
        def check_exists(num_col = 2, compare, datatable)
            begin
                table = @sunstone_test.get_element_by_id("#{datatable}")
                raise TableNotFound if !table
            rescue Selenium::WebDriver::Error::TimeoutError, TableNotFound
                begin
                    table = @sunstone_test.get_element_by_xpath("//*[@id='#{datatable}']")
                    raise TableNotFound if !table
                rescue Selenium::WebDriver::Error::TimeoutError, TableNotFound
                    table = $driver.find_element(:id, datatable)
                end
            end
            
            tr_table = table.find_elements(:xpath, "//table[@id='#{datatable}']//tr")

            return unless tr_table

            [tr_table].flatten.each do |tr|
                td = tr.find_elements(:tag_name => 'td')

                next if !td || !td[0] || td[0].text == 'There is no data available' || !td[num_col]

                return tr if compare == td[num_col].text
            end

            false
        end

        # num_col: datatable column number (0: id, 1: name...)
        # compare: element to compare
        # datatable: datatable DOM id
        #
        # return: tr with match
        def check_exists_vcenter(compare, datatable, num_col=1)
            trs = datatable.find_elements(tag_name: "tr")
            trs = trs[1..trs.size]
            trs.each { |tr|
                tds = tr.find_elements(tag_name: "td")
                if tds[num_col].find_element(tag_name: "label").text == compare
                    return tr
                    break
                end
            }
            return false
        end

        def wait_cond(opts = {}, timeout = 60, &block)
            cond = nil
            (0..timeout).each{ |current_time|
                sleep 1
                raise 'mandatory block!' unless block_given?
                value = block.call(current_time)
                cond = !(value == nil || value == false)
                break if cond
            }

            if !cond
                message = 'sunstone timeout!:'
                message << " waiting for #{opts[:debug]}" if opts[:debug]

                self.save_temp_screenshot(opts[:name_screenshot]) if opts[:name_screenshot]
                raise message
            end
        end

        # num_col: datatable column number (0: id, 1: name...)
        # compare: element to compare
        # datatable: Selenium Object
        # next_indicator: Selenium Object next datatable indicator css selector
        #
        # return: tr with match
        def find_in_datatable(num_col = 2, compare = "", datatable = "", next_indicator = '.next')
          begin
            retries ||= 0
            trs = datatable.find_elements(tag_name: "tr")
            wait_cond({:debug=>"could not find #{compare}"}, 600){
              trs = datatable.find_elements(tag_name: "tr")
              tds = trs[0].find_elements(tag_name: "td")
              tds.empty? || (!tds[0].nil? && tds[0].text != "There is no data available")
            }
            trs = datatable.find_elements(tag_name: "tr")
            trs = trs[1..trs.size]
            trs.each { |tr|
              tds = tr.find_elements(tag_name: "td")
                if tds[num_col].text == compare && tds[num_col].displayed?
                  return tr
                end
            }
            parent = datatable.find_element(:xpath, "..");
            next_button = parent.find_element(:css, "ul.pagination>li#{next_indicator}")
            if next_button
              next_button_classes = next_button.attribute("class")
              if !next_button_classes.include?("disabled")
                next_button.click
                return find_in_datatable(num_col, compare, datatable, next_indicator)
              end
            end
            raise "element with text (#{compare}) not exists in datatable"
          rescue
            if retries < 3
              retries = retries + 1
              retry
            else
              fail "element with text (#{compare}) not exists in datatable"
              return false
            end
          end
        end

        def find_in_datatable_paginated(num_col = 2, compare = "", datatable = nil, refresh = false)
            begin
                fail "Datatable should be a WebDriver Element" if !datatable.is_a?(Selenium::WebDriver::Element)
                fail "Tag datatable should be equal table" if datatable.tag_name != "table"
                id_datatable = datatable.attribute("id")
                pagination = @sunstone_test.get_element_by_id("#{id_datatable}_paginate")

                # wait 2s to ensure correct loading
                sleep 2
                
                # Refresh datatable before look on it
                @sunstone_test.get_element_by_id("refresh_button_#{id_datatable}").click if refresh

                # Calculate number of pages
                number_of_pages = pagination.find_element(:css, "ul.pagination > li:nth-last-child(2)").text.to_i
                return false if number_of_pages == 0
                
                # First page
                btn_first_page = pagination.find_element(:css, "ul.pagination > li + li")
                
                # Go to first page
                btn_first_page.click if btn_first_page.displayed?
                
                # Looking for row in datatable from first page
                loop do
                    current_page = pagination.find_element(:css, "ul.pagination > li.current").text.to_i
                    row = find_row(num_col, compare, datatable)
                    
                    # return row if find it or last page
                    return row if row || current_page == number_of_pages
                    
                    # go to next page
                    btn_next = pagination.find_element(:css, "ul.pagination > li.next")
                    btn_next.click if btn_next.displayed?
                end
            end
        end

        def find_row(num_col = 2, compare = "", datatable = "")
            # Get all rows from current page
            trs = datatable.find_elements(tag_name: "tr")
            
            wait_cond({:debug=>"could not find #{compare}"}, 600){
                trs = datatable.find_elements(tag_name: "tr")
                tds = trs[0].find_elements(tag_name: "td")
                tds.empty? || (!tds[0].nil? && tds[0].text != "There is no data available")
            }

            trs = datatable.find_elements(tag_name: "tr")
            trs = trs[1..trs.size]
            trs.each { |tr|
                tds = tr.find_elements(tag_name: "td")
                if tds[num_col].text == compare && tds[num_col].displayed?
                    return tr
                end
            }
            return false
        end

        # num_col: datatable column number (0: id, 1: name...)
        # compare: element to compare
        # datatable: Selenium Object
        # limit: seg limit
        # block: condition for wait (refresh)
        #
        # return: tr with match
        def check_exists_datatable(num_col, compare, obj, limit_time = 60, &block)
            tr_table = nil
            block.call if block_given?
            begin
                wait_cond({:debug=>"could not find #{compare}"}, limit_time){
                    block.call if block_given?
                    tbody = obj.find_element(tag_name: "tbody")
                    tr_table = tbody.find_elements(tag_name: "tr")
                    tds = tr_table[0].find_elements(tag_name: "td")
                    if !tds.empty? && (!tds[0].nil? && tds[0].text != "There is no data available")
                        tr_table.each { |tr|
                            begin
                                td = tr.find_elements(tag_name: "td")
                                if td.length >= num_col &&
                                   !td[num_col].nil? &&
                                   compare == td[num_col].text
                                    return tr
                                    break
                                end
                            rescue Selenium::WebDriver::Error::StaleElementReferenceError
                            end    
                        }
                        tr = false 
                    end
                }
            rescue
            end
            return false
        end

        # tr_table: tr Array
        # hash: Array [{key: "key", value: "value"}]
        #
        # return: hash without elements match
        def check_elements(tr_table, hash)
            tr_table.each { |tr|
                td = tr.find_elements(tag_name: "td")
                if td.length > 0
                    hash.each{ |obj|
                        if obj[:key] == td[0].text && obj[:value] != td[1].text
                            fail "Check fail: #{obj[:key]} : #{obj[:value]}"
                            break
                        elsif obj[:key] == td[0].text && obj[:value] == td[1].text
                            hash.delete(obj)
                        end
                    }
                end
            }
            return hash
        end

        def check_elements_raw(pre, hash)
            tmpl_text = pre.attribute("innerHTML")
            hash_copy = hash[0 .. hash.length]
            hash.each{ |obj|
                compare = obj[:key] + ' = "' + obj[:value] + '"'
                if tmpl_text.include? compare
                    hash_copy.delete(obj)
                end
            }
            return hash_copy
        end

        def delete_resource(name, general, resource, datatable)
            self.wait_jGrowl
            self.navigate(general, resource)
            res = self.check_exists(2, name, datatable)
            if res
                td = res.find_elements(tag_name: "td")[0]
                td_input = td.find_element(:class, "check_item")
                check = td.attribute("class")
                td_input.click if check.nil? || check == ""
                @sunstone_test.get_element_by_id("#{resource}-tabdelete_buttons").click
                @sunstone_test.get_element_by_id("confirm_proceed").click
            else
                fail "Error delete: Resource not found"
            end
            sleep 2
        end

        def wait_jGrowl()
            begin
                while $driver.find_elements(:class, "jGrowl-notify-submit").size() > 0 do
                    notification = $driver.find_element(:xpath, "//button[contains(@class, 'jGrowl-close')]")
                    notification.click if notification
                    sleep 0.5
                end
            rescue Selenium::WebDriver::Error::NoSuchElementError,
                Selenium::WebDriver::Error::StaleElementReferenceError,
                Timeout::Error => e
                self.save_temp_screenshot('notification-err', e)
            end

            $driver.find_elements(:class, "jGrowl-notify-error").each { |e|
                e.find_element(:class, "jGrowl-close").click
                sleep 0.5
            }
        end

        def update_name(new_name)
            sleep 1
            a = @sunstone_test.get_element_by_id("div_edit_rename_link")
            a.find_element(:tag_name, "i").click
            input_name = @sunstone_test.get_element_by_id("input_edit_rename")
            input_name.clear
            input_name.send_keys "#{new_name}"
            input_name.send_keys :enter
        end

        def update_info(xpath, info)
            sleep 0.5
            info.each { |obj_attr|
                attr_element = false
                sleep 0.5
                table = $driver.find_element(:xpath, xpath)
                tr_table = table.find_elements(:tag_name, "tr")
                tr_table.each { |tr|
                    td = tr.find_elements(:tag_name, "td")
                    if td.length > 0 && td[0].text != "There is no data available"
                        if obj_attr[:key] == td[0].text
                            attr_element = tr
                            break
                        end
                    end
                }
                if attr_element
                    td = attr_element.find_elements(:tag_name, "td")[2] #edit
                    td.find_element(:tag_name, "i").click
                    td_value = attr_element.find_elements(tag_name: "td")[1]
                    dropdown = td_value.find_elements(:tag_name, "select")
                    if dropdown.size() > 0 #is select
                        @sunstone_test.click_option(dropdown[0], "value", obj_attr[:value])
                    else
                        input = td_value.find_element(:tag_name, "input")
                        input.clear
                        td = attr_element.find_elements(:tag_name, "td")[2] #edit
                        td.find_element(:tag_name, "i").click
                        td_value = attr_element.find_elements(tag_name: "td")[1]
                        input.send_keys obj_attr[:value]
                    end
                else
                    fail "Information attribute not found: #{obj_attr[:key]}"
                end
                self.wait_jGrowl
            }
        end

        def update_attr(datatable_name, attrs)
            sleep 1
            attrs.each { |obj_attr|
                attr_element = check_exists(0, obj_attr[:key], datatable_name)
                if attr_element
                    attr_element.find_element(:id, "div_edit").click
                    attr_element.find_element(:id, "div_edit").click
                    input = @sunstone_test.get_element_by_id("input_edit_#{obj_attr[:key]}")
                    input.clear
                    input.send_keys obj_attr[:value]
                    input.send_keys :enter
                else
                    @sunstone_test.get_element_by_id("new_key").send_keys obj_attr[:key]
                    @sunstone_test.get_element_by_id("new_value").send_keys obj_attr[:value]
                    @sunstone_test.get_element_by_id("button_add_value").click
                end
                self.wait_jGrowl
            }
        end

        def open_sidebar
            begin
                toggle_button = @sunstone_test.get_element_by_id("menu-toogle")
                toggle_button.click if toggle_button
            rescue
            end
        end

        #
        # :class             => 'ClassName',
        # :class_name        => 'ClassName',
        # :css               => 'CssSelector',
        # :id                => 'Id',
        # :link              => 'LinkText',
        # :link_text         => 'LinkText',
        # :name              => 'Name',
        # :partial_link_text => 'PartialLinkText',
        # :tag_name          => 'TagName',
        # :xpath             => 'Xpath',
        #
        def fill_input_by_finder(finder, element, data)
            fail "Type finder should be a symbol (:example)" if !finder.is_a? Symbol
            fail "Element selector should be a string" if !element.is_a? String
            fail "Data should be a string" if !data.is_a? String

            input = case finder
            when :class, :class_name then @sunstone_test.get_element_by_class(element)
            when :css then @sunstone_test.get_element_by_css(element)
            when :id then @sunstone_test.get_element_by_id(element)
            when :name then @sunstone_test.get_element_by_name(element)
            when :xpath then @sunstone_test.get_element_by_xpath(element, true)
            else
                $driver.find_element(finder, element)
            end

            if input
                begin
                    input.clear
                    input.send_keys data
                rescue
                    fail "Error - Input cannot be filled"
                end
            else
                fail "Input (#{element}) doesn't exists"
            end
        end

        # Wait until find the element by id
        # ** saves screenshot if fails **
        #
        # @param id  [String]  DOM element id
        def wait_element_by_id(id)
            self.wait_cond({
                :debug => "element with id (#{id})",
                :name_screenshot => "wait_error-#{id}"
            }, 20) {
                elements = $driver.find_elements(:xpath, "//*[@id='#{id}']")
                break if elements.size > 0
            }
        end

        # Wait until find the element by xpath
        # ** saves screenshot if fails **
        #
        # @param xpath  [String]  DOM element xpath
        def wait_element_by_xpath(xpath)
            self.wait_cond({
                :debug => "element with xpath (#{xpath})",
                :name_screenshot => "wait_error-#{xpath}"
            }, 20) {
                element = $driver.find_element(:xpath, xpath)
                break if element.displayed?
            }
        end

        # Mouse hover perform on the element
        #
        # @param element  [Selenium::WebDriver::Element]  DOM element
        def hover_element(element)
            begin
                $driver.action.move_to(element).perform
            rescue StandardError => e
                save_temp_screenshot('hover-element', e.to_s)
            end
        end

        # Generates random file pathname on /var/lib/one/debug/
        #
        # @param filename   [String]  File name
        # @param extension  [String]  File extension
        def generate_tempfile_path(filename = '', extension = '')
            debug_location = File.join(Dir.home, 'debug')

            unless Dir.exist? debug_location
                Dir.mkdir(debug_location)
            end

            "#{debug_location}/#{filename}-#{SecureRandom.uuid}#{extension}"
        end

        # Saves screenshot and current HTML on home directory: /var/lib/one/debug/
        # Could be fail with error message after saving files
        #
        # @param filename   [String]  File name
        # @param error_msg  [String]  Error message
        def save_temp_screenshot(filename = '', error_msg = nil)
            sc_filepath = generate_tempfile_path(filename, '.png')
            $driver.save_screenshot(sc_filepath)

            html_filepath = generate_tempfile_path(filename, '.html')
            open(html_filepath, 'a') do |file|
                file.write($driver.page_source)
            end

            fail "Error: #{error_msg}.
                  HTML: #{html_filepath}.
                  Screenshot: #{sc_filepath}" if error_msg
        end

    end

end
