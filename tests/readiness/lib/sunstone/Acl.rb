require 'sunstone/Utils'

class Sunstone
    class Acl
        def initialize(sunstone_test)
            @general_tag = "system"
            @resource_tag = "acls"
            @sunstone_test = sunstone_test
            @datatable = "dataTableAcls"
            @utils = Utils.new(sunstone_test)
        end

        def refresh_users
            @utils.navigate(@general_tag, "users")
            @sunstone_test.get_element_by_id("users-tabrefresh_buttons").click
        end

        def create(apply, hash = {}, extra_apply = nil, extra_subset = nil)
            @utils.navigate_create(@general_tag, @resource_tag)

            checkbox = @sunstone_test.get_element_by_id("applies_#{apply}").click
            if !extra_apply.nil?
               element = @sunstone_test.get_element_by_id("applies_to_#{extra_apply[0]}")
               dropdown = element.find_element(:class, "resource_list_select")
               @sunstone_test.click_option(dropdown, "value", extra_apply[1])
            end

            if hash[:zone]
                element = @sunstone_test.get_element_by_id("zones_applies")
                dropdown = element.find_element(:class, "resource_list_select")
                @sunstone_test.click_option(dropdown, "value", hash[:zone])
            end

            hash[:resources].each{ |resource| @sunstone_test.get_element_by_id("res_#{resource}").click }

            checkbox = @sunstone_test.get_element_by_id("res_subgroup_#{hash[:subset]}").click
            if !extra_subset.nil?
                if hash[:subset] == "id"
                    @sunstone_test.get_element_by_id("res_#{extra_subset[0]}").send_keys extra_subset[1]
                else
                    element = @sunstone_test.get_element_by_id(extra_subset[0])
                    dropdown = element.find_element(:class, "resource_list_select")
                    @sunstone_test.click_option(dropdown, "value", extra_subset[1])
                end
            end

            hash[:operations].each{ |op| @sunstone_test.get_element_by_id("right_#{op}").click }

            @utils.submit_create(@resource_tag)
        end

        def delete_by_id(id)
            @utils.wait_jGrowl
            @utils.navigate(@general_tag, @resource_tag)
            res = @utils.check_exists(1, id, @datatable)
            if res
                td = res.find_elements(tag_name: "td")[0]
                td_input = td.find_element(:class, "check_item")
                check = td.attribute("class")
                td_input.click if check.nil? || check == ""
                @sunstone_test.get_element_by_id("#{@resource_tag}-tabdelete_buttons").click
                @sunstone_test.get_element_by_id("confirm_proceed").click
            else
                fail "Error delete: Resource not found"
            end
            sleep 2
        end
    end
end
