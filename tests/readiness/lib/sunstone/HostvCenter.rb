require 'sunstone/Utils'

class Sunstone
    class HostvCenter
        def initialize(sunstone_test)
            @general_tag = "infrastructure"
            @resource_tag = "hosts"
            @datatable = "dataTableHosts"
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
        end

        def import(cluster_name, opts)
            @utils.navigate(@general_tag, @resource_tag)
            if !@utils.check_exists(2, cluster_name, @datatable)
                @utils.navigate_create(@general_tag, @resource_tag)

                tabs = @sunstone_test.get_element_by_id("hosts-tabreset_button")
                tabs.find_element(tag_name: "button").click
                sleep 1

                dropdown = @sunstone_test.get_element_by_id("host_type_mad")
                @sunstone_test.click_option(dropdown, "value", "vcenter")
                sleep 1

                hostname = @sunstone_test.get_element_by_id("vcenter_host")
                hostname.clear
                hostname.send_keys opts[:hostname]
                user = @sunstone_test.get_element_by_id("vcenter_user")
                user.clear
                user.send_keys opts[:user]
                pass = @sunstone_test.get_element_by_id("vcenter_password")
                pass.clear
                pass.send_keys opts[:pass]
                @sunstone_test.get_element_by_id("get_vcenter_clusters").click
                sleep 3

                div = $driver.find_element(:class, "vcenter_credentials")
                table = div.find_element(:class, "vcenter_import_table")

                host = @utils.check_exists_datatable(1, cluster_name, table)
                if host
                    host.click
                    @sunstone_test.get_element_by_id("import_vcenter_clusters").click
                else
                    fail "Host name: #{cluster_name} not exists"
                end
            end
        end

        def import_wilds(cluster_name, opts)
            @utils.navigate(@general_tag, @resource_tag)
            host = @utils.check_exists(2, cluster_name, @datatable)

            if host
                begin
                    retries ||= 0
                    wild_found = false

                    host.click
                    @sunstone_test.get_element_by_id("host_wilds_tab-label").click

                    wild_tr = check_wilds(opts[:wild_name], "datatable_host_wilds", 1)

                    if wild_tr
                      tds = wild_tr.find_elements(tag_name: "td")
                      input = tds[0].find_element(tag_name: "input").click
                      @sunstone_test.get_element_by_id("import_wilds").click
                      wild_found = true
                    end

                    raise "Wild not found" unless wild_found
                rescue
                    sleep 10
                    retry if (retries += 1) < 3
                end
            else
                fail "Host name: #{cluster_name} not exists"
            end
            sleep 7
        end

        def check_tab_resource_pool(cluster_name, rp_array)
            @utils.navigate(@general_tag, @resource_tag)
            host = @utils.check_exists(2, cluster_name, @datatable)
            if host
                host.click
                @sunstone_test.get_element_by_id("host_pool_tab-label").click

                pool_tab_content = @sunstone_test.get_element_by_id("host_pool_tab")

                cards = pool_tab_content.find_elements(:css, "#host_pool_tab div.column")
                cards.each do |card|
                    card.displayed?

                    rp_name = card.find_element(:class, "button").text;
                    rp_hash = nil

                    rp_array.each do |rp|
                        hash = rp.to_hash["VCENTER_RESOURCE_POOL_INFO"]
                        if rp_name == hash["NAME"]
                            rp_hash = hash
                            rp_hash.delete("NAME")
                        end
                    end

                    table = card.find_element(:class, "dataTable")
                    tr_table = table.find_elements(tag_name: 'tr')

                    hash_info = []
                    rp_hash.each do |key , value|
                        hash_info.push({key: key, value: value})
                    end

                    hash_info = @utils.check_elements(tr_table, hash_info)

                    if !hash_info.empty?
                        hash_info.each{ |obj| puts "#{obj[:key]} : #{obj[:value]}" }
                        fail "Check fail info: Not Found all keys"
                    end
                end
            end
        end

        private

        def check_wilds(compare, datatable, num_col=2)
          begin
              table = @sunstone_test.get_element_by_id(datatable)
          rescue Selenium::WebDriver::Error::TimeoutError
              table = $driver.find_element(:id, datatable)
          end
          return @utils.find_in_datatable(num_col, compare, table, '#datatable_host_wilds_next')
        end
    end
end
