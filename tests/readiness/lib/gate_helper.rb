module GateHelper

require 'openssl'
require 'base64'

CIPHER = "aes-256-cbc"

########################################################################
# HELPERS
########################################################################

def gen_token(vm_xml, token_password)
    cipher = OpenSSL::Cipher.new(CIPHER)

    cipher.encrypt
    cipher.key = token_password[0..31]

    rc =  cipher.update("#{vm_xml['ID']}:#{vm_xml['STIME']}")
    rc << cipher.final

    return Base64::strict_encode64(rc)
end

########################################################################
# SERVER
########################################################################

# Start oneflow server
def start_gate
    config_file = "#{ONE_ETC_LOCATION}/onegate-server.conf"
    config = YAML.load_file(config_file)

    # Enable permissions for vrouter show
    if config[:permissions][:vrouter].nil?
        config[:permissions][:vrouter] = {
            :show => true
        }
    end

    # Enable permissions for vnet show
    if config[:permissions][:vnet].nil?
        config[:permissions][:vnet] = {
            :show_by_id => true
        }
    end

    config[:host] = '0.0.0.0'

    File.open(config_file, 'w') do |file|
        file.write(config.to_yaml)
    end

    STDOUT.print "==> Starting OneGate server... "
    STDOUT.flush

    rc = system('onegate-server start 2>&1 > /dev/null')

    return false if rc == false
    STDOUT.puts "done"

    wait_gate

    config
end

# Stop oneflow server
def stop_gate
    STDOUT.print "==> Stopping OneGate server... "
    STDOUT.flush

    rc = system('onegate-server stop 2>&1 > /dev/null')

    return false if rc == false
    STDOUT.puts "done"
end

# Wait until oneflow server is running
def wait_gate
    pid_file = if ONE_LOCATION
        "#{ONE_VAR_LOCATION}/onegate.pid"
    else
        '/var/run/one/onegate.pid'
    end

    loop do
        break if File.exist?(pid_file)
    end
end

########################################################################
# CLIENT
########################################################################

class Client
    def initialize(opts={})
        @vmid  = opts[:vm_id]
        @token = opts[:token]
        @host  = opts[:host]
        @port  = opts[:port]

        url = opts[:url]
        @uri = URI.parse(url)

        @user_agent = "OpenNebula"
    end

    def get(path, extra = nil)
        req = Net::HTTP::Proxy(@host, @port)::Get.new(path)
        req.body = extra if extra

        do_request(req)
    end

    def delete(path)
        req =Net::HTTP::Proxy(@host, @port)::Delete.new(path)

        do_request(req)
    end

    def post(path, body)
        req = Net::HTTP::Proxy(@host, @port)::Post.new(path)
        req.body = body

        do_request(req)
    end

    def put(path, body)
        req = Net::HTTP::Proxy(@host, @port)::Put.new(path)
        req.body = body

        do_request(req)
    end

    def login
        req = Net::HTTP::Proxy(@host, @port)::Post.new('/login')

        do_request(req)
    end

    def logout
        req = Net::HTTP::Proxy(@host, @port)::Post.new('/logout')

        do_request(req)
    end

    private

    def do_request(req)
        req.basic_auth @username, @password

        req['User-Agent'] = @user_agent
        req['X-ONEGATE-TOKEN'] = @token
        req['X-ONEGATE-VMID'] = @vmid

        http = Net::HTTP::Proxy().new(@uri.host, @uri.port)
        http.read_timeout = 15

        begin
            res = http.start do |connection|
                http.request(req)
            end
        rescue Exception => e
            str =  "Error connecting to server (#{e.to_s}).\n"
            str << "Server: #{@uri.host}:#{@uri.port}"

            return Error.new(str)
        end

        res
    end

    # #########################################################################
    # The Error Class represents a generic error in the Cloud Client
    # library. It contains a readable representation of the error.
    # #########################################################################
    class Error
        attr_reader :message

        # +message+ a description of the error
        def initialize(message=nil)
            @message=message
        end

        def to_s()
            @message
        end
    end

    # #########################################################################
    # Returns true if the object returned by a method of the OpenNebula
    # library is an Error
    # #########################################################################
    def self.is_error?(value)
        value.class==CloudClient::Error
    end

end

end