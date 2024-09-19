require 'init'

# Tests the configuration of the Frontend, the Hosts, and the SSH Keys

# Description:
# - OpenNebula is Running
# - CLI is able to run a command
# Parameters:
# None
RSpec.describe "Basic Configuration" do
    it "OpenNebula is running" do
        cli_action('pgrep -lf oned', true)
    end

    it "CLI is working" do
        xml = cli_action_xml("oneuser show -x")
        expect(xml['ID']).to eq("0")
    end
end

# Description:
# - SSH passwordlessly to all the hosts
# - User oneadmin is present with expected uid/gid
# - SSH from every node to all the other nodes
# Parameters:
# :hosts: [Array] list of hosts to test
# :oneadmin: The oneadmin user
RSpec.describe "Hosts Configuration" do
    it "ssh key and fingerprint" do
        @defaults[:hosts].each do |host|
            cli_action("ssh #{HOST_SSH_OPTS} #{host} echo")
        end
    end

    it "oneadmin account and id" do
        @defaults[:hosts].each do |host|
            id_u_cmd   = cli_action("ssh #{host} id -u")
            whoami_cmd = cli_action("ssh #{host} whoami")

            id_u   = id_u_cmd.stdout.to_i
            whoami = whoami_cmd.stdout.strip

            expect(id_u).to be(9869)
            expect(whoami).to eq(@defaults[:oneadmin])
        end
    end

    it "all hosts know about all other hosts and frontend" do
        hosts = @defaults[:hosts]
        target_hosts = hosts.clone << `hostname -f`.strip

        # Build the concatenated ssh command that accesses all hosts
        # to be run from all hosts
        ssh_hosts = target_hosts.map do |h|
            "ssh #{HOST_SSH_OPTS} #{h} echo '#{h}: OK'"
        end.join(" && ")

        hosts.each do |host|
            cmdline = ''
            if cli_action('test /run/one/ssh-agent.sock', nil).success?
                cmdline = %Q{SSH_AUTH_SOCK=/run/one/ssh-agent.sock ssh -A -o ControlMaster=no -o ControlPath=none #{host} "#{ssh_hosts}"}
                # TODO: provisional workaround needed because env var SSH_AUTH_SOCK
                #       requires -e in docker exec
                cmdline = %Q{sh -c 'SSH_AUTH_SOCK=/run/one/ssh-agent.sock ssh -A -o ControlMaster=no -o ControlPath=none #{host} "#{ssh_hosts.gsub("'","\\\\\"")}"'} if REMOTE_FRONTEND && REMOTE_TYPE == 'docker'
            else
                cmdline = %Q{ssh #{host} "#{ssh_hosts}"}
            end

            cmd = cli_action(cmdline)
        end
    end
end
