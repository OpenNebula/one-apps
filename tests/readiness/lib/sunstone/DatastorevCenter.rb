require 'sunstone/Utils'

class Sunstone
    class DatastorevCenter
        def initialize(sunstone_test)
            @general_tag = "storage"
            @resource_tag = "datastores"
            @datatable = "dataTableDatastores"
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
        end

        def import(cluster_name, opts)
            @utils.navigate(@general_tag, @resource_tag)

            if !@utils.check_exists(2, cluster_name, @datatable)
                @utils.navigate_import(@general_tag, @resource_tag)

                tab = @sunstone_test.get_element_by_id("datastores-tab-wizardForms")

                table = tab.find_element(:class, "dataTable")
                host = @utils.check_exists_datatable(1, cluster_name, table)

                if host
                    host.click
                    @sunstone_test.get_element_by_id("get-vcenter-ds").click
                    sleep 3
                else
                    msg = "Host name: #{cluster_name} not exists"
                    @utils.save_temp_screenshot('vcenter-host', msg)
                end

                table = tab.find_element(:class, "vcenter_import_table")

                all_ds = [ opts[:datastore],
                           opts[:datastore1],
                           opts[:datastore2] ]

                all_ds.each { |ds_name|
                    ds = @utils.check_exists_datatable(1, ds_name, table)
                    if ds
                        ds.click
                    end
                }

                @sunstone_test.get_element_by_id("import_vcenter_datastores").click
            end
        end
    end
end
