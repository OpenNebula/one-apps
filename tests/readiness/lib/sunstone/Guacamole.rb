require 'sunstone/Utils'

class Sunstone

    class Guacamole

        def initialize(sunstone_test)
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
        end

        private

        def get_connection_state
            xpath_toolbar_state = "//header//*[contains(@class, 'toolbar__state')]"

            wait_args = { :debug => 'toolbar state stop loading',
                :name_screenshot => 'guacamole-toolbar-state' }

            @utils.wait_cond(wait_args, 10) {
                toolbar_state = @sunstone_test.get_element_by_xpath(xpath_toolbar_state)

                next if (toolbar_state == false || toolbar_state.text == '')

                return toolbar_state.text.upcase
            }
        end

        def wait_until_connected
            reconnect_action = get_actions().find {
                |action| action.attribute('id') == 'buttons__reconnect'
            }

            @sunstone_test.retry_loop(retries: 10,
                                      delay_after_retry: 10,
                                      screenshot: 'error-state-connected') do
                connection_state = get_connection_state

                if connection_state != 'CONNECTED'
                    # force to reconnect if it's not connected
                    reconnect_action.click if reconnect_action
                    fail "The remote connection is unavailable"
                end

                return connection_state
            end
        end

        def get_vm_information
            xpath_information = "//header//*[contains(@class, 'information')]/*/div"

            title, started_time, ips_dropdown = $driver.find_elements(:xpath, xpath_information)

            state = title.find_element(:tag_name, 'span').attribute('title')

            @utils.hover_element(ips_dropdown)
            # when VM has only one IP, menu-hide isn't exists
            ips = ips_dropdown.find_element(:class, 'menu-hide') rescue ips_dropdown

            return {
                state: state,
                title: title.text,
                started_time: started_time.text,
                ips: ips.text
            }
        end

        def get_canvas
            xpath_canvas = "//main//canvas"

            wait_args = { :debug => 'canvas with remote connection',
                :name_screenshot => 'guacamole-canvas' }

            @utils.wait_cond(wait_args, 10) {
                canvas = @sunstone_test.get_element_by_xpath(xpath_canvas)

                next if canvas == false

                return canvas
            }
        end

        def get_actions
            xpath_toolbar_actions = "//header
                                     //*[contains(@class, 'toolbar__buttons')]
                                     /*[not(contains(@class, 'hidden'))]"

            wait_args = { :debug => 'toolbar actions for guacamole',
                :name_screenshot => 'guacamole-actions' }

            @utils.wait_cond(wait_args, 10) {
                actions = $driver.find_elements(:xpath, xpath_toolbar_actions)

                next if actions.length == 0

                return actions
            }
        end

        public

        def get_info_from_interface
            begin
                { connection_state: wait_until_connected,
                  vm: get_vm_information,
                  canvas: get_canvas,
                  actions: get_actions }
            rescue StandardError => e
                @utils.save_temp_screenshot('guacamole-interface' , e)
            end
        end

    end

end
