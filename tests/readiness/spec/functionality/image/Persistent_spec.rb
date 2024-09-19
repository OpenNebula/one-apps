#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Persistent attribute configration test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        # Create 2 users (A, B) in the 'users' group, and one (C) in a new group
        @uidA = cli_create_user("userA", "passa")
        @uidB = cli_create_user("userB", "passb")

        @gid = cli_create("onegroup create new_group")

        cli_action("oneuser chgrp userB new_group")

        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update("onedatastore update default", mads, false)

        cli_update("onedatastore update system", mads, false)

        wait_loop do
            xml = cli_action_xml("onedatastore show -x default")
            xml['FREE_MB'].to_i > 0
        end

        @p  =  cli_create("oneimage create -d 1 --name p --path "\
                            "/etc/passwd --size 200")
        @np =  cli_create("oneimage create -d 1 --name np --path "\
                            "/etc/passwd --size 200")

        wait_loop() do
            xml = cli_action_xml("oneimage show -x #{@p}")
            Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
        end

        wait_loop() do
            xml = cli_action_xml("oneimage show -x #{@np}")
            Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
        end

        @host_id = cli_create("onehost create dummy -i dummy -v dummy")

        cli_action("oneimage chmod #{@p} 666")
        cli_action("oneimage persistent #{@p}")
        cli_update("oneimage update #{@p}",
                   "PERSISTENT_TYPE=\"SHAREABLE\"", true)
        cli_action("oneimage chmod #{@np} 666")
        cli_action("oneimage nonpersistent #{@np}")

        as_user("userA") do

            template=<<-EOF
                NAME   = test_vm
                CPU    = 1
                MEMORY = 128

                DISK = [ IMAGE = p , IMAGE_UID = 0 ]
                DISK = [ IMAGE = np , IMAGE_UID = 0 ]
            EOF

            @vmid = cli_create("onevm create", template)
        end

        cli_action("onevm deploy #{@vmid} #{@host_id}")

        VM.new(@vmid).running?
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should preserve the default persitency when save-as an vm disk" do
        vm = VM.new(@vmid)

        as_user("userA") do
            cli_action("onevm disk-saveas #{@vmid} 0 uAsp")
            vm.running?
            cli_action("onevm disk-saveas #{@vmid} 1 uAsnp")
            vm.running?

            xmlp  = cli_action_xml("oneimage show -x uAsp")
            xmlnp = cli_action_xml("oneimage show -x uAsnp")

            expect(xmlp['PERSISTENT']).to eq('0')
            expect(xmlnp['PERSISTENT']).to eq('0')
        end

        as_user("userA") do
            cli_update("oneuser update userA",
                   "OPENNEBULA = [ DEFAULT_IMAGE_PERSISTENT = \"YES\" ] ", true)

            cli_action("onevm disk-saveas #{@vmid} 0 uAsp2")
            vm.running?
            cli_action("onevm disk-saveas #{@vmid} 1 uAsnp2")
            vm.running?

            xmlp  = cli_action_xml("oneimage show -x uAsp2")
            xmlnp = cli_action_xml("oneimage show -x uAsnp2")

            expect(xmlp['PERSISTENT']).to eq('1')
            expect(xmlnp['PERSISTENT']).to eq('1')
        end

        vm.running?

        cli_action("onevm terminate --hard #{@vmid}");

        vm.done?
    end

    it "should preserve the default persistency when cloning an image" do
        as_user("userA") do
            cli_update("oneuser update userA",
                   "OPENNEBULA = [ DEFAULT_IMAGE_PERSISTENT = \"\" ] ", true)

            uap  = cli_action("oneimage clone #{@p} uAp")
            uanp = cli_action("oneimage clone #{@np} uAnp")

            xmlp  = cli_action_xml("oneimage show -x uAp")
            xmlnp = cli_action_xml("oneimage show -x uAnp")

            expect(xmlnp['PERSISTENT']).to eq('0')
            expect(xmlp['PERSISTENT']).to eq('1')
            expect(xmlp['TEMPLATE/PERSISTENT_TYPE']).to eq('SHAREABLE')
        end
    end

    it "should set the user defined default persistency when cloning an image" do

        cli_update("oneuser update userA",
                   "OPENNEBULA = [ DEFAULT_IMAGE_PERSISTENT = \"YES\" ] ", true)

        as_user("userA") do
            uap  = cli_action("oneimage clone #{@p} uAp2")
            uanp = cli_action("oneimage clone #{@np} uAnp2")

            xmlp  = cli_action_xml("oneimage show -x uAp2")
            xmlnp = cli_action_xml("oneimage show -x uAnp2")

            expect(xmlnp['PERSISTENT']).to eq('1')
            expect(xmlp['PERSISTENT']).to eq('1')
            expect(xmlp['TEMPLATE/PERSISTENT_TYPE']).to eq('SHAREABLE')
        end

        cli_update("oneuser update userA",
                   "OPENNEBULA = [ DEFAULT_IMAGE_PERSISTENT = \"NO\" ] ", true)

        as_user("userA") do
            uap  = cli_action("oneimage clone #{@p} uAp3")
            uanp = cli_action("oneimage clone #{@np} uAnp3")

            xmlp  = cli_action_xml("oneimage show -x uAp3")
            xmlnp = cli_action_xml("oneimage show -x uAnp3")

            expect(xmlnp['PERSISTENT']).to eq('0')
            expect(xmlp['PERSISTENT']).to eq('0')
            expect(xmlp['TEMPLATE/PERSISTENT_TYPE']).to be_nil
        end
    end

    it "should set the group defined default persistency when cloning an image" do

        cli_update("onegroup update new_group",
                   "OPENNEBULA = [ DEFAULT_IMAGE_PERSISTENT = \"NO\" ] ", true)

        as_user("userB") do
            uap  = cli_action("oneimage clone #{@p} uBp")
            uanp = cli_action("oneimage clone #{@np} uBnp")

            xmlp  = cli_action_xml("oneimage show -x uBp")
            xmlnp = cli_action_xml("oneimage show -x uBnp")

            expect(xmlnp['PERSISTENT']).to eq('0')
            expect(xmlp['PERSISTENT']).to eq('0')
            expect(xmlp['TEMPLATE/PERSISTENT_TYPE']).to be_nil
        end
    end

    it "should set the group defined default persistency and persistency into
         template when creating an image" do

        cli_update("onegroup update new_group",
                   "OPENNEBULA = [ DEFAULT_IMAGE_PERSISTENT_NEW = \"NO\" ] ", true)

        as_user("userB") do
            pB  =  cli_create("oneimage create -d 1 --name pB1 --path "\
                            "/etc/passwd --size 200 --persistent")

            xmlnp = cli_action_xml("oneimage show -x pB1")

            expect(xmlnp['PERSISTENT']).to eq('1')
        end
    end

    it "should set the group defined default persistency when creating an image" do

        cli_update("onegroup update new_group",
                   "OPENNEBULA = [ DEFAULT_IMAGE_PERSISTENT_NEW = \"YES\" ] ", true)

        as_user("userB") do
            pB  =  cli_create("oneimage create -d 1 --name pB --path "\
                            "/etc/passwd --size 200")

            xmlnp = cli_action_xml("oneimage show -x pB")

            expect(xmlnp['PERSISTENT']).to eq('1')
        end
    end

    it "should set the user defined default persistency when creating an image" do

        as_user("userA") do
            pA2  =  cli_create("oneimage create -d 1 --name pA2 --path "\
                            "/etc/passwd --size 200")

            xmlnp = cli_action_xml("oneimage show -x pA2")

            expect(xmlnp['PERSISTENT']).to eq('0')
        end

        cli_update("oneuser update userA",
                   "OPENNEBULA = [ DEFAULT_IMAGE_PERSISTENT_NEW = \"YES\" ] ", true)

        as_user("userA") do
            pA  =  cli_create("oneimage create -d 1 --name pA --path "\
                            "/etc/passwd --size 200")

            xmlnp = cli_action_xml("oneimage show -x pA")

            expect(xmlnp['PERSISTENT']).to eq('1')
        end
    end

end

