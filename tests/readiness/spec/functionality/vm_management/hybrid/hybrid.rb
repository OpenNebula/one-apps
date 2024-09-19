require 'init_functionality'
require 'open3'
require 'fileutils'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
ONE_LOCATION = ENV["ONE_LOCATION"] if !defined?(ONE_LOCATION)

describe "VirtualMachine into a Hybrid cloud" do

    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do

        # Only for sqlite DB backend
        if @main_defaults && @main_defaults[:db]
            unless @main_defaults[:db]['BACKEND'] == 'sqlite'
                @skip_one_stop = true
                skip 'only for sqlite DB backend'
            end
        end

        @one_location = Dir.pwd+'/one_location/'
        @local_location = '/'
        if ONE_LOCATION
            @local_location = ONE_LOCATION
        end
        @remote_env = {}
        @remote_env["ONE_LOCATION"] = @one_location
        @remote_env["ONE_XMLRPC"]='http://localhost:2634/RPC2'
        if File.directory?(@one_location)
            FileUtils.remove_dir(@one_location)
        end

        etc_location     = @one_location + "etc/"
        bin_location     = @one_location + "bin/"
        var_location     = @one_location + "var/"
        lib_location     = @one_location + "lib/"
        share_location     = @one_location + "share/"
        if !File.directory?(@one_location)
            FileUtils.mkdir(@one_location)
        end
        if !File.directory?(etc_location)
            FileUtils.mkdir(etc_location)
            FileUtils.cp_r(@local_location+'etc/one/.', etc_location)
        end
        if !File.directory?(bin_location)
             FileUtils.mkdir(bin_location)
             FileUtils.cp_r(Dir[@local_location+'usr/bin/one*'], bin_location)
             FileUtils.cp(Dir[@local_location+'usr/bin/mm_sched'], bin_location)
        end
        if !File.directory?(var_location)
            FileUtils.mkdir(var_location)
            FileUtils.mkdir("#{var_location}/lock")
            FileUtils.cp(@local_location+'var/lib/one/one.db', var_location)
            FileUtils.cp_r(@local_location+'var/lib/one/datastores', var_location)
            FileUtils.cp_r(@local_location+'var/lib/one/sunstone_vnc_tokens', var_location)
            FileUtils.cp_r(@local_location+'var/lib/one/remotes', var_location)
            FileUtils.cp_r(@local_location+'var/lib/one/vms', var_location)
            #FileUtils.cp_r(@local_location+'var/log/one/', var_location)
        end
        if !File.directory?(lib_location)
            FileUtils.mkdir(lib_location)
            FileUtils.cp_r(@local_location+'usr/lib/one/.', lib_location)
        end
        if !File.directory?(share_location)
            FileUtils.mkdir(share_location)
            `rsync -auv --delete --ignore-errors #{@local_location+'usr/share/one/'} #{share_location}`
        end

        changes = 's/PORT= "2633"/PORT= "2634"/'
        system "sed", "-i", "-e", changes, "#{etc_location}/oned.conf"

        changes = 's/localhost:2633/localhost:2634/'
        system "sed", "-i", "-e", changes, "#{etc_location}/sched.conf"

	    changes = 's/4124/4125/'
	    system "sed", "-i", "-e", changes, "#{etc_location}/monitord.conf"

        Open3.popen3(@remote_env, 'one start') { |i,o,e|
            rc = e.read()
        }

        log_file = "#{var_location}/oned.log"
        text = "Starting XML-RPC server"

        wait_loop do
            system("egrep '#{text}' #{log_file} > /dev/null")
        end

        Open3.popen3(@remote_env, 'onehost create host01 -i dummy -v dummy') { |i,o,e|
            @id_host_remote = o.read()
        }

        Open3.popen3(@remote_env, 'onetemplate create --name test --cpu 0.1 --memory 128') { |i,o,e|
            @id_remote_tmpl = o.read()
            @id_remote_tmpl.slice! "ID: "
            @id_remote_tmpl = @id_remote_tmpl.strip
        }

        template = <<-EOF
            NAME = test_remote
            CPU = 0.1
            MEMORY = 128
            PUBLIC_CLOUD = [
                TEMPLATE_ID="#{@id_remote_tmpl}",
                TYPE="opennebula" ]
            SCHED_REQUIREMENTS = "PUBLIC_CLOUD = YES"
        EOF

        host = <<-EOF
            ONE_USER = oneadmin
            ONE_PASSWORD = opennebula
            ONE_ENDPOINT = #{@remote_env['ONE_XMLRPC']}
            ONE_CAPACITY = [
                CPU = 0,
                MEMORY = 0
            ]
        EOF

        @id_host_local = cli_create("onehost create host01 -i one -v one")
        cli_update("onehost update host01", host, true)
        cli_action("onehost disable host01")
        cli_action("onehost enable host01")

        # host could be in ERROR for a sec due to created empty, skip it
        sleep 10

        wait_loop(:success => "MONITORED", :break => "ERROR") {
            xml = cli_action_xml("onehost show -x host01")
            OpenNebula::Host::HOST_STATES[xml['STATE'].to_i]
        }
        @id_template_local = cli_create('onetemplate create', template)
        @id_vm_local = cli_create("onetemplate instantiate #{@id_template_local}")
        @vm = VM.new(@id_vm_local)
        @vm.running?
        @vm.info
        @remote_id = "0"
    end

    after(:all) do
        unless @skip_one_stop
            Open3.popen3(@remote_env, 'one stop') { |i,o,e|
                rc = e.read()
            }
            if File.directory?(@one_location)
                #FileUtils.remove_dir(@one_location)
            end
        end
    end

    it "should check state of the remote Virtual Machine" do

        vm_xml = cli_action_xml("onevm show #{@id_vm_local} -x")
        #remove opennebula-hybrid-
        @remote_id = vm_xml['DEPLOY_ID']
        @remote_id["opennebula-hybrid-"] = ""
        remote_state = "BOOT"
        while remote_state != "RUNNING" do
            Open3.popen3(@remote_env, "onevm show #{@remote_id} -x") { |i,o,e|
                xml = Nokogiri::XML(o.read())
                lcm_state = xml.root.at_xpath("LCM_STATE").text
                remote_state = OpenNebula::VirtualMachine::LCM_STATE[lcm_state.to_i]
            }
        end
    end

    it "should poweroff a remote Virtual Machine" do
        @vm.safe_poweroff
        remote_state = "LCM_INIT"
        while remote_state != "POWEROFF" do
            Open3.popen3(@remote_env, "onevm show #{@remote_id} -x") { |i,o,e|
                xml = Nokogiri::XML(o.read())
                state = xml.root.at_xpath("STATE").text
                remote_state = OpenNebula::VirtualMachine::VM_STATE[state.to_i]
            }
        end
    end

    it "should resume a remote Virtual Machine" do
        cli_action("onevm resume #{@id_vm_local}")
        @vm.running?
        remote_state = "LCM_INIT"
        while remote_state != "RUNNING" do
            Open3.popen3(@remote_env, "onevm show #{@remote_id} -x") { |i,o,e|
                xml = Nokogiri::XML(o.read())
                lcm_state = xml.root.at_xpath("STATE").text
                remote_state = OpenNebula::VirtualMachine::LCM_STATE[lcm_state.to_i]
            }
        end
    end

    it "should reboot a remote Virtual Machine" do
        @vm.safe_reboot
        remote_state = "LCM_INIT"
        while remote_state != "RUNNING" do
            Open3.popen3(@remote_env, "onevm show #{@remote_id} -x") { |i,o,e|
                xml = Nokogiri::XML(o.read())
                lcm_state = xml.root.at_xpath("LCM_STATE").text
                remote_state = OpenNebula::VirtualMachine::LCM_STATE[lcm_state.to_i]
            }
        end
    end
end
