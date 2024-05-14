# frozen_string_literal: true

require 'base64'
require 'fileutils'
require 'ipaddr'
require 'json'
require 'logger'
require 'open3'
require 'socket'

LOGGER_STDOUT = Logger.new(STDOUT)
LOGGER_STDERR = Logger.new(STDERR)

LOGGERS = {
    info:  LOGGER_STDOUT.method(:info),
    debug: LOGGER_STDERR.method(:debug),
    warn:  LOGGER_STDERR.method(:warn),
    error: LOGGER_STDERR.method(:error)
}.freeze

def msg(level, string)
    LOGGERS[level].call string
end

def env(name, default)
    value = ENV.fetch name.to_s, ''
    value = value.empty? ? default : value
    value = %w[YES 1].include?(value.upcase) if default.instance_of?(String) && %w[YES NO].include?(default.upcase)
    value
end

def load_env(path = '/run/one-context/one_env')
    replacements = {
        "\n" => '\n'
    }.tap do |h|
        h.default_proc = ->(h, k) { k }
    end

    # NOTE: We must allow literal newline characters in values as
    #       OpenNebula separates multiple ssh-rsa entries with
    #       literal newlines!
    folded = Enumerator.new do |y|
        cached = []

        yield_prev_line = -> do
            unless cached.empty?
                y << cached.join.gsub(/./m, replacements)
                cached = []
            end
        end

        File.read(path).lines.each do |line|
            yield_prev_line.call if line =~ /^export [^=]+="/
            cached << line
        end

        yield_prev_line.call
    end

    folded.each do |line|
        # Everything to the right of the last " is discarded!
        next unless line =~ /^export ([^=]+)=(".*")[^"]*$/

        ENV[$1] = $2.undump
    end
end

def slurp(path)
    Base64.encode64(File.read(path)).lines.map(&:strip).join
end

def file(path, content, owner: nil, group: nil, mode: 'u=rw,go=r', overwrite: false)
    return if !overwrite && File.exist?(path)

    FileUtils.mkdir_p File.dirname path

    File.write path, content

    FileUtils.chown owner, group, path unless owner.nil? || group.nil?

    FileUtils.chmod mode, path
end

def bash(script, chomp: false, terminate: false)
    command = 'exec /bin/bash --login -s'

    stdin_data = <<~SCRIPT
    set -o errexit -o nounset -o pipefail
    set -x
    #{script}
    SCRIPT

    stdout, stderr, status = Open3.capture3 command, stdin_data: stdin_data
    unless status.exitstatus.zero?
        error_message = "#{status.exitstatus}: #{stderr}"
        msg :error, error_message

        raise error_message unless terminate

        exit status.exitstatus
    end

    chomp ? stdout.chomp : stdout
end

def ipv4?(string)
    string.is_a?(String) && IPAddr.new(string) ? true : false
rescue IPAddr::InvalidAddressError
    false
end

def integer?(string)
    Integer(string) ? true : false
rescue ArgumentError
    false
end

alias port? integer?

def tcp_port_open?(ipv4, port, seconds = 5)
    # > If a block is given, the block is called with the socket.
    # > The value of the block is returned.
    # > The socket is closed when this method returns.
    Socket.tcp(ipv4, port, connect_timeout: seconds) {}
    true
rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ETIMEDOUT
    false
end

def hashmap
    def recurse(a, b, g)
        return a.method(g.next).call(b) { |_, a, b| recurse(a, b, g) } if a.is_a?(Hash) && b.is_a?(Hash)
        return b
    end

    # USAGE: c = hashmap.combine a, b
    def combine(a, b)
        recurse(a, b, Enumerator.new { |y| loop { y << :merge } })
    end

    # USAGE: hashmap.combine! a, b
    def combine!(a, b)
        recurse(a, b, Enumerator.new { |y| y << :merge!; loop { y << :merge } })
    end
end

def sortkeys
    def apply(method, keys, pattern)
        k_unsorted = keys.select do |k|
            k =~ pattern
        end

        k_sorted = k_unsorted.sort_by do |k|
            k =~ pattern
            Gem::Version.new $~[1..(-1)].join(%[.])
        end

        k_map = k_unsorted.zip(k_sorted).to_h

        keys.method(method).call do |x|
            (y = k_map[x]).nil? ? x : y
        end
    end

    def as_version(keys, pattern: /^(\d+)[.](\d+)[.](\d+)$/)
        apply :map, keys, pattern
    end

    def as_version!(keys, pattern: /^(\d+)[.](\d+)[.](\d+)$/)
        apply :map!, keys, pattern
    end
end

def sorted_deps(deps)
    # NOTE: This doesn't handle circular dependencies.

    # Work with string keys only.
    d = deps.to_h { |k, v| [k.to_s, v.map(&:to_s)] }

    def recurse(d, x, level = 0)
        # The distance is at least the same as the current level.
        distance = level

        # Recurse down each branch and record the longest distance to the root.
        d[x].each { |y| distance = [distance, recurse(d, y, level + 1)].max }

        distance
    end

    deps.keys.map { |k| [k, recurse(d, k.to_s)] } # compute the longest distance
             .sort_by(&:last)                     # sort by the distance
             .map(&:first)                        # return sorted keys (original)
end

# install|configure|bootstrap started|success|failure
def set_motd(step, status, path = '/etc/motd')
    header_txt = <<~'HEADER'
    .
       ___   _ __    ___
      / _ \ | '_ \  / _ \   OpenNebula Service Appliance
     | (_) || | | ||  __/
      \___/ |_| |_| \___|

    HEADER

    step_txt = \
        case step.to_sym
        when :install   then '1/3 Installation'
        when :configure then '2/3 Configuration'
        when :bootstrap then '3/3 Bootstrap'
        end

    status_txt = \
        case status.to_sym
        when :started then <<~STARTED
        #{header_txt}
         #{step_txt} step is in progress...

         * * * * * * * *
         * PLEASE WAIT *
         * * * * * * * *

        STARTED
        when :success then if step.to_sym == :bootstrap
            <<~SUCCESS
            #{header_txt}
             All set and ready to serve 8)

            SUCCESS
        else
            <<~SUCCESS
            #{header_txt}
             #{step_txt} step was successfull.

            SUCCESS
        end
        when :failure then <<~FAILURE
        #{header_txt}
         #{step_txt} step failed.

         * * * * * * * * * *
         * APPLIANCE ERROR *
         * * * * * * * * * *

         Read documentation and try to redeploy!

        FAILURE
        end

    file path, status_txt.delete_prefix('.'), mode: 'u=rw,go=r', overwrite: true
end

# install|configure|bootstrap|success|failure
def set_status(status, path = '/etc/one-appliance/status')
    case status.to_sym
    when :install, :configure, :bootstrap
        file path, <<~STATUS, mode: 'u=rw,go=r', overwrite: true
            #{status.to_s}_started
        STATUS
        set_motd status, :started
    when :success, :failure
        step = File.open(path, &:gets).strip.split('_').first
        file path, <<~STATUS, mode: 'u=rw,go=r', overwrite: true
            #{step}_#{status.to_s}
        STATUS
        set_motd step, status
    end
end
