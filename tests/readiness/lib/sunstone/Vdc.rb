require 'sunstone/Utils'

class Sunstone
    class Vdc
        def initialize(sunstone_test)
            @general_tag = "system"
            @resource_tag = "vdcs"
            @datatable = "dataTableVDCs"
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
        end

        def create(name, groups = [], resources = {}, extra_params = {})
            @utils.navigate(@general_tag, @resource_tag)

            if !@utils.check_exists(2, name, @datatable)
                @utils.navigate_create(@general_tag, @resource_tag)

                add_general(name)
                if !groups.empty?
                    add_groups(groups)
                end
                if !resources.empty?
                    add_resources(resources)
                end

                @utils.submit_create(@resource_tag)
            end
        end

        def create_advanced(template)
            @utils.create_advanced(template, @general_tag, @resource_tag, 'VDC')
        end

        def update(name, groups = [], resources = {}, extra_params = {})
            navigate_update(name)

            if !groups.empty?
                add_groups(groups)
            end
            if !resources.empty?
                add_resources(resources, "update")
            end

            @utils.submit_create(@resource_tag)
        end

        def delete(name)
            @utils.delete_resource(name, @general_tag, @resource_tag, @datatable)
        end

        def delete_resources(name, resources)
            @utils.navigate(@general_tag, @resource_tag)
            if @utils.check_exists(2, name, @datatable)
              navigate_update(name)
              @sunstone_test.get_element_by_id("vdcCreateResourcesTab-label").click
              resources.each do |key, value|
                @sunstone_test.get_element_by_id(value[:tab]).click
                labels_space = @sunstone_test.get_element_by_id(value[:labels])
                spans = labels_space.find_elements(:tag_name, "span")
                spans.each do |span|
                    if span.attribute("row_id") && span.text === value[:element]
                      span.click
                    end
                end
              end
              @utils.submit_create(@resource_tag)
            end
        end

        private

        def add_general(name, custom_attrs = {})
            @sunstone_test.get_element_by_id("vdcCreateGeneralTab-label").click

            tab = @sunstone_test.get_element_by_id("vdcCreateGeneralTab")
            name_input = tab.find_element(:id, "name")

            name_input.clear
            name_input.send_keys name
        end

        def add_groups(groups)
            begin
                @sunstone_test.get_element_by_id("vdcCreateGroupsTab-label").click

                groups.each do |group_id|
                    @utils.check_exists(0, "#{group_id}", "vdc_wizard_groups").click
                end
            rescue StandardError => e
                @utils.save_temp_screenshot('vdc-add-group', e)
            end
        end

        def add_resources(resources, action = "create")
            @sunstone_test.get_element_by_id("vdcCreateResourcesTab-label").click

            resources.each do |key, value|
                @sunstone_test.get_element_by_id("vdc#{key.capitalize}Tab_vdc_#{action}_wizard_0-label").click
                value.each do |id|
                    rs = @utils.check_exists(0, "#{id}", "vdc_#{key}_vdc_#{action}_wizard_0")
                    if rs
                        rs.click
                    else
                        fail "#{key.capitalize} with id: #{id} not exists"
                    end
                end
            end
        end

        def navigate_update(name)
            @utils.navigate(@general_tag, @resource_tag)
            vdc = @utils.check_exists(2, name, @datatable)
            if vdc
                td = vdc.find_elements(tag_name: "td")[0]
                element = td.find_element(:class, "check_item")
                if !element.selected?
                    element.click
                end
                span = @sunstone_test.get_element_by_id("#{@resource_tag}-tabmain_buttons")
                buttons = span.find_elements(:tag_name, "button")
                buttons[0].click
            else
                fail "Vdc name: #{name} not exists"
            end
        end

    end
end
