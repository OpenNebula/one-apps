module CLITester

require 'uri'

# methods
class Zone
    include RSpec::Matchers

    attr_accessor :id, :master

    def initialize(id, master=true)
        @id = id
        @master = master
        @slaves = []
        @servers = {}

        info
    end

    def [](key)
         return @xml[key]
    end

    def endpoint
        if @xml["/ZONE_POOL/ZONE[ID=#{@id}]/TEMPLATE/ENDPOINT"].nil?
            @xml["/ZONE/TEMPLATE/ENDPOINT"]
        else
            @xml["/ZONE_POOL/ZONE[ID=#{@id}]/TEMPLATE/ENDPOINT"]
        end
    end

    def host
        URI(endpoint).host
    end

    def slaves
        @slaves
    end

    def servers(refresh=true)
        sync_status if refresh
        @servers
    end

    def leader
        leader = nil

        servers.each do |id, h|
            if h[:state] == 'leader'
                expect(leader).to be_nil
                leader = id
            end
        end

        leader
    end

    def ha?
        @servers.length > 1
    end

    def ok?
        if @servers.empty?
            true
        else
            # get list of server states
            states = []
            servers.each do |id, h|
                states << h[:state]
            end

            if @servers.keys.length == 1
                # if single server, it must be "solo"
                states == ["solo"]
            else
                # if more servers, there should be only one leader
                # and the rest followers
                states.sort == ["follower"]*(@servers.keys.length-1) + ["leader"]
            end
        end
    end

    def xml(refresh=false)
        info if refresh
        @xml
    end

    def info
        @xml = cli_action_xml("onezone list -x")

        # servers endpoints
        @servers = {}
        @xml.each("/ZONE_POOL/ZONE[ID=#{@id}]/SERVER_POOL/SERVER") do |server|
            @servers[ server['ID'] ] = {
                name:       server['NAME'],
                endpoint:   server['ENDPOINT'],
                host:       URI(server['ENDPOINT']).host,
                state:    'unknown'
            }
        end

        # for master zone, reread all slave zones
        @slaves = []
        if @master
            @xml.each("/ZONE_POOL/ZONE[ID!=#{@id}]") do |slave|
                @slaves << Zone.new(slave['ID'], false)
            end
        end
    end

    def humanize_state(s)
        case s
            when "0" then "solo"
            when "1" then "candidate"
            when "2" then "follower"
            when "3" then "leader"
            else "unknown"
        end
    end

    def sync_status
        @servers.each do |_k, s|
            s[:state] = 'unknown'
            ep = s[:endpoint]
            cs = OpenNebula::Client.new(nil, ep, :timeout => 5)

            STDERR.puts "Updating server status via #{ep}"

            ss_xml = cs.call('zone.raftstatus')
            nk_xml = Nokogiri::XML(ss_xml)

            next if OpenNebula.is_error?(ss_xml)

            state = nk_xml.at_xpath('RAFT/STATE')

            next unless state

            s[:state] = humanize_state(state.text)

            STDERR.puts "New server status is #{s[:state]}"
        end
    end
end

# end module CLITester
end
