#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Security Group permissions test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        # Create 2 users (A, B) in the 'group1' group, and one (C) in group2
        cli_create_user("userA", "passwordA")
        cli_create_user("userB", "passwordB")
        cli_create_user("userC", "passwordC")

        cli_create("onegroup create group1")
        cli_create("onegroup create group2")

        cli_action("oneuser chgrp userA group1")
        cli_action("oneuser chgrp userB group1")

        cli_action("oneuser chgrp userC group2")

        cli_action("oneacl create '* SECGROUP/* CREATE'")
    end

    before(:each) do
        as_user("userA") do
            @id = cli_create("onesecgroup create", "NAME = test_sg")
        end
    end

    after(:each) do
        cli_action("onesecgroup delete #{@id}") if @id != -1
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    ############################################################################
    # Owner user tests
    ############################################################################

    it "Owner user should check USE right is set" do
        %w[400 u=r].each do |perm|
            cli_action("onesecgroup chmod #{@id} #{perm}")

            as_user("userA") do
                cli_action("onesecgroup show #{@id}")
                expect(cli_action("onesecgroup list").stdout).to match(/test_sg/)
            end
        end
    end

    it "Owner user should check USE right is unset" do
        cli_action("onesecgroup chmod #{@id} 000")

        as_user("userA") do
            cli_action("onesecgroup show #{@id}", false)
            expect(cli_action("onesecgroup list").stdout).to match(/test_sg/)
        end
    end

    it "Owner user should check MANAGE right is set" do
        # Set Owner_M
        cli_action("onesecgroup chmod #{@id} 200")

        as_user("userA") do
            cli_action("onesecgroup delete #{@id}")
            @id = -1
        end
    end

    it "Owner user should check MANAGE right is unset" do
        # Unset Owner_M
        cli_action("onesecgroup chmod #{@id} 000")

        as_user("userA") do
            cli_action("onesecgroup delete #{@id}", false)
        end
    end

    it "Owner user should check ADMIN right is set" do
        # Set Owner_A
        %w[100 u=x].each do |perm|
            cli_action("onesecgroup chmod #{@id} #{perm}")

            as_user("userA") do
                cli_action("onesecgroup chmod #{@id} 770")
            end
        end
    end

    it "Owner user should check ADMIN right is unset" do
        # Unset Owner_A
        cli_action("onesecgroup chmod #{@id} 000")

        as_user("userA") do
            cli_action("onesecgroup chmod #{@id} 770", false)
        end
    end

    ############################################################################
    # Group user tests
    ############################################################################
    it "Group user should check USE right is set" do
        # Set Group_U
        %w[040 g=r].each do |perm|
            cli_action("onesecgroup chmod #{@id} #{perm}")

            as_user("userB") do
                cli_action("onesecgroup show #{@id}")
                expect(cli_action("onesecgroup list").stdout).to match(/test_sg/)
            end
        end
    end

    it "Group user should check USE right is unset" do
        # Set Group_U
        cli_action("onesecgroup chmod #{@id} 600")

        as_user("userB") do
            cli_action("onesecgroup show #{@id}", false)
            expect(cli_action("onesecgroup list").stdout).not_to match(/test_sg/)
        end
    end

    it "Group user should check MANAGE right is set" do
        # Set Group_M
        cli_action("onesecgroup chmod #{@id} 020")

        as_user("userB") do
            cli_action("onesecgroup delete #{@id}")
            @id = -1
        end
    end

    it "Group user should check MANAGE right is unset" do
        # Unset Group_M
        cli_action("onesecgroup chmod #{@id} 600")

        as_user("userB") do
            cli_action("onesecgroup delete #{@id}", false)
        end
    end

    it "Group user should check ADMIN right is set" do
        # Set Group_A
        %w[010 g=x].each do |perm|
            cli_action("onesecgroup chmod #{@id} #{perm}")

            as_user("userB") do
                cli_action("onesecgroup chmod #{@id} 770")
            end
        end
    end

    it "Group user should check ADMIN right is unset" do
        # Unset Group_A
        cli_action("onesecgroup chmod #{@id} 600")

        as_user("userB") do
            cli_action("onesecgroup chmod #{@id} 770", false)
        end
    end

    ############################################################################
    # User not in group tests
    ############################################################################

    it "User not in group should check USE right is set" do
        # Set Other_U
        %w[004 o=r].each do |perm|
            cli_action("onesecgroup chmod #{@id} #{perm}")

            as_user("userC") do
                cli_action("onesecgroup show #{@id}")
                expect(cli_action("onesecgroup list").stdout).to match(/test_sg/)
            end
        end
    end

    it "User not in group should check USE right is unset" do
        # Set Other_U
        cli_action("onesecgroup chmod #{@id} 600")

        as_user("userC") do
            cli_action("onesecgroup show #{@id}", false)
            expect(cli_action("onesecgroup list").stdout).not_to match(/test_sg/)
        end
    end

    it "User not in group should check MANAGE right is set" do
        # Set Other_M
        cli_action("onesecgroup chmod #{@id} 002")

        as_user("userC") do
            cli_action("onesecgroup delete #{@id}")
            @id = -1
        end
    end

    it "User not in group should check MANAGE right is unset" do
        # Unset Other_M
        cli_action("onesecgroup chmod #{@id} 600")

        as_user("userC") do
            cli_action("onesecgroup delete #{@id}", false)
        end
    end

    it "User not in group should check ADMIN right is set" do
        # Set Other_A
        %w[001 o=x].each do |perm|
            cli_action("onesecgroup chmod #{@id} #{perm}")

            as_user("userC") do
                cli_action("onesecgroup chmod #{@id} 770")
            end
        end
    end

    it "User not in group should check ADMIN right is unset" do

        # Unset Other_A
        cli_action("onesecgroup chmod #{@id} 600")

        as_user("userC") do
            cli_action("onesecgroup chmod #{@id} 770", false)
        end
    end

    it "Should check access to SGs in NICs" do
        vnet=<<-EOF
            NAME = "nics"
            BRIDGE = br0
            VN_MAD = dummy
            AR = [ TYPE = "IP4", IP = "10.0.0.0", SIZE = 1024 ]
            EOF

        id1 = 0
        id2 = 0
        id3 = 0

        as_user("userA") do
            id1 = cli_create("onesecgroup create", "NAME = test_sg1")
            id2 = cli_create("onesecgroup create", "NAME = test_sg2")
            id3 = cli_create("onesecgroup create", "NAME = test_sg3")

            cli_action("onesecgroup chmod #{id1} 600")
            cli_action("onesecgroup chmod #{id2} 640")
            cli_action("onesecgroup chmod #{id3} 644")
        end

        vnetid = cli_create("onevnet create", vnet)

        vmtmpl=<<-EOF
            NAME=test
            CPU=1
            MEMORY=1
            NIC = [ NETWORK_ID = #{vnetid}, SECURITY_GROUPS = "#{id2}, #{id3}, #{id1}"]
        EOF

        vmtmpl2=<<-EOF
            NAME=test
            CPU=1
            MEMORY=1
            NIC = [ NETWORK_ID = #{vnetid}, SECURITY_GROUPS = "#{id2}, #{id3}"]
        EOF

        vmid = 0

        as_user("userB") do
            cli_create("onevm create", vmtmpl, false)
            vmid = cli_create("onevm create", vmtmpl2, true)
        end

        as_user("userC") do
            cli_create("onevm create", vmtmpl, false)
            cli_create("onevm create", vmtmpl2, false)
        end

        cli_action("onevm recover --delete  #{vmid}")
        vm = VM.new(vmid)
        vm.done?

        cli_action("onesecgroup delete #{id1}")
        cli_action("onesecgroup delete #{id2}")
        cli_action("onesecgroup delete #{id3}")

        cli_action("onevnet delete #{vnetid}")
    end

    it "Should check access to SGs in VNET" do
        id1 = 0
        id2 = 0
        id3 = 0

        as_user("userA") do
            id1 = cli_create("onesecgroup create", "NAME = test_sg1")
            id2 = cli_create("onesecgroup create", "NAME = test_sg2")
            id3 = cli_create("onesecgroup create", "NAME = test_sg3")

            cli_action("onesecgroup chmod #{id1} 640")
            cli_action("onesecgroup chmod #{id2} 644")
            cli_action("onesecgroup chmod #{id3} 600")
        end

        vnet=<<-EOF
            NAME = "nics"
            BRIDGE = br0
            VN_MAD = dummy
            AR = [ TYPE = "IP4", IP = "10.0.0.0", SIZE = 1024 ]
            SECURITY_GROUPS = "#{id1}, #{id2}"
            EOF

        vnetid = cli_create("onevnet create", vnet)

        vmtmpl=<<-EOF
            NAME=test
            CPU=1
            MEMORY=1
            NIC = [ NETWORK_ID = #{vnetid}, SECURITY_GROUPS = "#{id3}" ]
        EOF

        vmtmpl2=<<-EOF
            NAME=test
            CPU=1
            MEMORY=1
            NIC = [ NETWORK_ID = #{vnetid}]
        EOF

        vmid = 0

        as_user("userB") do
            cli_create("onevm create", vmtmpl, false)
            vmid = cli_create("onevm create", vmtmpl2, true)
        end

        as_user("userC") do
            cli_create("onevm create", vmtmpl, false)
            cli_create("onevm create", vmtmpl2, false)
        end

        cli_action("onevm recover --delete  #{vmid}")
        vm = VM.new(vmid)
        vm.done?

        cli_action("onesecgroup delete #{id1}")
        cli_action("onesecgroup delete #{id2}")
        cli_action("onesecgroup delete #{id3}")

        cli_action("onevnet delete #{vnetid}")
    end

    it "Should check access to SGs in ARs" do
        id1 = 0
        id2 = 0
        id3 = 0

        as_user("userA") do
            id1 = cli_create("onesecgroup create", "NAME = test_sg1")
            id2 = cli_create("onesecgroup create", "NAME = test_sg2")
            id3 = cli_create("onesecgroup create", "NAME = test_sg3")

            cli_action("onesecgroup chmod #{id1} 640")
            cli_action("onesecgroup chmod #{id2} 644")
            cli_action("onesecgroup chmod #{id3} 644")
        end

        vnet=<<-EOF
            NAME = "nics"
            BRIDGE = br0
            VN_MAD = dummy
            AR = [ TYPE = "IP4", IP = "10.0.0.0", SIZE = 1024, SECURITY_GROUPS = "#{id2}" ]
            AR = [ TYPE = "IP4", IP = "10.0.0.0", SIZE = 1024 ]
            AR = [ TYPE = "IP4", IP = "10.0.0.0", SIZE = 1024, SECURITY_GROUPS = "#{id1}"]

            SECURITY_GROUPS = "#{id3}"
            EOF

        vnetid = cli_create("onevnet create", vnet)

        vmtmpl2=<<-EOF
            NAME=test
            CPU=1
            MEMORY=1
            NIC = [ NETWORK_ID = #{vnetid}]
        EOF

        vmid = 0

        as_user("userB") do
            vmid = cli_create("onevm create", vmtmpl2, true)
        end

        as_user("userC") do
            cli_create("onevm create", vmtmpl2, false)
        end

        cli_action("onevm recover --delete  #{vmid}")

        vm = VM.new(vmid)
        vm.done?

        cli_action("onesecgroup delete #{id1}")
        cli_action("onesecgroup delete #{id2}")
        cli_action("onesecgroup delete #{id3}")

        cli_action("onevnet delete #{vnetid}")
    end

    it "Should check access to SGs for sg-attach/detach actions" do
        vnet=<<-EOF
            NAME = "nics"
            BRIDGE = br0
            VN_MAD = dummy
            AR = [ TYPE = "IP4", IP = "10.0.0.0", SIZE = 1024 ]
            EOF

        id1 = 0
        id2 = 0
        id3 = 0

        as_user("userA") do
            id1 = cli_create("onesecgroup create", "NAME = test_sg1")
            id2 = cli_create("onesecgroup create", "NAME = test_sg2")
            id3 = cli_create("onesecgroup create", "NAME = test_sg3")

            cli_action("onesecgroup chmod #{id1} 600")
            cli_action("onesecgroup chmod #{id2} 640")
            cli_action("onesecgroup chmod #{id3} 644")
        end

        vnetid = cli_create("onevnet create", vnet)

        vmtmpl=<<-EOF
            NAME=test
            CPU=1
            MEMORY=1
            NIC = [ NETWORK_ID = #{vnetid} ]
        EOF

        vmid = 0

        # Owner can use all SGs
        as_user("userA") do
            vmid = cli_create("onevm create", vmtmpl)

            cli_action("onevm sg-attach #{vmid} 0 #{id1}")
            cli_action("onevm sg-attach #{vmid} 0 #{id2}")
            cli_action("onevm sg-attach #{vmid} 0 #{id3}")

            cli_action("onevm sg-detach #{vmid} 0 #{id1}")
            cli_action("onevm sg-detach #{vmid} 0 #{id2}")
            cli_action("onevm sg-detach #{vmid} 0 #{id3}")
        end

        cli_action("onevm recover --delete  #{vmid}")
        vm = VM.new(vmid)
        vm.done?

        # userB use group permissions
        as_user("userB") do
            vmid = cli_create("onevm create", vmtmpl)

            cli_action("onevm sg-attach #{vmid} 0 #{id1}", false)
            cli_action("onevm sg-attach #{vmid} 0 #{id2}")
            cli_action("onevm sg-attach #{vmid} 0 #{id3}")

            cli_action("onevm sg-detach #{vmid} 0 #{id2}")
            cli_action("onevm sg-detach #{vmid} 0 #{id3}")
        end

        cli_action("onevm recover --delete  #{vmid}")
        vm = VM.new(vmid)
        vm.done?

        # userC use others permissions
        as_user("userC") do
            vmid = cli_create("onevm create", vmtmpl)

            cli_action("onevm sg-attach #{vmid} 0 #{id1}", false)
            cli_action("onevm sg-attach #{vmid} 0 #{id2}", false)
            cli_action("onevm sg-attach #{vmid} 0 #{id3}")

            cli_action("onevm sg-detach #{vmid} 0 #{id3}")
        end

        cli_action("onevm recover --delete  #{vmid}")
        vm = VM.new(vmid)
        vm.done?

        cli_action("onesecgroup delete #{id1}")
        cli_action("onesecgroup delete #{id2}")
        cli_action("onesecgroup delete #{id3}")

        cli_action("onevnet delete #{vnetid}")
    end

end

