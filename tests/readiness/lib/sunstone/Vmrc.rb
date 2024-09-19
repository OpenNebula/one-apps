require 'sunstone/Utils'

class Sunstone

    class Vmrc

        def initialize(sunstone_test)
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
        end

        private

        def get_connection_state
            xpath_toolbar_state = "//*[@id='VMRC_status']"

            wait_args = { :debug => 'toolbar state stop loading',
                :name_screenshot => 'vmrc-toolbar-state' }

            @utils.wait_cond(wait_args, 10) {
                toolbar_state = @sunstone_test.get_element_by_xpath(xpath_toolbar_state)

                next if (toolbar_state == false || toolbar_state.text == '')

                return toolbar_state.text.upcase
            }
        end

        def get_vm_information
            xpath_information = "//*[@class='VMRC_info']/*/div"

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
            xpath_canvas = "//*[@id='VMRC_canvas']//canvas"

            wait_args = { :debug => 'canvas with remote connection',
                :name_screenshot => 'vmrc-canvas' }

            @utils.wait_cond(wait_args, 10) {
                canvas = @sunstone_test.get_element_by_xpath(xpath_canvas)

                next if canvas == false

                return canvas
            }
        end

        public

        def get_info_from_interface
            begin
                { connection_state: get_connection_state,
                  vm: get_vm_information,
                  canvas: get_canvas }
            rescue StandardError => e
                @utils.save_temp_screenshot('vmrc-interface' , e)
            end
        end

    end

end
