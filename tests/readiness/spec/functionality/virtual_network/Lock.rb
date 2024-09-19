#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
require 'VN'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "lock VirtualNetwork test" do

    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        cli_create_user("userA", "passwordA")
        tmpl = <<-EOF
            NAME = vnet_test
            BRIDGE = br0
            VN_MAD = dummy
            AR=[TYPE = "IP4", IP = "10.0.0.10", SIZE = "100" ]
        EOF
        @vnet_id = cli_create("onevnet create", tmpl)

        cli_action("onevnet chown vnet_test userA")
        cli_action("onevnet chmod vnet_test 700")
    end

    after(:each) do
        vn = VN.new('test_reservation')
        vn.delete
        vn.deleted?
    end

    after(:all) do
        cli_action("onevnet delete vnet_test")
    end

    it "should lock/unlock 'use' level a vnet" do
        as_user("userA") do
            cli_action("onevnet lock vnet_test --use")
            cli_action("onevnet reserve vnet_test -s 1 -n test_reservation", false)   # use
            cli_update("onevnet update vnet_test", "LOCK_USE_TEST=TRUE", true, false) # manage
            cli_action("onevnet addar vnet_test -s 128 -i 10.0.1.1", false)           # admin

            cli_action("onevnet unlock vnet_test")
            cli_action("onevnet reserve vnet_test -s 1 -n test_reservation", true)    # use
            cli_update("onevnet update vnet_test", "LOCK_USE_TEST=TRUE", true, true)  # manage
            cli_action("onevnet addar vnet_test -s 128 -i 10.0.1.1", true)            # admin
        end
    end

    it "should lock/unlock 'manage' level a vnet" do
        as_user("userA") do
            cli_action("onevnet lock vnet_test --manage")
            cli_action("onevnet reserve vnet_test -s 1 -n test_reservation", true)       # use
            cli_update("onevnet update vnet_test", "LOCK_MANAGE_TEST=TRUE", true, false) # manage
            cli_action("onevnet addar vnet_test -s 128 -i 10.0.2.1", false)              # admin

            cli_action("onevnet unlock vnet_test")
            cli_update("onevnet update vnet_test", "LOCK_MANAGE_TEST=TRUE", true, true)  # manage
            cli_action("onevnet addar vnet_test -s 128 -i 10.0.2.1", true)               # admin
        end
    end

    it "should lock/unlock 'admin' level a vnet" do
        as_user("userA") do
            cli_action("onevnet lock vnet_test --admin")
            cli_action("onevnet reserve vnet_test -s 1 -n test_reservation", true)     # use
            cli_update("onevnet update vnet_test", "LOCK_ADMIN_TEST=TRUE", true, true) # manage
            cli_action("onevnet addar vnet_test -s 128 -i 10.0.3.1", false)            # admin

            cli_action("onevnet unlock vnet_test")
            cli_action("onevnet addar vnet_test -s 128 -i 10.0.3.1", true)            # admin
        end
    end

    it "should lock/unlock 'all' level a vnet" do
        as_user("userA") do
            cli_action("onevnet lock vnet_test --all")
            cli_action("onevnet reserve vnet_test -s 1 -n test_reservation", false)   # use
            cli_update("onevnet update vnet_test", "LOCK_ALL_TEST=TRUE", true, false) # manage
            cli_action("onevnet addar vnet_test -s 128 -i 10.0.1.1", false)           # admin

            cli_action("onevnet unlock vnet_test")
            cli_action("onevnet reserve vnet_test -s 1 -n test_reservation", true)    # use
            cli_update("onevnet update vnet_test", "LOCK_ALL_TEST=TRUE", true, true)  # manage
            cli_action("onevnet addar vnet_test -s 128 -i 10.0.1.1", true)            # admin
        end
    end
end