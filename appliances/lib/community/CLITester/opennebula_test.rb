# This class abstract the configuration start and stop of OpenNebula services
#
# It is based on a defaults.yaml file with the follwing options
# :oned_conf_base:  Path to oned.conf base file
# :oned_conf_extra: Path to additional settings for oned.conf for this test
# :sched_conf: Path to the sched.conf file (if not set use default)
# :monitor_conf: Path to the monitord.conf file (if not set use default)
# :nosched: Disable the scheduler for this test if defined
# :ca_cert: CA certificate
class OpenNebulaTest

    READINESS_DIR     = File.realpath(File.join(__FILE__,'../..'))
    FUNCTIONALITY_DIR = 'spec/functionality'
    ONED_CONF_BASE    = 'conf/oned.conf.xml'
    ONED_DB_CONF      = 'conf/db.conf.xml'
    ONED_CONF_EXTRA   = 'conf/oned.extra.yaml'
    SCHED_CONF_BASE   = 'conf/sched.conf'
    MONITOR_CONF_BASE = 'conf/monitord.conf'
    MONITOR_CONF_EXTRA = 'conf/monitord.extra.conf'
    SUNSTONE_EXTRA    = 'conf/sunstone_extra.yaml'

    # default stop/start commands
    CMD_PREFIX        = 'env -i - PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin'
    NOVNC_START       = "#{CMD_PREFIX} novnc-server start"
    NOVNC_STOP        = "#{CMD_PREFIX} novnc-server stop"
    SUNSTONE_START    = "#{CMD_PREFIX} sunstone-server start"
    SUNSTONE_STOP     = "#{CMD_PREFIX} sunstone-server stop"
    FIREEDGE_START    = "#{CMD_PREFIX} fireedge-server start"
    FIREEDGE_STOP     = "#{CMD_PREFIX} fireedge-server stop"

    def initialize(options={})
        @options={
            :oned_conf_base    => ONED_CONF_BASE,
            :oned_conf_extra   => ONED_CONF_EXTRA,
            :oned_db_conf      => ONED_DB_CONF,
            :monitor_conf_extra   => MONITOR_CONF_EXTRA,
            :sunstone_extra    => SUNSTONE_EXTRA,
            :functionality_dir => FUNCTIONALITY_DIR
        }.merge!(options)

        unless @options.has_key? :functionality_abs_dir
            @options[:functionality_abs_dir] = READINESS_DIR + '/' + @options[:functionality_dir] + '/'
        end

        # load oned.conf.xml
        conf      = XMLElement.new
        conf_file = @options[:functionality_abs_dir] + @options[:oned_conf_base]
        conf.initialize_xml(File.read(conf_file), 'OPENNEBULA_CONFIGURATION')

        @one_conf = conf.to_hash
        @one_conf = @one_conf['OPENNEBULA_CONFIGURATION']

        @one_conf.delete('VM_MAD')
        @one_conf.delete('IM_MAD')

        # load db.conf.xml
        db_conf_file = @options[:functionality_abs_dir] + @options[:oned_db_conf]
        if File.exist?(db_conf_file)
            begin
                db_conf = XMLElement.new
                db_conf.initialize_xml(File.read(db_conf_file), 'DB')
                db_hash = db_conf.to_hash
            rescue
                STDERR.puts "Error reading xml #{db_conf_file}, skipping"
            else
                @one_conf.delete('DB')
                @one_conf.merge!(db_hash)
            end
        end

        # make the DB section available to test (some are not applicable)
        RSpec.configuration.main_defaults[:db] = @one_conf['DB']

        # load oned.extra.yaml
        extra_file = @options[:functionality_abs_dir] + @options[:oned_conf_extra]
        extra_hash = YAML.load(File.read(extra_file))

        # load sunstone_extra.yaml
        extra_sunstone_file = @options[:functionality_abs_dir] + @options[:sunstone_extra]
        @sunstone_conf = YAML.load(File.read("#{ONE_ETC_LOCATION}/sunstone-server.conf"))
        sunstone_extra = YAML.load(File.read(extra_sunstone_file))
        @sunstone_conf.merge!(sunstone_extra)

        @sunstone_conf.delete(:tmpdir)

        # merge extra into @one_conf
        @one_conf.merge!(extra_hash) unless extra_hash.nil?
    end

    #private
    ############################################################################
    # Manage oned.conf & sched.conf
    ############################################################################
    def set_conf
        STDOUT.puts "==> Setting #{ONE_ETC_LOCATION}/oned.conf"

        fd = File.open("#{ONE_ETC_LOCATION}/oned.conf", "w")
        fd.write(to_template(@one_conf))
        fd.close

        STDOUT.puts "==> Setting #{ONE_ETC_LOCATION}/sunstone-server.conf"

        fd = File.open("#{ONE_ETC_LOCATION}/sunstone-server.conf", "w")
        fd.write(@sunstone_conf.to_yaml)
        fd.close

        STDOUT.puts "==> Setting #{ONE_ETC_LOCATION}/sched.conf"

        sched_conf = @options[:sched_conf] || SCHED_CONF_BASE

        FileUtils.cp(@options[:functionality_abs_dir] + sched_conf,
                     "#{ONE_ETC_LOCATION}/sched.conf")

        monitor_conf = @options[:monitor_conf] || MONITOR_CONF_BASE

        # put monitord.extra.conf at the begining
        FileUtils.cp(@options[:functionality_abs_dir] + @options[:monitor_conf_extra],
                    "#{ONE_ETC_LOCATION}/monitord.conf")

        system("cat #{@options[:functionality_abs_dir] + monitor_conf} " \
               ">> #{ONE_ETC_LOCATION}/monitord.conf")

        if !@options[:ca_cert].nil?
            STDOUT.puts "==> Copying CA certificate #{@options[:ca_cert]}"

            FileUtils.mkdir_p("#{ONE_ETC_LOCATION}/auth/certificates")
            FileUtils.cp(@options[:functionality_abs_dir] + @options[:ca_cert],
                         "#{ONE_ETC_LOCATION}/auth/certificates")
        end
    end

    def start_one
        STDOUT.print "==> Starting OpenNebula... "
        STDOUT.flush
        rc = system('one start')
        return false if rc == false

        wait_for_one

        STDOUT.puts "done"

        if RSpec.configuration.main_defaults[:manage_fireedge]
            start_fireedge
        end

        if RSpec.configuration.main_defaults[:manage_sunstone]
            start_sunstone
        end

        if @options[:nosched] == true
            STDOUT.print "==> Stopping Scheduler... "
            STDOUT.flush
            stop_sched

            STDOUT.puts "done"
        end

        true
    end

    def wait_for_one
        log_file = "#{ONE_LOG_LOCATION}/oned.log"
        text = "Request Manager started"

        wait_loop do
            system("egrep '#{text}' #{log_file} > /dev/null")
        end
    end

    def start_sched
        system('one start-sched 2>&1 > /dev/null')
    end

    def stop_sched
        system('one stop-sched 2>&1 > /dev/null; pkill -9 mm_sched')
    end

    def log_backup(name)
        orig = ONE_LOG_LOCATION.clone
        dst  = ONE_VAR_LOCATION == ONE_LOG_LOCATION ? '/tmp' : ONE_VAR_LOCATION + "/#{name}"

        %x(cp -rp #{orig} #{dst})
        #%x(rm -rf #{ONE_LOG_LOCATION}/*) unless ONE_VAR_LOCATION == ONE_LOG_LOCATION
    end

    def stop_one(ignore_wait_failure = true)
        STDOUT.print "==> Stopping OpenNebula... "
        STDOUT.flush
        system('one stop 2>&1 > /dev/null')
        STDOUT.puts "done"

        if RSpec.configuration.main_defaults[:manage_fireedge]
            stop_fireedge(ignore_wait_failure)
        end

        if RSpec.configuration.main_defaults[:manage_sunstone]
            stop_sunstone(ignore_wait_failure)
        end
    end

    ############################################################################
    # Functions to manage Sunstone
    ############################################################################

    def start_sunstone
        STDOUT.print "==> Starting Sunstone server... "
        STDOUT.flush

        # alternative ways how to start Sunstone
        begin
            sunstone_start_cmds = RSpec.configuration.main_defaults[:sunstone_start_commands]
        rescue StandardError => e
        ensure
            sunstone_start_cmds ||= [SUNSTONE_START]
        end

        sunstone_ready = false
        sunstone_start_cmds.each do |cmd|
            stdout_str, stderr_str, status = Open3.capture3(cmd)
            next unless status.success?

            sunstone_ready = true

            if cmd != SUNSTONE_START
                # start VNC server
                stdout_str, stderr_str, status = Open3.capture3(NOVNC_START)
                sunstone_ready = status.success?
            end

            break
        end

        return false unless sunstone_ready

        wait_for_port_open(get_sunstone_url)

        STDOUT.puts "done"
    end

    def stop_sunstone(ignore_wait_failure = true)
        STDOUT.print "==> Stopping Sunstone server... "
        STDOUT.flush

        # alternative ways how to stop Sunstone
        begin
            sunstone_stop_cmds = RSpec.configuration.main_defaults[:sunstone_stop_commands]
        rescue StandardError => e
        ensure
            sunstone_stop_cmds ||= [SUNSTONE_STOP]
        end

        if sunstone_stop_cmds.include? SUNSTONE_STOP
            if !wait_for_port_open(get_sunstone_url) && !ignore_wait_failure
              STDOUT.puts "not found, continuing."
              return
            end
        end

        sunstone_done = false
        sunstone_stop_cmds.each do |cmd|
            stdout_str, stderr_str, status = Open3.capture3(cmd)
            next unless status.success?

            if cmd == SUNSTONE_STOP
                if !stderr_str.include? "VNC server is not running"
                    wait_loop({timeout: 150}) do
                        !is_port_open?('localhost', 9869)
                    end
                end
            else
                # stop VNC server
                stdout_str, stderr_str, status = Open3.capture3(NOVNC_STOP)
                sunstone_done = status.success?
            end

            sunstone_done = true
            break
        end

        return false unless sunstone_done

        STDOUT.puts "done"
    end

    def is_port_open?(ip, port)
        begin
            Timeout::timeout(1) do
                begin
                    s = TCPSocket.new(ip, port)
                    s.close
                    return true
                rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
                    return false
                end
            end
        rescue Timeout::Error
        end

        return false
    end

    def get_sunstone_url
        # respect alternative Sunstone URL if specified
        # in the microenv's defaults.yaml
        begin
            url = RSpec.configuration.main_defaults[:sunstone_url]
        rescue StandardError => e
        ensure
            url ||= 'http://localhost:9869'
        end

        fail 'Error: Bad URI for sunstone' if !valid_url?(url)

        return url
    end

    def valid_url?(url)
        uri = URI.parse(url)
        (uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)) && !uri.host.nil? && !uri.port.nil?
    rescue URI::InvalidURIError
        false
    end

    def wait_for_port_open(url)
        uri = URI.parse(url)
        host = uri.host
        port = uri.port

        (0..10).each{
            sleep 1
            return if is_port_open?(host, port)
        }

        return false
    end

    ############################################################################
    # Functions to manage FireEdge
    ############################################################################

    def start_fireedge
        STDOUT.print "==> Starting FireEdge server... "
        STDOUT.flush

        # alternative ways how to start FireEdge
        begin
            fireedge_start_cmds = RSpec.configuration.main_defaults[:fireedge_start_commands]
        rescue StandardError => e
        ensure
            fireedge_start_cmds ||= [FIREEDGE_START]
        end

        fireedge_ready = false
        fireedge_start_cmds.each do |cmd|
            stdout_str, stderr_str, status = Open3.capture3(cmd)

            if status.success?
                fireedge_ready = true
                break
            end
        end

        return false unless fireedge_ready

        wait_for_port_open(get_fireedge_url)

        STDOUT.puts "done"
    end

    def stop_fireedge(ignore_wait_failure = true)
        STDOUT.print "==> Stopping FireEdge server... "
        STDOUT.flush

        # alternative ways how to stop FireEdge
        begin
            fireedge_stop_cmds = RSpec.configuration.main_defaults[:fireedge_stop_commands]
        rescue StandardError => e
        ensure
            fireedge_stop_cmds ||= [FIREEDGE_STOP]
        end

        if fireedge_stop_cmds.include? FIREEDGE_STOP
            if !wait_for_port_open(get_fireedge_url) && !ignore_wait_failure
              STDOUT.puts "not found, continuing."
              return
            end
        end

        fireedge_done = false
        fireedge_stop_cmds.each do |cmd|
            stdout_str, stderr_str, status = Open3.capture3(cmd)
            next unless status.success?

            fireedge_done = true
            break
        end

        return false unless fireedge_done

        STDOUT.puts "done"
    end

    def get_fireedge_url
        # respect alternative FireEdge URL if specified
        # in the microenv's defaults.yaml
        begin
            url = RSpec.configuration.main_defaults[:fireedge_url]
        rescue StandardError => e
        ensure
            url ||= 'http://localhost:2616'
        end

        fail 'Error: Bad URI for FireEdge' if !valid_url?(url)

        return url
    end

    ############################################################################
    # Functions to manage OpenNebula database
    ############################################################################
    def clean_db
        case @one_conf['DB']['BACKEND']
        when 'sqlite'
            STDOUT.puts "==> Cleaning sqlite DB"
            clean_sqlite_db
        when 'mysql'
            STDOUT.puts "==> Cleaning mysql DB"
            clean_mysql_db
        else
            STDERR.puts "==> Unknown DB backend"
        end
    end

    def is_sqlite?
        @one_conf['DB']['BACKEND'] == 'sqlite'
    end

    def clean_mysql_db
        user   = @one_conf['DB']['USER']
        pass   = @one_conf['DB']['PASSWD']

        dbname = @one_conf['DB']['DB_NAME']

        cmd_str = "mysqladmin -f -p drop #{dbname} -u #{user} -p#{pass}"

        system(cmd_str)

        # Reset query cache otherwise new mysql (8.0.30) is unpredictable
        system('sudo mysql -e "RESET QUERY CACHE"')
    end

    def clean_sqlite_db
        cmd_str = "rm -f #{ONE_VAR_LOCATION}/one.db > /dev/null 2>&1"

        system(cmd_str)
    end

    def backup_db
        case @one_conf['DB']['BACKEND']
        when 'sqlite'
            STDOUT.puts "==> Doing backup sqlite DB"

            cmd_str = "onedb backup -s #{ONE_VAR_LOCATION}/one.db"
        when /^mysql$/
            STDOUT.puts "==> Doing backup mysql/psql DB"

            user   = @one_conf['DB']['USER']
            pass   = @one_conf['DB']['PASSWD']

            dbname = @one_conf['DB']['DB_NAME']

            cmd_str = "onedb backup -u #{user} -p #{pass} -d #{dbname}"
        else
            STDERR.puts "==> Unknown DB backend"
            return false
        end

        backup_file = ""
        IO.popen(cmd_str) do |return_str|
            out = return_str.read
            backup_file = out[/stored in (.*?)\nUse/m, 1]
        end

        return backup_file
    end

    def restore_db(backup_file)
        case @one_conf['DB']['BACKEND']
        when 'sqlite'
            STDOUT.puts "==> Restoring sqlite DB"

            cmd_str = "onedb restore -f -s #{ONE_VAR_LOCATION}/one.db #{backup_file}"

            system(cmd_str)
        when /^mysql$/
            STDOUT.puts "==> Restoring mysql/psql DB"

            user   = @one_conf['DB']['USER']
            pass   = @one_conf['DB']['PASSWD']

            dbname = @one_conf['DB']['DB_NAME']

            cmd_str = "onedb restore -f -u #{user} -p #{pass} -d #{dbname} #{backup_file}"

            system(cmd_str)
        else
            STDERR.puts "==> Unknown DB backend"
        end
    end

    def upgrade_db
        case @one_conf['DB']['BACKEND']
        when 'sqlite'
            STDOUT.puts "==> Doing upgrade sqlite DB"

            cmd_str = "onedb upgrade -v --no-backup -s #{ONE_VAR_LOCATION}/one.db"
        when /^mysql$/
            STDOUT.puts "==> Doing upgrade mysql/psql DB"

            user   = @one_conf['DB']['USER']
            pass   = @one_conf['DB']['PASSWD']

            dbname = @one_conf['DB']['DB_NAME']

            cmd_str = "onedb upgrade -v --no-backup -u #{user} -p #{pass} -d #{dbname}"
        else
            STDERR.puts "==> Unknown DB backend"
            return false
        end

        system(cmd_str)
    end

    def version_db
        case @one_conf['DB']['BACKEND']
        when 'sqlite'
            STDOUT.puts "==> Getting version sqlite DB"

            cmd_str = "onedb version -s #{ONE_VAR_LOCATION}/one.db"
        when /^mysql$/
            STDOUT.puts "==> Getting version mysql/psql DB"

            user   = @one_conf['DB']['USER']
            pass   = @one_conf['DB']['PASSWD']

            dbname = @one_conf['DB']['DB_NAME']

            cmd_str = "onedb version -u #{user} -p #{pass} -d #{dbname}"
        else
            STDERR.puts "==> Unknown DB backend"
            return false
        end

        out = ""
        IO.popen(cmd_str) do |return_str|
            out = return_str.read
        end

        return out[/Shared: (.*?)\n/m, 1], out[/Local: (.*?)\n/m, 1]
    end

    ############################################################################
    # Functions to manage OpenNebula var state
    ############################################################################
    def clean_var
        STDOUT.puts "==> Cleaning #{ONE_VAR_LOCATION}"

        3.times do |i|
            ds_dir = "#{ONE_VAR_LOCATION}/datastores/#{i}"
            rm_cmd = "find #{ds_dir} -mindepth 1 -delete > /dev/null 2>&1"

            system(rm_cmd)
        end

        rm_cmd = "find #{ONE_VAR_LOCATION}/datastores/10* -maxdepth 0 "\
            "-exec rm -rf \{\} + > /dev/null 2>&1"
        system(rm_cmd)

        rm_cmd = "rm -rf #{ONE_VAR_LOCATION}/vms/* > /dev/null 2>&1"
        system(rm_cmd)

        rm_cmd ="find #{ONE_VAR_LOCATION}/.one -type f ! -name 'one_auth' -delete 2>&1"
        system(rm_cmd)
    end

    def clean_oned_log
        # Wait for oned to shut down
        system("mv #{ONE_LOG_LOCATION}/oned.log #{ONE_LOG_LOCATION}/oned-sunstonetests.log")
    end

    ############################################################################
    # This functions writes a hash to a string using OpenNebula Template syntax
    ############################################################################
    def render_template_value(str, value)
        if value.class == Hash
            str << "=[\n"

            str << value.collect do |k, v|
                next if !v || v.empty?

                '    ' + k.to_s.upcase + '=' + "\"#{v.to_s}\""
            end.compact.join(",\n")

            str << "\n]\n"
        elsif value.class == String
            str << "= \"#{value.to_s}\"\n"
        end
    end

    def to_template(attributes)
        str = attributes.collect do |key, value|
            next if !value || value.empty?

            str_line=""

            if value.class==Array
                value.each do |v|
                    str_line << key.to_s.upcase
                    render_template_value(str_line, v)
                end
            else
                str_line << key.to_s.upcase
                render_template_value(str_line, value)
            end

            str_line
        end.compact.join('')

        str
    end
end
