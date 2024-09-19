require 'sunstone/Utils'

class Sunstone
    class VNetvCenter

        def initialize(sunstone_test)
            @general_tag = "network"
            @resource_tag = "vnets"
            @datatable = "dataTableVNets"
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
            @wait = Selenium::WebDriver::Wait.new(:timeout => 20)
        end

        def import(opts, extra_data = nil)
            @utils.navigate(@general_tag, @resource_tag)

            if !@utils.check_exists(2, opts[:cluster], @datatable)
                @utils.navigate_import(@general_tag, @resource_tag)

                tab = @sunstone_test.get_element_by_id("vnets-tab-wizardForms")
                table = tab.find_element(:class, "dataTable")
                host = @utils.find_in_datatable(1, opts[:cluster], table, "#dataTableVNets_next")

                fail("Host name: #{opts[:cluster]} not exists") if !host
                
                host.click
                @sunstone_test.get_element_by_id("get-vcenter-networks").click
                sleep 3

                @wait.until {
                    table = tab.find_element(:class, "vcenter_import_table")
                    vnet_tr = @utils.find_in_datatable(1, opts[:network_path], table, "#vcenter_import_table_one2_next")

                    fail("Network name: #{opts[:network_path]} not exists") if !vnet_tr

                    tds = vnet_tr.find_elements(tag_name: "td")

                    if !extra_data.nil?
                        tds[1].find_element(tag_name: "a").click
                        extra_data.each { |data|
                            if data[:key] != "type_select"
                                tds[1].find_element(:class, "#{data[:key]}").clear
                            end
                            tds[1].find_element(:class, "#{data[:key]}").send_keys "#{data[:value]}"
                        }
                    end

                    input = tds[0].find_element(tag_name: "input").click

                    @sunstone_test.get_element_by_id("import_vcenter_networks").click
                    sleep 3
                }
            end
        end

    end
end