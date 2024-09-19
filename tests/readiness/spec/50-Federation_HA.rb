require 'init'

STOP_CMD  = 'sudo -u root -n systemctl stop opennebula'
START_CMD = 'sudo -u root -n systemctl start opennebula'
RESET_CMD = 'sudo -u root -n systemctl reset-failed opennebula'

RSpec.shared_examples_for "Federation-HA" do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}
        @info[:zone] = Zone.new(@defaults[:fedha_zone_id])
    end

    it "has slave and/or HA zones" do
        expect((@info[:zone].slaves.empty? and @info[:zone].servers.empty?)).to be(false)
    end

    it "has slave zones with at least 1 server" do
        @info[:zone].slaves do |slave|
            expect(slave.servers).not_to be_empty
        end
    end

    it "has healthy zones" do
        [@info[:zone], @info[:zone].slaves].flatten.each do |z|
            expect(z.ok?).to be(true)
        end
    end

    it "has reachable zone endpoints" do
        [@info[:zone], @info[:zone].slaves].flatten.each do |z|
            cli_action("oneuser list -x --endpoint #{z.endpoint}")
        end
    end

    it "has reachable zone endpoints via SSH" do
        [@info[:zone], @info[:zone].slaves].flatten.each do |z|
            cli_action("ssh #{z.host} /bin/true")
        end
    end

    it "has reachable server endpoints" do
        [@info[:zone], @info[:zone].slaves].flatten.each do |z|
            z.servers.each_pair do |id, h|
                cli_action("oneuser list -x --endpoint #{h[:endpoint]}")
            end
        end
    end

    it "has reachable server endpoints via SSH" do
        [@info[:zone], @info[:zone].slaves].flatten.each do |z|
            z.servers.each_pair do |id, h|
                cli_action("ssh #{h[:host]} /bin/true")
            end
        end
    end
end

RSpec.shared_examples_for "Restart OpenNebula" do
    it 'changes leader on OpenNebula restart' do
        [@info[:zone], @info[:zone].slaves].flatten.each do |z|
            next unless z.ha?

            leader = z.leader
            srv    = z.servers(false)[leader]

            cli_action("ssh #{srv[:host]} #{STOP_CMD}")

            t0 = Time.now

            wait_loop do
                STDERR.puts "Waiting for new leader on #{z.endpoint}"

                z.servers(true)

                leader = z.leader

                if z.leader
                    srv_new = z.servers(false)[z.leader]

                    srv_new[:host] != srv[:host]
                else
                    false
                end
            end

            STDERR.puts "New Leader found in #{Time.now - t0}"

            cli_action("ssh #{srv[:host]} #{RESET_CMD}")
            cli_action("ssh #{srv[:host]} #{START_CMD}")

            wait_loop do
                STDERR.puts "Waiting for #{srv[:endpoint]}"
                cmd = cli_action("oneuser list -x --endpoint #{srv[:endpoint]}", nil)
                cmd.success?
            end

        end
    end

    it "restarts federation zones" do
        [@info[:zone], @info[:zone].slaves].flatten.each do |z|
            next if z.ha?

            # for non-HA zones, restart the zone endpoint daemon
            cli_action("ssh #{z.host} #{STOP_CMD}")
            sleep 30
            cli_action("ssh #{z.host} #{RESET_CMD}")
            cli_action("ssh #{z.host} #{START_CMD}")

            # wait for the zone endpoint availability
            wait_loop do
                STDERR.puts "waiting for #{z.endpoint}"
                cmd = cli_action("oneuser list -x --endpoint #{z.endpoint}", nil)
                cmd.success?
            end
        end
    end

    it "waits until zones are healthy" do
        [@info[:zone], @info[:zone].slaves].flatten.each do |z|
            wait_loop do
                z.ok?
            end
        end
    end
end

RSpec.shared_examples_for "Create users" do |endpoint|
    include_examples "Federation-HA"

    it "creates users" do
        (1..@defaults[:fedha_objects_count]).each do |user_id|
            cli_action("oneuser create rspec_fedha_#{user_id} password --endpoint #{endpoint}")
        end
    end

    it "created users on all zone endpoints" do
        [@info[:zone], @info[:zone].slaves].flatten.each do |z|
            wait_loop do
                xml = cli_action_xml("oneuser list -x --endpoint #{z.endpoint}")

                users_found = true
                (1..@defaults[:fedha_objects_count]).each do |user_id|
                    unless xml["/USER_POOL/USER[NAME='rspec_fedha_#{user_id}']/ID"]
                        users_found = false
                    end
                end

                users_found
            end
        end
    end

    it "created users on all server endpoints" do
        [@info[:zone], @info[:zone].slaves].flatten.each do |z|
            z.servers.each_pair do |id, h|
                wait_loop do
                    xml = cli_action_xml("oneuser list -x --endpoint #{h[:endpoint]}")

                    users_found = true
                    (1..@defaults[:fedha_objects_count]).each do |user_id|
                        unless xml["/USER_POOL/USER[NAME='rspec_fedha_#{user_id}']/ID"]
                            users_found = false
                        end
                    end

                    users_found
                end
            end
        end
    end

    it "deletes users" do
        (1..@defaults[:fedha_objects_count]).each do |user_id|
            cli_action("oneuser delete rspec_fedha_#{user_id} --endpoint #{endpoint}")
        end
    end

    it "deleted users from all zone endpoints" do
        [@info[:zone], @info[:zone].slaves].flatten.each do |z|
            wait_loop do
                xml = cli_action_xml("oneuser list -x --endpoint #{z.endpoint}")

                users_found = false
                (1..@defaults[:fedha_objects_count]).each do |user_id|
                    if xml["/USER_POOL/USER[NAME='rspec_fedha_#{user_id}']/ID"]
                        users_found = true
                    end
                end

                not users_found
            end
        end
    end

    it "deleted users from all server endpoints" do
        [@info[:zone], @info[:zone].slaves].flatten.each do |z|
            z.servers.each_pair do |id, h|
                wait_loop do
                    xml = cli_action_xml("oneuser list -x --endpoint #{h[:endpoint]}")

                    users_found = false
                    (1..@defaults[:fedha_objects_count]).each do |user_id|
                        if xml["/USER_POOL/USER[NAME='rspec_fedha_#{user_id}']/ID"]
                            users_found = true
                        end
                    end

                    not users_found
                end
            end
        end
    end

    include_examples "Restart OpenNebula"
end

RSpec.shared_examples_for "onezone serversync" do |z|
    services = ['opennebula', 'opennebula-sunstone']

    it "check services before breaking anything" do
        services.each do |service|
            expect(system( "systemctl is-active --quiet #{service}" )).to be(true)
        end
    end

    #Inject some text to create inconsistency between configuration files
    it "modify config file" do
        cli_action("ssh root@#{z.host} \"echo \"A=A\" >>/etc/one/oned.conf\"")
        cli_action("ssh root@#{z.host} \"echo \":A: A\" >>/etc/one/sunstone-server.conf\"")
        cli_action("ssh root@#{z.host} \"echo \"a: a\" >>/etc/one/sunstone-views/kvm/admin.yaml\"")

        cli_action("grep 'A=A' /etc/one/oned.conf")
        cli_action("grep ':A: A' /etc/one/sunstone-server.conf")
        cli_action("grep 'a: a' /etc/one/sunstone-views/kvm/admin.yaml")
    end

    #Now fix everything by recovering configurations from slave nodes
    it "fixes configurations" do
        endpoint = z.xml["/ZONE_POOL/ZONE/SERVER_POOL/SERVER[2]/ENDPOINT"]
        endpointIPAddress = endpoint[7..(endpoint.length-11)]
        if z.host != endpointIPAddress
            cli_action("ssh root@#{z.host} onezone serversync #{endpointIPAddress}")
        end

        cli_action("grep 'A=A' /etc/one/oned.conf", false)
        cli_action("grep ':A: A' /etc/one/sunstone-server.conf", false)
        cli_action("grep 'a: a' /etc/one/sunstone-views/kvm/admin.yaml", false)

        services.each do |service|
            wait_loop do
                STDERR.puts "Waiting for #{service}"
                system("systemctl is-active --quiet #{service}")
            end
        end

    end
end

RSpec.describe "Federated-HA replication" do
    config = OpenNebula::System.new(Client.new()).get_configuration

    (1..10).each do |i|
        context "Iteration #{i}" do
            _defaults = RSpec.configuration.defaults
            @zone = Zone.new(_defaults[:fedha_zone_id])

            [@zone, @zone.slaves].flatten.each do |z|
                context "Endpoint #{z.endpoint}" do
                    context "Create users" do
                        include_examples "Create users", z.endpoint
                    end

                    # There is no sense on doing this test several times on different nodes
                    # so it will only be done at the master zone
                    # `onezone serversync` works only for mysql backend
                    if z.master && config['DB/BACKEND'] == 'mysql'
                        if !z.xml.to_hash['ZONE_POOL']['ZONE'].is_a?(Array)
                            # Only HA, no federation
                            context "Sync configuration" do
                                include_examples "onezone serversync", z
                            end
                        end
                    end
                end
            end
        end
    end
end
