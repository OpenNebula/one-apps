require 'vcenter_driver'
require 'fileutils'

module VOneCloudHelpers
    def load_conf
        test_type = ENV['TEST_TYPE']
        test_group = ENV['TEST_GROUP']
        path = ENV['ONE_SIMLOCATION'] + "/tests/" + test_type + "/etc/configuration.yaml"
        allconfigurations=YAML.load(File.read(path))
        @conf=allconfigurations[test_group.to_sym]
    end

    def get_hosts
        host_pool=OpenNebula::HostPool.new(OpenNebula::Client.new)
        host_pool.info

        [host_pool.to_hash['HOST_POOL']['HOST']].flatten
    end

    def vc_vm(test_vm)
        test_vm.state?(/RUNNING|^BOOT|^POWEROFF/,/FAIL|UNKNOWN/)
        test_vm.info
        did       = test_vm["DEPLOY_ID"]
        hid       = test_vm["HISTORY_RECORDS/HISTORY[last()]/HID"].to_i
        one_vm    = VCenterDriver::VIHelper.one_item(OpenNebula::VirtualMachine, test_vm.id)
        vi_client = VCenterDriver::VIClient.new_from_host(hid)

        VCenterDriver::VirtualMachine.new_one(vi_client, did, one_vm)
    end

    def get_host(name)
        get_hosts.find do |host|
            if host
                host['NAME'] == name
            end
        end
    end

    def get_host_by_vcenter_name(name)
        get_hosts.find do |host|
            if host
                host['TEMPLATE']['HOST']['HOSTNAME'] == name if host['TEMPLATE'].key?('HOST')
            end
        end
    end


    def wait_host(name, count = 1000)
        host = get_host(name)
        return false if !host

        while host['STATE'] != '2'
            STDERR.puts "Host state: #{host['STATE']} | #{count}"
            sleep 1

            host = get_host(name)

            return false if !host

            count -= 1
            return false if count == 0
        end

        true
    end

    def get_templates
        template_pool=OpenNebula::TemplatePool.new(OpenNebula::Client.new)
        template_pool.info

        [template_pool.to_hash['VMTEMPLATE_POOL']['VMTEMPLATE']].flatten
    end

    def get_datastores
        ds_pool=OpenNebula::DatastorePool.new(OpenNebula::Client.new)
        ds_pool.info

        [ds_pool.to_hash['DATASTORE_POOL']['DATASTORE']].flatten
    end

    def get_template_vc(name)
        get_templates.find do |template|
            if template
                template['NAME'] == name
            end
        end
    end

    def get_datastore_vc(name)
        get_datastores.find do |datastore|
            if datastore
                datastore['NAME'] == name
            end
        end
    end

    def get_vms
        vm_pool=OpenNebula::VirtualMachinePool.new(OpenNebula::Client.new)
        vm_pool.info

        [vm_pool.to_hash['VM_POOL']['VM']].flatten
    end

    def get_vm(id)
        get_vms.find do |vm|
            if vm
                vm['ID'] == id.to_s
            end
        end
    end

    def wait_for_vcenter(opts, timeout)
        t_start = Time.now
        error   = false

        while Time.now - t_start < timeout
            begin
                if RbVmomi::VIM.connect(opts)
                    error = false
                    break
                end
            rescue StandardError
                print '.'
                error = true
            end

            sleep 1
        end

        error
    end

    def wait_vm(id, count = 1000)
        vm = get_vm(id)
        return false if !vm

        while !get_ip(vm)
            STDERR.puts "VM state: #{get_ip(vm)} | #{count}"
            sleep 1

            vm = get_one_vm(vm)

            return false if !vm

            count -= 1
            return false if count == 0
        end

        vm
    end

    def wait_vm_state(id, state = 3, lcm_state = 0, count = 500)
        vm = get_vm(id)
        return false if !vm

        while vm['STATE'] != state.to_s || vm['LCM_STATE'] != lcm_state.to_s
            STDERR.puts "VM state: #{vm['STATE']}/#{vm['LCM_STATE']} | #{count}"
            sleep 1

            vm = get_one_vm(vm)

            return false if !vm

            count -= 1
            return false if count == 0
        end

        vm
    end

    def wait_vm_running(id, count = 500)
        wait_vm_state(id, 3, 3, count)
    end

    def wait_vm_done(id, count = 500)
        wait_vm_state(id, 6, 0, count)
    end

    def wait_vm_shutdown(id, count = 500)
        vm = get_vm(id)
        return false if !vm

        while vm['STATE'] != "6"
            STDERR.puts "VM state: #{vm['STATE']} | #{count}"
            sleep 1

            vm = get_one_vm(vm)
            return false if !vm

            count -= 1
            return false if count == 0
        end

        vm
    end

    def get_entities(folder, type, entities=[])
        return nil if folder == [] # || !folder

        folder.childEntity.each do |child|
            name, junk = child.to_s.split('(')

            case name
            when "Folder"
                get_entities(child, type, entities)
            when type
                entities.push(child)
            end
        end

        return entities
    end

    def clean_vcenter(host)
        host = get_host(host)
        host_name = host['NAME']
        vi_client = VCenterDriver::VIClient.new(host['ID'])

        vms = []

        datacenters = get_entities(vi_client.root, 'Datacenter')
        datacenters.each do |dc|
            vm = get_entities(dc.vmFolder, 'VirtualMachine')
            #STDERR.puts vm.inspect
            vm = vm.select do |v|
                v.config && !v.config.template && v.name.match(/^one-\d/)
            end
            vms += vm.map {|v| v.config.uuid }
        end

        #STDERR.puts vms.inspect

        vms.each do |vm|
            STDERR.puts "Canceling #{vm} in #{host_name}"
            VCenterDriver::VCenterVm.cancel(vm, host_name, "CANCEL", false, nil, nil)
        end
    end

    def execute_vm(template_id, options = {})
        template = OpenNebula::Template.new(
            OpenNebula::Template.build_xml(template_id),
            OpenNebula::Client.new)

        context = "CONTEXT=[\
                SSH_PUBLIC_KEY=\"#{options[:ssh_key]}\", \
                SET_HOSTNAME=\"test-vm\", \
                NETWORK=YES
            ]
            NIC=[NETWORK=\"VM Network\", MODEL=\"vmxnet3\"]"

        id_vm = template.instantiate('test-vm', false, context)
        STDERR.puts id_vm.inspect
        id_vm.class.should_not eq(OpenNebula::Error)

        vm = wait_vm(id_vm)
        vm.should be

        vm
    end

    def check_ssh(vm)
        ip = get_ip(vm)

        ip.should be
        ip.should match(/^(\d{1,3}\.){3}\d{1,3}$/)

        # let ssh start
        sleep 20

        name = cli_action("ssh root@#{ip} hostname")

        name.stdout.strip.should eq('test-vm')
    end

    def get_one_vm(vm)
        vm = OpenNebula::VirtualMachine.new_with_id(
            vm['ID'],
            OpenNebula::Client.new)

        vm.info

        vm
    end

    def get_ip(vm)
        if vm['MONITORING/GUEST_IP']
            vm['MONITORING/GUEST_IP']
        else
            nil
        end
    end

    def shutdown_vm(vm)
        vm = get_one_vm(vm)

        if block_given?
            rc= yield vm
        else
            rc = vm.terminate
        end

        rc.class.should_not eq(OpenNebula::Error)

        id_vm = vm['ID']
        rc = wait_vm_shutdown(id_vm)
        rc.should be

        rc = vm.info
        rc.should be_falsey
    end

    def run_shutdown_cycle(template_id, options = {})
        vm = execute_vm(template_id, options)
        ip = get_ip(vm)

        one_vm = get_one_vm(vm)

        yield vm, one_vm, ip if block_given?

        shutdown_vm(vm) do |v|
            v.terminate(true)
        end
    end


    def create_net(tmpl, cluster=nil)
        cmd = 'onevnet create'
        cmd << " -c #{cluster}" if cluster

        vid = cli_create(cmd, tmpl)

        wait_loop(:success => "READY", :break => "ERROR") {
            xml = cli_action_xml("onevnet show -x #{vid}")
            VirtualNetwork::VN_STATES[xml['STATE'].to_i]
        }

        vid
    end
end

module VCenterOps

    require 'opennebula_test'

    if !ONE_LOCATION
        ONE_VAR_LOCATION = "/var/lib/one"
        ONE_ETC_LOCATION = "/etc/one"
        ONE_DB_LOCATION  = ONE_VAR_LOCATION
    else
        ONE_VAR_LOCATION = ONE_LOCATION + "/var"
        ONE_ETC_LOCATION = ONE_LOCATION + "/etc"
        ONE_DB_LOCATION  = ONE_VAR_LOCATION
    end

    class Cleaner
        def initialize(opts)
            @defaults = opts
            @info = {}

            opts = {
                :insecure => true,
                :host     => @defaults[:vcenter],
                :user     => @defaults[:vuser],
                :password => @defaults[:vpass]
            }

            @vim = RbVmomi::VIM.connect(opts)
        end

        def delete_vm_resource(ref)
            RbVmomi::VIM::VirtualMachine.new(@vim, ref).Destroy_Task.wait_for_completion
        end

        def clean_nets
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

        def get_cluster_info
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

        def cleartags(wild)
            keys_to_remove = ['opennebula.vm.running', 'opennebula.vm.id']
            wild['config.extraConfig'].each do |extraconfig|
                if extraconfig.key.include?('opennebula.disk')
                    keys_to_remove << extraconfig.key
                end
            end

            spec_hash = keys_to_remove.map {|key| { :key => key, :value => '' } }

            spec = RbVmomi::VIM.VirtualMachineConfigSpec(
                { :extraConfig => spec_hash }
            )
            wild.ReconfigVM_Task(:spec => spec).wait_for_completion
        end

        def clean_and_move_vms
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
                    elsif hashed_properties["name"].include?("wild") and
                              hashed_properties["name"] != @defaults[:wild_with_ip][:name].split('-')[0][0..-2] and
                              hashed_properties["name"] != @defaults[:wild03][:name].split('-')[0][0..-2] and
                              hashed_properties["name"] != @defaults[:wild04][:name].split('-')[0][0..-2]
                        r.obj.PowerOffVM_Task.wait_for_completion rescue nil
                        r.obj.MigrateVM_Task(*params).wait_for_completion
                        cleartags r.obj
                    elsif hashed_properties["name"] == @defaults[:wild_with_ip][:name].split('-')[0][0..-2]
                        r.obj.PowerOnVM_Task.wait_for_completion rescue nil
                    elsif hashed_properties["name"] == @defaults[:wild03][:name].split('-')[0][0..-2]
                        r.obj.PowerOnVM_Task.wait_for_completion rescue nil
                    elsif hashed_properties["name"] == @defaults[:wild04][:name].split('-')[0][0..-2]
                        r.obj.PowerOnVM_Task.wait_for_completion rescue nil
                    # Only take care of VM Templates starting with sunstone_test_ and that are templates
                    elsif hashed_properties["name"].start_with?("sunstone_test_")
                        # Destroy the VM Template
                        r.obj.Destroy_Task.wait_for_completion rescue nil
                    end
                end
            end

            # Destroy the view
            view.DestroyView
        end

        def fs_clean
            regexs = [
                '.*/one-[^/]*$',
                '.*/one_[^/]*$',
                '.*/[0-9a-f]{32}(/.*)?$',
                '.*/[0-9a-f]{32}.vmdk',
                '.*/[0-9a-f]{32}-flat.vmdk' ]

            cmds = []

            regexs.each do |r|
                delete_cmd = "find #{@defaults[:vcenter_datastore_path]} -mindepth 1 -maxdepth 1 -regextype posix-egrep -regex '#{r}' -exec rm -r '{}' \\;"
                cmds << SafeExec.run("ssh #{@defaults[:vcenter_datastore_user]}@#{@defaults[:vcenter_datastore_host]} \"#{delete_cmd}\"").success?
            end

            new_path = "#{@defaults[:vcenter_datastore_path]}/#{@defaults[:template]}"
            delete_cmd = "find #{new_path} -mindepth 1 -maxdepth 1 -regextype sed -regex '.*/corelinux7_x86_64_5-000001-[0-9]*-[0-9][-flat]*.vmdk' -exec rm '{}' \\;"
            cmds << SafeExec.run("ssh #{@defaults[:vcenter_datastore_user]}@#{@defaults[:vcenter_datastore_host]} \"#{delete_cmd}\"").success?

            # Delete copies of image with spaces
            new_path = "#{@defaults[:vcenter_datastore_path]}/image\\ with\\ spaces"
            delete_cmd = "find #{new_path} -mindepth 1 -maxdepth 1 -regextype posix-egrep -regex 'spaces-[0-9]*' -exec rm '{}' \\;"
            cmds << SafeExec.run("ssh #{@defaults[:vcenter_datastore_user]}@#{@defaults[:vcenter_datastore_host]} \"#{delete_cmd}\"").success?


            raise "any command failed cleaning the datastore file System" if cmds.include?(false)
        end

        def close
            @vim.close if @vim
        end
    end

    def logs_prepare
        logs_path = '/var/lib/one/testlogs/'

        unless File.directory?(logs_path)
            FileUtils.mkdir_p(logs_path)
        end
    end

    def reset_one
        one_test = OpenNebulaTest.new()

        one_test.log_backup("sunstone_backup_log")
        one_test.clean_oned_log

        # reset one routine:
        %x(pkill -f -9 oned)
        %x(pkill -f -9 mm_sched)
        %x(pkill -f -9 sunstone-server)

        one_test.clean_db
        one_test.clean_var

        # wait for Request Manager
        one_test.wait_for_one
    end

    def prepare_vcenter(defaults)

        cleaner = Cleaner.new(defaults)

        # Filesystem clean
        begin
            cleaner.logs_prepare
            cleaner.fs_clean
        rescue StandardError => e
            STDERR.puts "Error in filesystem cleaner: #{e.message}"
        end

        # vCenter clean
        begin
            cleaner.get_cluster_info
            cleaner.clean_and_move_vms
            cleaner.clean_nets
        rescue StandardError => e
            STDERR.puts "Errors in prepare_vcenter: #{e.message}"
        ensure
            cleaner.close
        end
    end
end
