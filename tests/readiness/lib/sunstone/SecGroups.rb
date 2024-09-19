require 'sunstone/Utils'

class Sunstone
    class SecGroups
        def initialize(sunstone_test)
            @general_tag = "network"
            @resource_tag = "secgroups"
            @datatable = "dataTableSecurityGroups"
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
        end

        def create(name, rules = [], extra_params = {})
            @utils.navigate(@general_tag, @resource_tag)

            if !@utils.check_exists(2, name, @datatable)
                @utils.navigate_create(@general_tag, @resource_tag)
                @sunstone_test.get_element_by_id("security_group_name").send_keys name

                add_rules(rules, extra_params)

                @utils.submit_create(@resource_tag)
            end
        end

        def update(name, rules = [], extra_params = {})
            navigate_update(name)
            remove_rules

            add_rules(rules, extra_params)

            @utils.submit_create(@resource_tag)
        end

        def delete(name)
            @utils.delete_resource(name, @general_tag, @resource_tag, @datatable)
        end

        private

        def add_rules(rules, extra_params = {})
            rules.each do |rule|
                rule.each do |key, value|
                    dropdown = $driver.find_element(:class, "security_group_rule_#{key}")
                    @sunstone_test.click_option(dropdown, "value", value)
                end

                if rule[:network_sel] == "VNET"
                    vnet = @utils.check_exists(0, "#{extra_params[:vnet_id]}", "new_sg_rule")
                    if vnet
                        vnet.click
                    else
                        fail "VNet with id: #{extra_params[:vnet_id]} not exists"
                    end
                end
                $driver.find_element(:class, "add_security_group_rule").click
            end
        end

        def remove_rules
            sleep 1
            table = $driver.find_element(:class, "policies_table")
            rules = table.find_elements(:class, "remove-tab")

            rules.each do |rule|
                rule.click
            end
        end

        def navigate_update(name)
            @utils.navigate(@general_tag, @resource_tag)
            secgroup = @utils.check_exists(2, name, @datatable)
            if secgroup
                td = secgroup.find_elements(tag_name: "td")[0]
                td.find_element(:class, "check_item").click
                span = @sunstone_test.get_element_by_id("#{@resource_tag}-tabmain_buttons")
                buttons = span.find_elements(:tag_name, "button")
                buttons[0].click
            else
                fail "Security group name: #{name} not exists"
            end
        end

    end
end
