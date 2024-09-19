require 'json'
require 'yaml'

# Helper class for OneFlow tests
module FlowHelper

    ########################################################################
    # HELPER FUNCTIONS
    ########################################################################

    # Execute command
    #
    # @param cmd [String] command to execute
    def execute_cmd(cmd)
        out, err, ec = Open3.capture3(cmd)

        if !ec.success?
            raise "Error executing #{cmd}: #{err}"
        else
            out
        end
    end

    # Wait until the service and its roles and in an specific state
    #
    # @param service_id [Integer] Service ID
    # @param state      [Integer] State to wait
    #
    # @return [Array] Service and roles states
    def wait_state(service_id, state, timeout = 1000)
        states  = []

        wait_loop(:timeout => timeout, :success => state) do
            service = JSON.parse(execute_cmd("oneflow show -j #{service_id}"))

            get_state(service)
        end

        service = JSON.parse(execute_cmd("oneflow show -j #{service_id}"))

        states << get_state(service)

        get_roles(service).each {|role| states << role['state'].to_i }

        states
    end

    # Wait until role is in specific state
    #
    # @param service_id [Integer] Service ID
    # @param role       [String]  Role name
    # @param state      [Integer] State to wait
    def wait_role_state(service_id, role, state)
        wait_loop(:timeout => 1000, :success => state) do
            service = JSON.parse(execute_cmd("oneflow show -j #{service_id}"))

            self.send("get_#{role}", service)['state'].to_i
        end
    end

    # Get service state
    #
    # @param service [Json] Service information
    def get_state(service)
        service['DOCUMENT']['TEMPLATE']['BODY']['state'].to_i
    end

    # Get service roles
    #
    # @param service [Json] Service information
    def get_roles(service)
        service['DOCUMENT']['TEMPLATE']['BODY']['roles']
    end

    # Get role deploy ID
    #
    # @param service [Json]    Service information
    # @param node    [Integer] Node to take
    def get_deploy_id(role, node = 0)
        role['nodes'][node]['deploy_id']
    end

    # Get master role information
    #
    # @param service [JSON] Service information
    def get_master(service)
        roles = get_roles(service)
        roles.find {|r| r['parents'].nil? }
    end

    # Get slave role information
    #
    # @param service [JSON] Service information
    def get_slave(service)
        roles = get_roles(service)
        roles.find {|r| !r['parents'].nil? }
    end

    # Get specific role
    #
    # @param service [JSON]   Service information
    # @param name    [String] Role to find
    def get_role(service, name)
        roles = get_roles(service)
        roles.find {|r| r['name'] == name }
    end

    # Get document body
    #
    # @param service [JSON] Service information
    def get_body(service)
        service['DOCUMENT']['TEMPLATE']['BODY']
    end

    # Get elasticity policy
    #
    # @param service [JSON]    Service information
    # @param role    [String]  Role name
    # @param idx     [Integer] Policy to take
    def get_elasticity(service, role, idx = 0)
        roles = get_roles(service)
        role  = roles.find {|r| r['name'] == role }

        role['elasticity_policies'][idx]
    end

    ########################################################################
    # TEMPLATE
    ########################################################################

    # Returns oneflow roles VM template
    def vm_template(image = false, vm_name = 'vm_template', image_name='test_flow')
        if image
            <<-EOF
                NAME   = #{vm_name}
                CPU    = 1
                MEMORY = 128
                DISK = [
                    IMAGE       = #{image_name},
                    IMAGE_UNAME = "oneadmin"
                ]
            EOF
        else
            <<-EOF
                NAME   = #{vm_name}
                CPU    = 1
                MEMORY = 128
            EOF
        end
    end

    # Returns oneflow service template
    #
    # @param strategy    [String]  Service strategy
    # @param gate        [Boolean] True to wait until the VM is ready
    # @param network     [Boolean] True to generate network information
    # @param custom      [Boolean] True to generate custom attributes
    # @param automatic   [Boolean] True to set automatic deletion
    # @param hold        [Boolean] True to instantiate vms on hold
    # @param custom_role [Boolean] True to generate custom role attributes
    def service_template(strategy,
                         gate        = false,
                         network     = false,
                         custom      = false,
                         automatic   = false,
                         hold        = false,
                         custom_role = false)
        template = ''

        template << '{'
        template << "\"name\": \"TEST\","
        template << "\"deployment\": \"#{strategy}\","
        template << "\"roles\": ["
        template << '{'
        template << "\"name\": \"MASTER\","
        template << "\"cardinality\": 1,"
        template << "\"vm_template\": 0,"
        template << "\"min_vms\": 1,"
        template << "\"max_vms\": 2,"

        if network
            template << "\"vm_template_contents\": \"NIC=[NETWORK_ID=$Public]\","
        end

        if custom_role
            template << "\"custom_attrs\": {\"Man\": \"M|text|desc| |default\"},"
        end

        template << "\"elasticity_policies\": [],"
        template << "\"scheduled_policies\": []"
        template << '},'
        template << '{'
        template << "\"name\": \"SLAVE\","
        template << "\"cardinality\": 1,"
        template << "\"vm_template\": 0,"
        template << "\"min_vms\": 0,"
        template << "\"max_vms\": 2,"
        template << "\"vm_template_contents\": \"TEST=$\{MASTER.vm.name\}\\nNOT_FOUND=$\{aaaa.not_found\}\","
        template << "\"parents\": ["
        template << "\"MASTER\""
        template << '],'
        template << "\"elasticity_policies\": [],"
        template << "\"scheduled_policies\": []"
        template << '}'
        template << '],'

        if custom
            template << "\"custom_attrs\": {\"Man\": \"M|text|desc| |default\"},"
        end

        if network
            template << "\"networks\": {\"Public\": \"M|vnet_id|\"},"
        end

        template << "\"shutdown_action\": \"terminate-hard\","

        if gate
            template << "\"ready_status_gate\": true,"
        else
            template << "\"ready_status_gate\": false,"
        end

        if hold
            template << "\"on_hold\": true,"
        end

        if automatic
            template << "\"automatic_deletion\": true"
        else
            template << "\"automatic_deletion\": false"
        end

        template << '}'

        template
    end

    ########################################################################
    # SERVER
    ########################################################################

    # Start oneflow server
    def start_flow
        config_file = "#{ONE_ETC_LOCATION}/oneflow-server.conf"
        config = YAML.load_file(config_file)

        config[:autoscaler_interval] = 30
        config[:default_cooldown]    = 15

        File.open(config_file, 'w') do |file|
            file.write(config.to_yaml)
        end

        STDOUT.print "==> Starting OneFlow server... "
        STDOUT.flush

        rc = system('oneflow-server start 2>&1 > /dev/null')

        return false if rc == false
        STDOUT.puts "done"

        wait_flow
    end

    # Stop oneflow server
    def stop_flow
        STDOUT.print "==> Stopping OneFlow server... "
        STDOUT.flush

        rc = system('oneflow-server stop 2>&1 > /dev/null')

        return false if rc == false
        STDOUT.puts "done"
    end

    # Wait until oneflow server is running
    def wait_flow
        wait_loop do
            File.exist?("#{ONE_RUN_LOCATION}/oneflow.pid")
        end
    end

end
