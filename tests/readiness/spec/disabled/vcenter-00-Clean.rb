require 'init'
require 'vcenter_driver'
require 'rbvmomi'

RSpec.describe "vCenter Cleanup Tasks" do

    before(:all) do
        @defaults = RSpec.configuration.defaults
        @info = {}

        opts = {
            :insecure => true,
            :host     => @defaults[:vcenter],
            :user     => @defaults[:vuser],
            :password => @defaults[:vpass]
        }

        @vim = RbVmomi::VIM.connect(opts)
    end

    it "clean vcenter networks" do
        pc = @vim.serviceContent.propertyCollector

        #Get all port groups and distributed port groups in vcenter instance
        view = @vim.serviceContent.viewManager.CreateContainerView({
                container: @vim.rootFolder,
                type:      ['Network','DistributedVirtualPortgroup'],
                recursive: true
        })

        filterSpec = RbVmomi::VIM.PropertyFilterSpec(
            :objectSet => [
                :obj => view,
                :skip => true,
                :selectSet => [
                RbVmomi::VIM.TraversalSpec(
                    :name => 'traverseEntities',
                    :type => 'ContainerView',
                    :path => 'view',
                    :skip => false
                )
                ]
            ],
            :propSet => [
                { :type => 'Network', :pathSet => ['name'] },
                { :type => 'DistributedVirtualPortgroup', :pathSet => ['name'] }
            ]
        )
        result = pc.RetrieveProperties(:specSet => [filterSpec])

        processed = []
        result.each do |net|
            name = net.propSet.first.val

            next unless name.match(/^test_pg_[0-9]*$/) || name.match(/^test_pg_upl_[0-9]*$/) || processed.include?(name)

            if net.obj.class == RbVmomi::VIM::DistributedVirtualPortgroup
                dswitch = net.obj.config.distributedVirtualSwitch rescue nil
                dswitch.Destroy_Task if dswitch
            elsif net.obj.class == RbVmomi::VIM::Network
                hosts = net.obj.host rescue nil
                next unless hosts

                hosts.each do |host|

                    # Network system for the selected host
                    system = host.configManager.networkSystem

                    # Delete every switch
                    system.networkConfig.portgroup.each do |pg|
                        name_d = pg.spec.name
                        next unless name_d.match(/^test_pg_[0-9]*$/) || name_d.match(/^test_pg_upl_[0-9]*$/)
                        processed << name_d

                        swname = pg.spec.vswitchName

                        system.RemovePortGroup(:pgName => pg.spec.name)
                        system.RemoveVirtualSwitch(:vswitchName => swname) if swname.match(/^test_sw_[0-9]*$/)
                    end

                end
            end
        end

        # Destroy the view
        view.DestroyView

    end

    it "get clusters info" do
        view = @vim.serviceContent.viewManager.CreateContainerView({
            container: @vim.rootFolder,
            type:      ['ClusterComputeResource'],
            recursive: true
        })
        pc = @vim.serviceContent.propertyCollector

        filterSpec = RbVmomi::VIM.PropertyFilterSpec(
            :objectSet => [
                :obj => view,
                :skip => true,
                :selectSet => [
                RbVmomi::VIM.TraversalSpec(
                    :name => 'traverseEntities',
                    :type => 'ContainerView',
                    :path => 'view',
                    :skip => false
                )
                ]
            ],
            :propSet => [
                { :type => 'ClusterComputeResource', :pathSet => ['name','resourcePool'] }
            ]
        )

        result = pc.RetrieveProperties(:specSet => [filterSpec])
        result.each do |r|
            pair = r.propSet
            @info[:destination] = pair[1].val if pair[0].val.include?("Cluster2")
        end
    end

    it "cleans all vcenter VMs" do

        view = @vim.serviceContent.viewManager.CreateContainerView({
            container: @vim.rootFolder, #View for VMs inside this cluster
            type:      ['VirtualMachine'],
            recursive: true
        })

        pc = @vim.serviceContent.propertyCollector

        properties = [
            "name", #VM name
            "config.template", #To filter out templates
            "summary.runtime.powerState", #VM power state
        ]

        filterSpec = RbVmomi::VIM.PropertyFilterSpec(
            :objectSet => [
                :obj => view,
                :skip => true,
                :selectSet => [
                RbVmomi::VIM.TraversalSpec(
                    :name => 'traverseEntities',
                    :type => 'ContainerView',
                    :path => 'view',
                    :skip => false
                )
                ]
            ],
            :propSet => [
                { :type => 'VirtualMachine', :pathSet => properties }
            ]
        )

        result = pc.RetrieveProperties(:specSet => [filterSpec])
        params = [:pool=> @info[:destination], :priority => "defaultPriority"]

        # Results loop
        result.each do |r|
            hashed_properties = r.to_hash
            if r.obj.is_a?(RbVmomi::VIM::VirtualMachine)
                # Only take care of VMs starting with one and that are not templates
                if hashed_properties["name"].start_with?("one-") && !hashed_properties["config.template"]
                    # First poweroff the VM
                    if hashed_properties["summary.runtime.powerState"] != "poweredOff"
                        r.obj.PowerOffVM_Task.wait_for_completion
                    end
                    # Destroy the VM
                    r.obj.Destroy_Task.wait_for_completion
                elsif hashed_properties["name"].include?("wild")
                    r.obj.PowerOffVM_Task.wait_for_completion rescue nil
                    r.obj.MigrateVM_Task(*params).wait_for_completion
                # Only take care of VM Templates starting with sunstone_test_ and that are templates
                elsif hashed_properties["name"].start_with?("sunstone_test_")
                    # Destroy the VM Template
                    r.obj.Destroy_Task.wait_for_completion
                end
            end
        end

        # Destroy the view
        view.DestroyView
    end

    it "cleanup datastore" do
        regexs = [
            '.*/one-[^/]*$',
            '.*/one_[^/]*$',
            '.*/[0-9a-f]{32}(/.*)?$',
            '.*/[0-9a-f]{32}.vmdk',
            '.*/[0-9a-f]{32}-flat.vmdk' ]

        cmds = []

        regexs.each do |r|
            delete_cmd = "find #{@defaults[:vcenter_datastore_path]} -mindepth 1 -maxdepth 1 -regextype posix-egrep -regex '#{r}' -exec rm -r '{}' \\;"
            cmds << SafeExec.run("ssh #{@defaults[:vcenter_datastore_host]} \"#{delete_cmd}\"").success?
        end

        new_path = "#{@defaults[:vcenter_datastore_path]}/#{@defaults[:template]}"
        delete_cmd = "find #{new_path} -mindepth 1 -maxdepth 1 -regextype sed -regex '.*/corelinux7_x86_64_5-000001-[0-9]*-[0-9][-flat]*.vmdk' -exec rm '{}' \\;"
        cmds << SafeExec.run("ssh #{@defaults[:vcenter_datastore_host]} \"#{delete_cmd}\"").success?

        # Delete copies of image with spaces
        new_path = "#{@defaults[:vcenter_datastore_path]}/image\\ with\\ spaces"
        delete_cmd = "find #{new_path} -mindepth 1 -maxdepth 1 -regextype posix-egrep -regex '.*[0-9]-[0-9].*' -exec rm '{}' \\;"
        # cmds << SafeExec.run("ssh #{@defaults[:vcenter_datastore_host]} \"#{delete_cmd}\"").success?

        expect(cmds).not_to include(false)
    end

    after(:all) do
        @vim.close if @vim
    end
end
