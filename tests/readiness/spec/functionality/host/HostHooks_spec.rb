#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Host operations test" do

    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do
        template = <<-EOF
                    NAME = offline
                    TYPE = state
                    COMMAND = /tmp/host.hook
                    STATE = OFFLINE
                    RESOURCE = HOST
        EOF

        cli_create('onehook create', template)

        template = <<-EOF
                    NAME = enable
                    TYPE = api
                    COMMAND = /tmp/host_enable.hook
                    CALL = "one.host.status"
                    RESOURCE = HOST
        EOF

        cli_create('onehook create', template)

        `echo "date >> /tmp/host_out.hook" > /tmp/host.hook`
        `echo "touch /tmp/enable" > /tmp/host_enable.hook`
        `chmod 766 /tmp/host.hook`
        `chmod 766 /tmp/host_enable.hook`

        @hid = cli_create("onehost create localhost -i dummy -v dummy")
    end

    it "should trigger a hook when host change to offline state" do
        next_exec = get_hook_exec('offline')

        cli_action("onehost offline #{@hid}")

        wait_loop()do
            xml = cli_action_xml("onehost show #{@hid} -x")
            OpenNebula::Host::HOST_STATES[xml['STATE'].to_i] == 'OFFLINE'
        end

        wait_hook('offline', next_exec)
    end

    it "should trigger a hook when host change to on state" do
        next_exec = get_hook_exec('enable')

        cli_action("onehost enable #{@hid}")

        wait_hook('enable', next_exec)

        expect(File.exist?('/tmp/enable')).to be(true)
    end

    it "should trigger a hook when host change to on state" do

        cli_action("onehost offline #{@hid}")

        wait_loop()do
            xml = cli_action_xml("onehost show #{@hid} -x")
            OpenNebula::Host::HOST_STATES[xml['STATE'].to_i] == 'OFFLINE'
        end

        cli_action("onehost enable #{@hid}")

        wait_loop()do
            xml = cli_action_xml("onehost show #{@hid} -x")
            OpenNebula::Host::HOST_STATES[xml['STATE'].to_i] == 'MONITORED'
        end

        File.read("/tmp/host_out.hook") { |f| expect(f.count).to eq(2) }
    end

end
