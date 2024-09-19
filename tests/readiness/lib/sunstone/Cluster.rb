require 'sunstone/Utils'

class Sunstone
    class Cluster
        def initialize(sunstone_test)
            @general_tag = "infrastructure"
            @resource_tag = "clusters"
            @datatable = "dataTableClusters"
            @sunstone_test = sunstone_test
            @utils = Utils.new(sunstone_test)
        end

        def create(name, hash = {})
            @utils.navigate(@general_tag, @resource_tag)

            if !@utils.check_exists(2, name, @datatable)
                @utils.navigate_create(@general_tag, @resource_tag)
                sleep 0.1
                form = @sunstone_test.get_element_by_id("createClusterFormWizard")
                form.find_element(:id, "name").send_keys name
                hash[:hosts].each{ |host_name|
                    host = @utils.check_exists(1, host_name, "cluster_wizard_hosts")
                    if host
                        host.click
                    else
                        fail "Host name not found: #{host_name}"
                    end
                }

                @sunstone_test.get_element_by_id("tab-vnetsTab-label").click
                hash[:vnets].each{ |vnet_name|
                    vnet = @utils.check_exists(1, vnet_name, "cluster_wizard_vnets")
                    if vnet
                        vnet.click
                    else
                        fail "Vnet name not found: #{vnet_name}"
                    end
                }

                @sunstone_test.get_element_by_id("tab-datastoresTab-label").click
                hash[:ds].each{ |ds_name|
                    ds = @utils.check_exists(1, ds_name, "cluster_wizard_datastores")
                    if ds
                        ds.click
                    else
                        fail "Datastore name not found: #{ds_name}"
                    end
                }

                @utils.submit_create(@resource_tag)
                @utils.wait_jGrowl
            end
        end

        def check(name, hash = {})
            @utils.navigate(@general_tag, @resource_tag)

            cs = @utils.check_exists(2, name, @datatable)
            if cs
                @utils.wait_jGrowl
                cs.click
                @sunstone_test.get_element_by_id("#{@resource_tag}-tab")

                @sunstone_test.get_element_by_id("cluster_host_tab-label").click
                @sunstone_test.get_element_by_id("cluster_host_tabHostsTable_wrapper")

                hash[:hosts].each{ |host_id|
                    if !@utils.check_exists(1, host_id, "cluster_host_tabHostsTable")
                        fail "Host not found: #{host_id}"
                    end
                }

                @sunstone_test.get_element_by_id("cluster_vnet_tab-label").click
                @sunstone_test.get_element_by_id("cluster_vnet_tabVNetsTable_wrapper")

                hash[:vnets].each{ |vnet_id|
                    if !@utils.check_exists(1, vnet_id, "cluster_vnet_tabVNetsTable")
                        fail "Vnet not found: #{vnet_id}"
                    end
                }

                @sunstone_test.get_element_by_id("cluster_datastore_tab-label").click
                @sunstone_test.get_element_by_id("cluster_datastore_tabDatastoresTable_wrapper")

                hash[:ds].each{ |ds_id|
                    if !@utils.check_exists(1, ds_id, "cluster_datastore_tabDatastoresTable")
                        fail "Datastore not found: #{ds_id}"
                    end
                }
            end
        end

        def update(name, hash)
            @utils.navigate(@general_tag, @resource_tag)
            cluster = @utils.check_exists(2, name, @datatable)
            if cluster
                cluster.click
                @sunstone_test.get_element_by_id("cluster_info_tab")
                if hash[:reserved_cpu]
                    input = nil
                    id = "textInput_reserved_cpu"
                    @utils.wait_cond({:debug=>"could not find #{id}"}, 60){
                        input = @sunstone_test.get_element_by_id(id)
                    }
                    input.clear()
                    input.send_keys hash[:reserved_cpu]
                    @sunstone_test.get_element_by_id("update_reserved").click
                end
                if hash[:reserved_mem]
                    input = nil
                    id = "textInput_reserved_mem"
                    @utils.wait_cond({:debug=>"could not find #{id}"}, 60){
                        input = @sunstone_test.get_element_by_id(id)
                    }
                    input.clear()
                    input.send_keys hash[:reserved_mem]
                    @sunstone_test.get_element_by_id("update_reserved").click
                end
                @sunstone_test.get_element_by_id("clusters-tabmain_buttons").click
                if hash[:hosts] && !hash[:hosts].empty?
                    hash[:hosts].each { |host_name|
                        host = @utils.check_exists(1, host_name, "cluster_wizard_hosts")
                        if host
                            host.click
                        else
                            fail "Host name not found: #{host_name}"
                        end
                    }
                end
                if hash[:vnets] && !hash[:vnets].empty?
                    @sunstone_test.get_element_by_id("tab-vnetsTab-label").click
                    @sunstone_test.get_element_by_id("cluster_wizard_vnetsContainer")
                    hash[:vnets].each { |vnet_name|
                        vnet = @utils.check_exists(1, vnet_name, "cluster_wizard_vnets")
                        if vnet
                            vnet.click
                        else
                            fail "VNet name not found: #{vnet_name}"
                        end
                    }
                end
                if hash[:ds] && !hash[:ds].empty?
                    @sunstone_test.get_element_by_id("tab-datastoresTab-label").click
                    @sunstone_test.get_element_by_id("cluster_wizard_datastoresContainer")
                    hash[:ds].each { |ds_name|
                        ds = @utils.check_exists(1, ds_name, "cluster_wizard_datastores")
                        if ds
                            ds.click
                        else
                            fail "Datastore name not found: #{ds_name}"
                        end
                    }
                end
                @utils.submit_create(@resource_tag)
            end
        end

        def remove_resources(name, hash)
            update(name, hash)
        end

        def delete(name)
            @utils.delete_resource(name, @general_tag, @resource_tag, @datatable)
        end
    end
end
