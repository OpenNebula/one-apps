module CLITester

    # methods

    require 'json'
    require 'tempfile'
    require 'timeout'
    require 'open3'

    ONE_LOCATION = ENV['ONE_LOCATION'] unless defined?(ONE_LOCATION)

    if !ONE_LOCATION
        ONE_VAR_LOCATION = '/var/lib/one' unless defined?(ONE_VAR_LOCATION)
        ONE_LOG_LOCATION = '/var/log/one' unless defined?(ONE_LOG_LOCATION)
    else
        ONE_VAR_LOCATION = ONE_LOCATION + '/var' unless defined?(ONE_VAR_LOCATION)
        ONE_LOG_LOCATION = ONE_VAR_LOCATION unless defined?(ONE_LOG_LOCATION)
    end

    DEFAULT_TIMEOUT = 180
    DEFAULT_EXEC_TIMEOUT = 200

    DO_FSCK = true

    VM_SSH_OPTS='-o StrictHostKeyChecking=no ' <<
                '-o UserKnownHostsFile=/dev/null ' <<
                '-o ConnectTimeout=90 ' <<
                '-o BatchMode=yes ' <<
                '-o PasswordAuthentication=no ' <<
                '-o ServerAliveInterval=3 ' <<
                '-o ControlMaster=auto ' <<
                '-o ControlPersist=15 ' <<
                '-o ControlPath=~/.ssh-rspec-%C '

    HOST_SSH_OPTS='-o PasswordAuthentication=no'

    DEFAULT_PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'

    REMOTE_FRONTEND = ENV['REMOTE_FRONTEND'] unless defined?(REMOTE_FRONTEND)

    if REMOTE_FRONTEND
        m = REMOTE_FRONTEND.match(%r{^(?<proto>docker|ssh)://(?<frontend_name>.*)})
        raise 'Malformed REMOTE_FRONTEND' if m.nil?

        case m[:proto]
        when 'docker'
            exec = "docker exec -u oneadmin -i #{m[:frontend_name]}"

            o, e, s = Open3.capture3("#{exec} cat /etc/profile.d/opennebula.sh")
            if s.success?
                env = Tempfile.new('docker-env')
                env << o.gsub(/^export /, '').gsub(/=['"]/, '=').gsub(/['"]$/, '')
                env.close

                # "persist" the temporary file
                FileUtils.cp(env.path, "#{env.path}.env")

                exec = "docker exec -u oneadmin -i --env-file=#{env.path}.env #{m[:frontend_name]}"
            end

            REMOTE_TYPE = 'docker'
            REMOTE_EXEC = exec
            REMOTE_COPY = :docker_copy
        when 'ssh'
            raise 'Not yet implemented REMOTE_FRONTEND protocol: ssh'
        else
            raise "Not supported REMOTE_FRONTEND protocol: #{m[:proto]}"
        end
    end

    def docker_copy(path)
        SafeExec.run("tar -C $(dirname #{path}) $(basename #{path}) -cf - " +
                      "| #{REMOTE_EXEC} tar -C $(dirname #{path}) -xf -")
    end

    def pre_cli_action_docker(action_string)
        # Detect local files and copy them to frontend container
        action_string.split[1..-1].each do |arg|
            file = arg.strip

            next unless File.exist?(file)

            cmd = SafeExec.run("#{REMOTE_EXEC} stat #{file} 2>/dev/null")

            # We don't copy files, which already exist on remote
            # (e.g., it could replace remote datastores with local)
            method(REMOTE_COPY).call(file) if cmd.fail?
        end
    end

    def pre_cli_action(action_string)
        if REMOTE_FRONTEND && REMOTE_TYPE == 'docker'
            pre_cli_action_docker(action_string)
            action_string = %(#{REMOTE_EXEC} #{action_string})
        end

        action_string
    end

    def cli_action(action_string, expected_result = true, may_fail = false)
        action_string = pre_cli_action(action_string)

        cmd = SafeExec.run(action_string)
        if cmd.fail? && !may_fail
            puts cmd.stdout
            puts cmd.stderr
        end

        if !expected_result.nil?
            expect(cmd.success?).to be(expected_result),
                                    "This command didn't #{expected_result ? 'succeed' : 'fail'} as expected:\n"<<
                                    "  #{action_string}\n" <<
                                    "#{cmd.stdout.nil? ? '' : '  ' + cmd.stdout}"<<
                                    "#{cmd.stderr.nil? ? '' : '  ' + cmd.stderr}"
        end

        cmd
    end

    def cli_action_timeout(action_string, expected_result = true, timeout = nil)
        action_string = pre_cli_action(action_string)

        if !timeout
            cmd = SafeExec.run(action_string)
        else
            cmd = SafeExec.run(action_string, timeout.to_i)
        end

        if cmd.fail?
            puts cmd.stdout
            puts cmd.stderr
        end

        if !expected_result.nil?
            expect(cmd.success?).to be(expected_result),
                                    "This command didn't #{expected_result ? 'succeed' : 'fail'} as expected:\n"<<
                                    "  #{action_string}\n" <<
                                    "#{cmd.stdout.nil? ? '' : '  ' + cmd.stdout}"<<
                                    "#{cmd.stderr.nil? ? '' : '  ' + cmd.stderr}"
        end

        cmd
    end

    def cli_create(action_string, template = nil, expected_result = true)
        if !template.nil?
            file = Tempfile.new('functionality')
            file << template
            file.flush
            file.close
            method(REMOTE_COPY).call file.path if REMOTE_FRONTEND

            action_string += " #{file.path}"
        end

        cmd = cli_action(action_string, expected_result)

        if expected_result == false
            return cmd
        end

        regexp_resource_id = /^(\w+ )*ID: (\d+)/
        expect(cmd.stdout).to match(regexp_resource_id)
        m = cmd.stdout.match(regexp_resource_id)
        m[-1].to_i
    end

    #
    # Pass the template via STDIN to the CLI creation command. The command must support STDIN.
    #
    # @param [String] cmd ID returning command
    # @param [String] template Template to be passed via STDIN
    # @param [Bool] expected_result Whether the command should succeed or fail
    #
    # @return [Int/False] ID of the created OpenNebula object. False if expected to fail
    #
    def cli_create_stdin(cmd, template, expected_result = true)
        template = template.gsub('$', '\\$') if template.include?('$')
        cmd = <<~BASH
            #{cmd} <<EOF
            #{template}
            EOF
        BASH

        cmd = cli_action(cmd, expected_result)

        return cmd if expected_result == false

        regexp_resource_id = /^(\w+ )*ID: (\d+)/
        expect(cmd.stdout).to match(regexp_resource_id)
        m = cmd.stdout.match(regexp_resource_id)
        m[-1].to_i
    end

    def cli_create_lite(action_string)
        cmd = cli_action(action_string, nil)

        m = cmd.stdout.match(/^(\w+ )*ID: (\d+)/)

        m[-1].to_i
    end

    def cli_update(action_string, template, append, expected_result = true)
        action_string += ' --append' if append

        file = Tempfile.new('functionality')
        file << template
        file.flush
        file.close
        method(REMOTE_COPY).call file.path if REMOTE_FRONTEND

        action_string += " #{file.path}"

        cli_action(action_string, expected_result)
    end

    def cli_update_stdin(cmd, template, append, expected_result = true)
        cmd += ' --append' if append

        template = template.gsub('$', '\\$') if template.include?('$')
        cmd = <<~BASH
            #{cmd} <<EOF
            #{template}
            EOF
        BASH

        cli_action(cmd, expected_result)
    end

    def cli_action_xml(action_string, expected_result = true)
        cmd = cli_action(action_string, expected_result)

        m = cmd.stdout.match(/^<(\w+)>/)
        root_element = m[1]

        elem = XMLElement.new
        elem.initialize_xml(cmd.stdout, root_element)
        elem
    end

    def cli_action_json(action_string, expected_result = true)
        cmd = cli_action(action_string, expected_result)
        JSON.parse(cmd.stdout)
    end

    def wait_loop(options = {}, &block)
        args = {
            :timeout => DEFAULT_TIMEOUT,
            :success => true
        }.merge!(options)

        timeout    = args[:timeout]
        success    = args[:success]
        break_cond = args[:break]

        timeout_reached = nil
        v = nil
        t_start = Time.now

        while Time.now - t_start < timeout
            v = block.call

            if break_cond
                if break_cond.instance_of? Regexp
                    if args[:resource_ref].nil?
                        expect(v).to_not match(break_cond)
                    else
                        expect(v).to_not match(break_cond),
                                         "expected #{v} not to match /#{break_cond.source}/ #{args[:resource_type].nil? ? '' : args[:resource_type]}(#{args[:resource_ref]})"
                    end
                else
                    if args[:resource_ref].nil?
                        expect(v).to_not eq(break_cond)
                    else
                        expect(v).to_not eq(break_cond),
                                         "expected: value != #{v}\ngot: #{break_cond}\n\n(compared using ==)\n#{args[:resource_type].nil? ? '' : args[:resource_type]}(#{args[:resource_ref]})"
                    end
                end
            end

            if success.instance_of? Regexp
                result = success.match(v)
            else
                result = v == success
            end

            if result
                timeout_reached = false
                return v
            else
                sleep 1
            end
        end

        pp "Waited #{Time.now - t_start}"

        if timeout_reached != false
            FileUtils.mkdir_p "#{ONE_VAR_LOCATION}/wait_loop/"
            timestamp = Time.now.strftime('%Y%m%d-%H%M')
            hosts_xml = cli_action('onehost list -x', expected_result = nil)
            vms_xml = cli_action('onevm list -x', expected_result = nil)
            File.open("#{ONE_VAR_LOCATION}/wait_loop/wait_hook_onehost-#{timestamp}-stdout.debug",
                      'w') do |f|
                f.write("#{hosts_xml.stdout}\n")
            end
            File.open("#{ONE_VAR_LOCATION}/wait_loop/wait_hook_onehost-#{timestamp}-stderr.debug",
                      'w') do |f|
                f.write("#{hosts_xml.stderr}\n")
            end
            File.open("#{ONE_VAR_LOCATION}/wait_loop/wait_hook_onehost-#{timestamp}-status.debug",
                      'w') do |f|
                f.write("#{hosts_xml.status}\n")
            end
            File.open("#{ONE_VAR_LOCATION}/wait_loop/wait_hook_onevm-#{timestamp}-stdout.debug",
                      'w') do |f|
                f.write("#{vms_xml.stdout}\n")
            end
            File.open("#{ONE_VAR_LOCATION}/wait_loop/wait_hook_onevm-#{timestamp}-stderr.debug",
                      'w') do |f|
                f.write("#{vms_xml.stderr}\n")
            end
            File.open("#{ONE_VAR_LOCATION}/wait_loop/wait_hook_onevm-#{timestamp}-status.debug",
                      'w') do |f|
                f.write("#{vms_xml.status}\n")
            end
        end

        expect(timeout_reached).to be(false),
                                   "reached timeout, last state was #{v} #{args[:resource_type].nil? ? '' : args[:resource_type]}#{args[:resource_ref].nil? ? '' : '(' + args[:resource_ref].to_s + ')'} while expected #{success}"
        expect(v).to be_truthy
    end

    ################################################################################
    # User related helpers
    ################################################################################

    ##
    # Execute the commands inside the block as the specified user. The user had to be
    # created using the cli_create_user helper
    #
    # @example
    #   as_user(new_user) {
    #       cli_action("onedatastore delete 12345")
    #   }
    #
    # @param [String] username
    def as_user(username, &block)
        previous_auth   = ENV['ONE_AUTH'] || ENV['HOME'] + '/.one/one_auth'
        ENV['ONE_AUTH'] = ENV["#{username.upcase}_AUTH"]
        begin
            block.call
        ensure
            ENV['ONE_AUTH'] = previous_auth
        end
    end

    ##
    # Execute the commands inside the block as the specified user using a token.
    #
    # @example
    #   as_user_token(user, token) {
    #       cli_action("onedatastore delete 12345")
    #   }
    #
    # @param [String] username
    # @param [String] token
    def as_user_token(username, token, &block)
        previous_auth = ENV['ONE_AUTH'] || ENV['HOME'] + '/.one/one_auth'

        auth_file = File.open("/tmp/auth_#{username}_#{token}", 'w', 0o644)
        auth_file.write("#{username}:#{token}")
        auth_file.close

        ENV['ONE_AUTH'] = "/tmp/auth_#{username}_#{token}"

        begin
            block.call
        ensure
            ENV['ONE_AUTH'] = previous_auth
        end
    end

    # Create a new user and define an environment variable pointing to his auth_file
    #
    # @example
    #   cli_create_user(username, userpassword)
    #
    # @param [String] username
    # @param [String] password
    def cli_create_user(username, password)
        id = cli_create("oneuser create #{username} #{password}")

        auth_file = File.open("/tmp/auth_#{username}", 'w', 0o644)
        auth_file.write("#{username}:#{password}")
        auth_file.close

        ENV["#{username.upcase}_AUTH"] = "/tmp/auth_#{username}"

        id
    end

    def wait_app_ready(timeout, app)
        ready_state = '1'
        error_state = '3'
        wait_loop(:success => ready_state, :break => error_state, :timeout => timeout,
                  :resource_ref => app) do
            xml = cli_action_xml("onemarketapp show -x #{app}", nil) rescue nil
            xml['STATE'] unless xml.nil?
        end
    end

    def wait_service_ready(timeout, service)
        ready_state = '2' # RUNNING
        error_state = '7' # FAILED_DEPLOYING
        wait_loop(:success => ready_state, :break => error_state, :timeout => timeout,
                  :resource_ref => service) do
            json = cli_action_json("oneflow show -j '#{service}'", nil) rescue nil
            json.dig('DOCUMENT', 'TEMPLATE', 'BODY', 'state').to_s unless json.nil?
        end
    end

    def wait_image_ready(timeout, image)
        wait_loop(:success => 'READY', :break => 'ERROR', :timeout => timeout,
                  :resource_ref => image) do
            xml = cli_action_xml("oneimage show -x #{image}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        end
    end

    def get_hook_exec(hook_name, next_exec = true)
        xpath     = '/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD/EXECUTION_ID'
        hook_xml  = cli_action_xml("onehook show #{hook_name} -x")
        last_exec = hook_xml.retrieve_elements(xpath)
        ret       = -1

        ret = last_exec[-1].to_i unless last_exec.nil?

        ret += 1 if next_exec

        ret
    end

    def wait_hook(hook_name, last_exec)
        wait_loop do
            hook_xml = cli_action_xml("onehook show #{hook_name} -x")
            c_exec   = get_hook_exec(hook_name, false)
            xpath_rc = "/HOOK/HOOKLOG/HOOK_EXECUTION_RECORD[EXECUTION_ID=#{c_exec}]//CODE"

            if c_exec == last_exec
                break true if hook_xml && hook_xml[xpath_rc] == '0'

                break false

            end
        end
    end

    def debug_action(action_string, info, file = '/tmp/tester_debug')
        action_string = pre_cli_action(action_string)

        cmd = SafeExec.run(action_string)

        File.open(file,
                  'a') do |f|
            f << "============================================================================================================\n"
            f << action_string + ' - ' + info
            f << "\n\n"
            f << cmd.stdout
            f << "============================================================================================================\n"
        end
    end

    def run_fsck(errors = 0, restart = true, dry = false)
        return unless DO_FSCK

        @one_test.stop_one

        wait_loop do
            !File.exist?('/var/lock/one/one')
        end

        fsck = ''
        if @one_test.is_sqlite?
            fsck = "onedb fsck -v -f --sqlite #{ONE_DB_LOCATION}/one.db"
        else
            backend= @main_defaults[:db]['BACKEND']
            user   = @main_defaults[:db]['USER']
            pass   = @main_defaults[:db]['PASSWD']
            dbname = @main_defaults[:db]['DB_NAME']

            fsck = "onedb fsck -v -f -t #{backend} -u #{user} -p #{pass} -d #{dbname}"
        end

        fsck += ' --dry' if dry

        cmd = cli_action(fsck)

        @one_test.start_one if restart

        expect(cmd.stdout).to match(/Total errors found: #{errors}/)
    end

    # end module CLITester

end
