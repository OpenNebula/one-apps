# frozen_string_literal: true

require 'erb'
require_relative '../vrouter.rb'

module Service
module DNS
    extend self

    DEPENDS_ON = %w[Service::Failover]

    ONEAPP_VNF_DNS_ENABLED      = env :ONEAPP_VNF_DNS_ENABLED, 'NO'
    ONEAPP_VNF_DNS_TCP_DISABLED = env :ONEAPP_VNF_DNS_TCP_DISABLED, 'NO'
    ONEAPP_VNF_DNS_UDP_DISABLED = env :ONEAPP_VNF_DNS_UDP_DISABLED, 'NO'

    ONEAPP_VNF_DNS_UPSTREAM_TIMEOUT = env :ONEAPP_VNF_DNS_UPSTREAM_TIMEOUT, 1128
    ONEAPP_VNF_DNS_MAX_CACHE_TTL    = env :ONEAPP_VNF_DNS_MAX_CACHE_TTL, 3600

    ONEAPP_VNF_DNS_USE_ROOTSERVERS = env :ONEAPP_VNF_DNS_USE_ROOTSERVERS, 'YES'
    ONEAPP_VNF_DNS_NAMESERVERS     = env :ONEAPP_VNF_DNS_NAMESERVERS, ''

    ONEAPP_VNF_DNS_INTERFACES       = env :ONEAPP_VNF_DNS_INTERFACES, '' # nil -> none, empty -> all
    ONEAPP_VNF_DNS_ALLOWED_NETWORKS = env :ONEAPP_VNF_DNS_ALLOWED_NETWORKS, ''

    def parse_env
        @interfaces ||= parse_interfaces ONEAPP_VNF_DNS_INTERFACES
        @mgmt       ||= detect_mgmt_nics

        interfaces = @interfaces.keys - @mgmt

        @n2a ||= addrs_to_nics(interfaces, family: %w[inet]).to_h do |a, n|
            [n.first, a]
        end

        {
            interfaces: @interfaces.select do |nic, _|
                interfaces.include?(nic)
            end.to_h do |nic, info|
                info[:addr] = @n2a[nic]
                [nic, info]
            end,

            nameservers: ONEAPP_VNF_DNS_NAMESERVERS.split(%r{[ ,;]})
                                                   .map(&:strip)
                                                   .reject(&:empty?),

            networks: if ONEAPP_VNF_DNS_ALLOWED_NETWORKS.empty? then
                addrs_to_subnets(interfaces, family: %w[inet]).values.join(%[,])
            else
                ONEAPP_VNF_DNS_ALLOWED_NETWORKS
            end.split(%r{[ ,;]})
               .map(&:strip)
               .reject(&:empty?)
        }
    end

    def install(initdir: '/etc/init.d')
        msg :info, 'DNS::install'

        puts bash <<~SCRIPT
            apk --no-cache add dns-root-hints ruby unbound
            install -o unbound -g unbound -m u=rwx,go=rx -d /var/log/unbound/
        SCRIPT

        file "#{initdir}/one-dns", <<~SERVICE, mode: 'u=rwx,g=rx,o='
            #!/sbin/openrc-run

            source /run/one-context/one_env

            command="/usr/bin/ruby"
            command_args="-r /etc/one-appliance/lib/helpers.rb -r #{__FILE__}"

            output_log="/var/log/one-appliance/one-dns.log"
            error_log="/var/log/one-appliance/one-dns.log"

            depend() {
                after net firewall keepalived
            }

            start_pre() {
                rc-service unbound start --nodeps
            }

            start() { :; }

            stop() { :; }

            stop_post() {
                rc-service unbound stop --nodeps
            }
        SERVICE

        toggle [:update]
    end

    def configure(basedir: '/etc/unbound')
        msg :info, 'DNS::configure'

        if ONEAPP_VNF_DNS_ENABLED
            proto_yesno = ->(proto) {
                udp = ONEAPP_VNF_DNS_UDP_DISABLED ? 'no' : 'yes'
                tcp = ONEAPP_VNF_DNS_TCP_DISABLED ? 'no' : 'yes'
                case proto
                when 'udp', 'udp-upstream' then udp
                when 'tcp'                 then tcp
                when 'tcp-upstream'        then udp == 'yes' ? 'no' : 'yes'
                end
            }

            dns_vars = parse_env

            file "#{basedir}/unbound.conf", ERB.new(<<~CONFIG, trim_mode: '-').result(binding), mode: 'u=rw,g=r,o=', overwrite: true
                server:
                    # verbosity number, 0 is least verbose. 1 is default.
                    verbosity: 1

                    # specify the interfaces to answer queries from by ip-address.
                    # The default is to listen to localhost (127.0.0.1 and ::1).
                    # specify 0.0.0.0 and ::0 to bind to all available interfaces.
                    # specify every interface[@port] on a new 'interface:' labelled line.
                    # The listen interfaces are not changed on reload, only on restart.
                    # LOCALHOST:
                    interface: 127.0.0.1
                    interface: ::1
                    # ALL:
                    # interface: 0.0.0.0
                    # interface: ::0
                    # WHITELIST:
                    <%- dns_vars[:interfaces].each do |_, info| -%>
                    interface: <%= render_interface(info, name: false) %>
                    <%- end -%>

                    # port to answer queries from
                    # port: 53

                    # specify the interfaces to send outgoing queries to authoritative
                    # server from by ip-address. If none, the default (all) interface
                    # is used. Specify every interface on a 'outgoing-interface:' line.
                    # outgoing-interface: 192.0.2.153
                    # outgoing-interface: 2001:DB8::5
                    # outgoing-interface: 2001:DB8::6

                    # msec for waiting for an unknown server to reply.  Increase if you
                    # are behind a slow satellite link, to eg. 1128.
                    unknown-server-time-limit: <%= ONEAPP_VNF_DNS_UPSTREAM_TIMEOUT %>

                    # Enable IPv4, "yes" or "no".
                    do-ip4: yes

                    # Enable IPv6, "yes" or "no".
                    do-ip6: yes

                    # Enable UDP, "yes" or "no".
                    do-udp: <%= proto_yesno.('udp') %>

                    # Enable TCP, "yes" or "no".
                    do-tcp: <%= proto_yesno.('tcp') %>

                    # upstream connections use TCP only (and no UDP), "yes" or "no"
                    # useful for tunneling scenarios, default no.
                    tcp-upstream: <%= proto_yesno.('tcp-upstream') %>

                    # upstream connections also use UDP (even if do-udp is no).
                    # useful if if you want UDP upstream, but don't provide UDP downstream.
                    udp-upstream-without-downstream: <%= proto_yesno.('udp-upstream') %>

                    # control which clients are allowed to make (recursive) queries
                    # to this server. Specify classless netblocks with /size and action.
                    # By default everything is refused, except for localhost.
                    # Choose deny (drop message), refuse (polite error reply),
                    # allow (recursive ok), allow_setrd (recursive ok, rd bit is forced on),
                    # allow_snoop (recursive and nonrecursive ok)
                    # deny_non_local (drop queries unless can be answered from local-data)
                    # refuse_non_local (like deny_non_local but polite error reply).
                    # DEFAULT RULES:
                    access-control: 0.0.0.0/0 refuse
                    access-control: ::0/0 refuse
                    access-control: 127.0.0.0/8 allow
                    access-control: ::1 allow
                    access-control: ::ffff:127.0.0.1 allow
                    # WHITELIST:
                    <%- dns_vars[:networks].each do |subnet| -%>
                    access-control: <%= subnet %> allow
                    <%- end -%>

                    # the time to live (TTL) value lower bound, in seconds. Default 0.
                    # If more than an hour could easily give trouble due to stale data.
                    cache-min-ttl: 0

                    # the time to live (TTL) value cap for RRsets and messages in the
                    # cache. Items are not cached for longer. In seconds.
                    cache-max-ttl: <%= ONEAPP_VNF_DNS_MAX_CACHE_TTL %>

                    # TODO: chroot
                    # if given, a chroot(2) is done to the given directory.
                    # i.e. you can chroot to the working directory, for example,
                    # for extra security, but make sure all files are in that directory.
                    #
                    # If chroot is enabled, you should pass the configfile (from the
                    # commandline) as a full path from the original root. After the
                    # chroot has been performed the now defunct portion of the config
                    # file path is removed to be able to reread the config after a reload.
                    #
                    # All other file paths (working dir, logfile, roothints, and
                    # key files) can be specified in several ways:
                    #     o as an absolute path relative to the new root.
                    #     o as a relative path to the working directory.
                    #     o as an absolute path relative to the original root.
                    # In the last case the path is adjusted to remove the unused portion.
                    #
                    # The pid file can be absolute and outside of the chroot, it is
                    # written just prior to performing the chroot and dropping permissions.
                    #
                    # Additionally, unbound may need to access /dev/urandom (for entropy).
                    # How to do this is specific to your OS.
                    #
                    # If you give "" no chroot is performed. The path must not end in a /.
                    # chroot: ""

                    # if given, user privileges are dropped (after binding port),
                    # and the given username is assumed. Default is user "unbound".
                    # If you give "" no privileges are dropped.
                    # username: "unbound"

                    # the working directory. The relative files in this config are
                    # relative to this directory. If you give "" the working directory
                    # is not changed.
                    # If you give a server: directory: dir before include: file statements
                    # then those includes can be relative to the working directory.
                    # directory: ""

                    # the log file, "" means log to stderr.
                    # Use of this option sets use-syslog to "no".
                    logfile: "/var/log/unbound/unbound.log"

                    # Log to syslog(3) if yes. The log facility LOG_DAEMON is used to
                    # log to. If yes, it overrides the logfile.
                    # use-syslog: yes

                    # Log identity to report. if empty, defaults to the name of argv[0]
                    # (usually "unbound").
                    log-identity: ""

                    # print UTC timestamp in ascii to logfile, default is epoch in seconds.
                    log-time-ascii: yes

                    # print one line with time, IP, name, type, class for every query.
                    log-queries: no

                    # print one line per reply, with time, IP, name, type, class, rcode,
                    # timetoresolve, fromcache and responsesize.
                    log-replies: no

                    # print log lines that say why queries return SERVFAIL to clients.
                    log-servfail: yes

                    # file to read root hints from.
                    # get one from https://www.internic.net/domain/named.cache
                    <%- if ONEAPP_VNF_DNS_USE_ROOTSERVERS -%>
                    root-hints: /usr/share/dns-root-hints/named.root
                    <%- else -%>
                    # root-hints: /usr/share/dns-root-hints/named.root
                    <%- end -%>

                    # enable to not answer id.server and hostname.bind queries.
                    hide-identity: yes

                    # enable to not answer version.server and version.bind queries.
                    hide-version: yes

                    # Serve expired responses from cache, with TTL 0 in the response,
                    # and then attempt to fetch the data afresh.
                    serve-expired: no

                    # Use systemd socket activation for UDP, TCP, and control sockets.
                    use-systemd: no

                    # Detach from the terminal, run in background, "yes" or "no".
                    # Set the value to "no" when unbound runs as systemd service.
                    do-daemonize: yes

                # Remote control config section.
                remote-control:
                    control-enable: no

                # Forward zones
                # Create entries like below, to make all queries for 'example.com' and
                # 'example.org' go to the given list of servers. These servers have to handle
                # recursion to other nameservers. List zero or more nameservers by hostname
                # or by ipaddress. Use an entry with name "." to forward all queries.
                # If you enable forward-first, it attempts without the forward if it fails.
                # forward-zone:
                #     name: "example.com"
                #     forward-addr: 192.0.2.68
                #     forward-addr: 192.0.2.73@5355  # forward to port 5355.
                #     forward-first: no
                #     forward-tls-upstream: no
                #     forward-no-cache: no
                # forward-zone:
                #     name: "example.org"
                #     forward-host: fwd.example.com
                <%- unless ONEAPP_VNF_DNS_USE_ROOTSERVERS -%>
                forward-zone:
                    name: "."
                <%- dns_vars[:nameservers].each do |nameserver| -%>
                    forward-addr: <%= nameserver %>
                <%- end -%>
                <%- end -%>
            CONFIG
        else
            # NOTE: We always disable it at re-contexting / reboot in case an user enables it manually.
            toggle [:stop, :disable]
        end
    end

    def toggle(operations)
        operations.each do |op|
            msg :debug, "DNS::toggle([:#{op}])"
            case op
            when :disable
                puts bash 'rc-update del unbound default ||:'
                puts bash 'rc-update del one-dns default ||:'
            when :update
                puts bash 'rc-update -u'
            else
                puts bash "rc-service one-dns #{op.to_s}"
            end
        end
    end

    def bootstrap
        msg :info, 'DNS::bootstrap'
    end
end
end
