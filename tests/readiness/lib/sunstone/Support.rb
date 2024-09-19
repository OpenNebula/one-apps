require 'sunstone/Utils'
require 'curb'

class Sunstone
    class Support
        @messages_no_display_form = "No displayed support form"
        @displayed_form_support = false

        def initialize(sunstone_test)
            @general_tag = "support"
            @datatable = "dataTableSupport"
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
        end

        def return_object(success = false, version = 0)
            {:success => success, :version => Gem::Version.new(version)}
        end

        def open_sidebar
            @utils.open_sidebar if !$driver.find_element(:id, "li_#{@general_tag}-tab").displayed?
        end

        def find_latest_version
            github_tags_url = "https://api.github.com/repos/opennebula/one/tags"
            header_url = "OpenNebula Version Validation Sunstone TEST"
            find = "release-"

            begin
                http = Curl.get(github_tags_url) do |request|
                    request.headers['User-Agent'] = header_url
                end
            rescue StandardError
                return return_object
            end

            if !http.nil? && http.response_code == 200
                JSON.parse(http.body_str).each  do |tag|

                    next unless tag &&
                                tag['name'] &&
                                !tag['name'].nil? &&
                                !tag['name'].empty? &&
                                tag['name'].start_with?(find)

                    git_version = tag['name'].tr(find, '')
                    split_version = git_version.split('.')
                    gem_git_version = Gem::Version.new(git_version)
                    gem_local_version = Gem::Version.new(@support_one_last_version)

                    next unless split_version &&
                                split_version[1] &&
                                split_version[1].to_i &&
                                split_version[1].to_i.even?

                    if gem_git_version > gem_local_version
                        @support_one_last_version = git_version
                    end

                    return return_object(true, @support_one_last_version)
                end
            end

            return return_object
        end

        def login(opts)
            self.open_sidebar

            if(@displayed_form_support)
                sleep 2
                $driver.find_element(:class, "support_connect_button").click

                @utils.fill_input_by_finder(:id, 'support_email', opts[:email]) if opts[:email]
                @utils.fill_input_by_finder(:id, 'support_password', opts[:pass]) if opts[:pass]

                $driver.find_element(:class, "submit_support_credentials_button").click

                @utils.wait_element_by_id(@datatable)
            else
                fail @messages_no_display_form
            end
        end

        def get_front_version
            self.open_sidebar

            footer = @sunstone_test.get_element_by_id("footer")
            dom_latest_version = footer.find_element(:id, "latest_version")
            recent_version = footer.find_element(tag_name: "a")

            if(dom_latest_version.displayed?)
                find = "(new version available: "
                find_end = ")"
                version = dom_latest_version.text.tr(find,'').tr(find_end,'')
            else
                find = "OpenNebula "
                version = recent_version.text.tr(find,'')
            end

            Gem::Version.new(version)
        end

        def officially_supported
            self.open_sidebar

            begin
                message = "Commercial Support Requests"
                menu_banner = @sunstone_test.get_element_by_id("li_support-tab")
                validate = menu_banner.find_element(:class, "support_connect")

                wait_loop(:timeout => 60) do
                  validate.displayed?
                end

                button_login = validate.find_element(:class, "support_connect_button")
                if(button_login.displayed?)
                    button_login.click
                    tab = @sunstone_test.get_element_by_id("support-tab")
                    header_title = tab.find_element(:class, "header-title")
                    if(header_title.displayed? && header_title.text != message)
                        raise @messages_no_display_form
                    end
                end
                @displayed_form_support = true
            rescue Exception => e
                fail 'Support not connected'
            end
        end

        def request(opts)
            begin
                # open form
                @sunstone_test.get_element_by_css('#support-tabcreate_buttons > button').click

                @utils.fill_input_by_finder(:id, 'subject', opts[:subject]) if opts[:subject]

                @utils.fill_input_by_finder(:id, 'opennebula_version', opts[:version]) if opts[:version]

                @utils.fill_input_by_finder(:id, 'description', opts[:description]) if opts[:description]

                if opts[:severity]
                    severity = @sunstone_test.get_element_by_id("severity")
                    @sunstone_test.click_option(severity, "value", opts[:severity])
                end

                @utils.save_temp_screenshot('after_submit_the_request')

                # submit form
                @sunstone_test.get_element_by_css('#support-tabsubmit_button > button').click

                @utils.save_temp_screenshot('submitting_the_request')

                sleep 5
                @utils.save_temp_screenshot('submitted_the_request')
            rescue Exception => e
                @utils.save_temp_screenshot('support_request', 'Error in support_request')
            end
        end

        def check_request(opts)
            begin
                table = @sunstone_test.get_element_by_id(@datatable)

                req = @utils.check_exists_datatable(1, opts[:subject], table, 60) {
                    # Refresh block
                    @sunstone_test.get_element_by_css('#support-tabrefresh_buttons > button').click
                    sleep 1
                }

                if !req
                    fail "#{opts[:subject]} request doesn't exists"
                end
            rescue Exception => e
                @utils.save_temp_screenshot('support_request', 'Error in support_request')
            end
        end
    end
end