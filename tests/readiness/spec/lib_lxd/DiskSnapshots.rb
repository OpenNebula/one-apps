shared_examples_for "DiskSnapshots" do |livesnap|
    describe "Simple Cycle" do
        before(:all) do
            @defaults = RSpec.configuration.defaults

            # Used to pass info accross tests
            @info = {}

            # Use the same VM for all the tests in this example
            @info[:vm_id] = cli_create("onetemplate instantiate --hold '#{@defaults[:template]}'")
            @info[:vm]    = VM.new(@info[:vm_id])

            @info[:ds_id]     = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DATASTORE_ID']
            @info[:ds_driver] = DSDriver.get(@info[:ds_id])

            @info[:rootfs_disk_id] = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/IMAGE_ID']

            # Get image list
            @info[:image_list] = @info[:ds_driver].image_list
        end

        it "deploys" do
            cli_action("onevm release #{@info[:vm_id]}")
            @info[:vm].running?
        end

        it "ssh and context" do
            @info[:vm].reachable?
        end

        it "create datablock" do
            @info[:ds_id] = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DATASTORE_ID']
            prefix = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DEV_PREFIX']

            if (driver = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DRIVER'])
                @info[:datablock_opts] = "--format #{driver}"
            else
                @info[:datablock_opts] = ""
            end

#            cmd = "oneimage create --name snapshot_cycle_with_attach_detach_#{@info[:vm_id]} " <<
#                    "--size 100 --type datablock " <<
#                    "-d #{@info[:ds_id]} #{@info[:datablock_opts]} --prefix #{prefix}"

            cmd = "oneimage clone #{@info[:rootfs_disk_id]} snapshot_cycle_with_attach_detach_#{@info[:vm_id]}"

            img_id = cli_create(cmd)

            wait_loop(:success => "READY", :break => "ERROR") {
                xml = cli_action_xml("oneimage show -x #{img_id}")
                Image::IMAGE_STATES[xml['STATE'].to_i]
            }

            @info[:img_id] = img_id
            @info[:prefix] = prefix
        end

        it "poweroff" do
            @info[:vm].safe_poweroff
        end

        it "attach datablock" do
            img_id = @info[:img_id]
            cli_action("onevm disk-attach #{@info[:vm_id]} --image #{img_id} --prefix #{@info[:prefix]}")
            @info[:vm].state?("POWEROFF")

            disk_id = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{img_id}']/DISK_ID"].to_i
            expect(disk_id).to be > 0

            @info[:disk_id]   = disk_id

            # get target
            target = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{img_id}']/TARGET"]
            @info[:target] = target

        end

        it "resume" do
            cli_action("onevm resume #{@info[:vm_id]}")
            @info[:vm].running?
            @info[:vm].reachable?
        end

        ############################################################################
        # SNAP 1 - Poweroff
        ############################################################################

        it "write to datablock" do
            @info[:vm].ssh("echo s1 > /dev/#{@info[:target]}; sync")
        end

        it "poweroff" do
            @info[:vm].safe_poweroff
            @info[:vm].state?("POWEROFF")
        end

        it "create 1st snapshot (poweroff)" do
            cli_action("onevm disk-snapshot-create #{@info[:vm_id]} #{@info[:disk_id]} s1")
            @info[:vm].state?("POWEROFF")
        end

        it "resume" do
            cli_action("onevm resume #{@info[:vm_id]}")
            @info[:vm].running?
            @info[:vm].reachable?
        end

        ############################################################################
        # SNAP 2 - Suspend
        ############################################################################

        it "write to datablock" do
            @info[:vm].ssh("echo s2 > /dev/#{@info[:target]}; sync")
        end

        it "suspend" do
            #cli_action("onevm suspend #{@info[:vm_id]}")
            #@info[:vm].state?("SUSPENDED")
            @info[:vm].safe_poweroff
            @info[:vm].state?("POWEROFF")
        end

        #It says suspend but it is poweroff....again
        it "create 2nd snapshot (suspend)" do
            cli_action("onevm disk-snapshot-create #{@info[:vm_id]} #{@info[:disk_id]} s2")
            @info[:vm].state?("POWEROFF")
            #@info[:vm].state?("SUSPENDED")
        end

        it "resume" do
            cli_action("onevm resume #{@info[:vm_id]}")
            @info[:vm].running?
            @info[:vm].reachable?
        end

        ############################################################################
        # SNAP 3 - Running
        ############################################################################

        it "write to datablock" do
            @info[:vm].ssh("echo s3 > /dev/#{@info[:target]}; sync")
        end

        it "create 3rd snapshot" do
            @info[:vm].safe_poweroff #if !livesnap

            cli_action("onevm disk-snapshot-create #{@info[:vm_id]} #{@info[:disk_id]} s3")

            #if !livesnap
                @info[:vm].state?("POWEROFF")
                cli_action("onevm resume #{@info[:vm_id]}")
            #end

            @info[:vm].running?
            @info[:vm].reachable?
        end

        ############################################################################
        # SNAP Take more snapshots to test with delete
        ############################################################################

        it "create 4th snapshot (running)" do
            @info[:vm].safe_poweroff #if !livesnap

            cli_action("onevm disk-snapshot-create #{@info[:vm_id]} #{@info[:disk_id]} s4")

            #if !livesnap
                @info[:vm].state?("POWEROFF")
                cli_action("onevm resume #{@info[:vm_id]}")
            #end

            @info[:vm].running?
            @info[:vm].reachable?
        end

        it "create 5th snapshot (running)" do
            @info[:vm].safe_poweroff #if !livesnap

            cli_action("onevm disk-snapshot-create #{@info[:vm_id]} #{@info[:disk_id]} s5")

            #if !livesnap
                @info[:vm].state?("POWEROFF")
                cli_action("onevm resume #{@info[:vm_id]}")
            #end

            @info[:vm].running?
            @info[:vm].reachable?
        end

        it "create 6th snapshot (running)" do
            @info[:vm].safe_poweroff #if !livesnap

            cli_action("onevm disk-snapshot-create #{@info[:vm_id]} #{@info[:disk_id]} s6")

            #if !livesnap
                @info[:vm].state?("POWEROFF")
                cli_action("onevm resume #{@info[:vm_id]}")
            #end

            @info[:vm].running?
            @info[:vm].reachable?
        end

        ############################################################################
        # Revert 1 - Poweroff
        ############################################################################

        it "poweroff" do
            @info[:vm].safe_poweroff
        end

	it "create 7th snapshot (poweroff after running with snapshots)" do
            cli_action("onevm disk-snapshot-create #{@info[:vm_id]} #{@info[:disk_id]} s7")
            @info[:vm].state?("POWEROFF")
	end

        it "revert to 1st snap (poweroff)" do
            cli_action("onevm disk-snapshot-revert #{@info[:vm_id]} #{@info[:disk_id]} 0")
            @info[:vm].state?("POWEROFF")
        end

        it "resume" do
            cli_action("onevm resume #{@info[:vm_id]}")
            @info[:vm].running?
            @info[:vm].reachable?
        end

#        it "verify revert" do
#            cmd = @info[:vm].ssh("head -n1 /dev/#{@info[:target]}")
#            expect(cmd.stdout.strip).to eq("s1")
#        end

        ############################################################################
        # Revert 2 - Suspend
        ############################################################################

        it "suspend" do
            #cli_action("onevm suspend #{@info[:vm_id]}")
            #@info[:vm].state?("SUSPENDED")
            @info[:vm].safe_poweroff
            @info[:vm].state?("POWEROFF")
        end

        it "revert to 2nd snap (suspend)" do
            cli_action("onevm disk-snapshot-revert #{@info[:vm_id]} #{@info[:disk_id]} 1")
            #@info[:vm].state?("SUSPENDED")
            @info[:vm].state?("POWEROFF")
        end

        it "resume" do
            cli_action("onevm resume #{@info[:vm_id]}")
            @info[:vm].running?
            @info[:vm].reachable?
        end

#        it "verify revert" do
#            cmd = @info[:vm].ssh("head -n1 /dev/#{@info[:target]}")
#            expect(cmd.stdout.strip).to eq("s2")
#        end

        ############################################################################
        # Delete 6 - Running
        ############################################################################

        it "delete 7th snapshot (running)" do
            cli_action("onevm disk-snapshot-delete #{@info[:vm_id]} #{@info[:disk_id]} 6")
            @info[:vm].state?("RUNNING")
        end

        it "delete 6th snapshot (running)" do
            cli_action("onevm disk-snapshot-delete #{@info[:vm_id]} #{@info[:disk_id]} 5")
            @info[:vm].state?("RUNNING")
        end

        it "verify delete" do
            snapshots = []
            @info[:vm].xml.each('SNAPSHOTS/SNAPSHOT'){|s| snapshots << s.to_hash["SNAPSHOT"] }

            expect(snapshots.length).to eq(5)
            expect(snapshots[-1]["NAME"]).to eq("s5")
        end

        ############################################################################
        # Delete 5 - Suspended
        ############################################################################

        it "suspend" do
            #cli_action("onevm suspend #{@info[:vm_id]}")
            #@info[:vm].state?("SUSPENDED")
            @info[:vm].safe_poweroff
            @info[:vm].state?("POWEROFF")
        end

        it "delete 5th snapshot (suspended)" do
            cli_action("onevm disk-snapshot-delete #{@info[:vm_id]} #{@info[:disk_id]} 4")
            #@info[:vm].state?("SUSPENDED")
            @info[:vm].state?("POWEROFF")
        end

        it "verify delete" do
            snapshots = []
            @info[:vm].xml.each('SNAPSHOTS/SNAPSHOT'){|s| snapshots << s.to_hash["SNAPSHOT"] }

            expect(snapshots.length).to eq(4)
            expect(snapshots[-1]["NAME"]).to eq("s4")
        end

        it "resume" do
            cli_action("onevm resume #{@info[:vm_id]}")
            @info[:vm].running?
            @info[:vm].reachable?
        end

        ############################################################################
        # Delete 4 - Poweroff
        ############################################################################

        it "poweroff" do
            @info[:vm].safe_poweroff
        end

        it "delete 4th snapshot (poweroff)" do
            cli_action("onevm disk-snapshot-delete #{@info[:vm_id]} #{@info[:disk_id]} 3")
            @info[:vm].state?("POWEROFF")
        end

        it "verify delete" do
            snapshots = []
            @info[:vm].xml.each('SNAPSHOTS/SNAPSHOT'){|s| snapshots << s.to_hash["SNAPSHOT"] }

            expect(snapshots.length).to eq(3)
            expect(snapshots[-1]["NAME"]).to eq("s3")
        end

        ############################################################################
        # SNAP 4-7 - Poweroff
        ############################################################################

        it "create 4st snapshot (poweroff) again" do
            cli_action("onevm disk-snapshot-create #{@info[:vm_id]} #{@info[:disk_id]} s4")
            @info[:vm].state?("POWEROFF")
        end

        it "create 5st snapshot (poweroff) again" do
            cli_action("onevm disk-snapshot-create #{@info[:vm_id]} #{@info[:disk_id]} s5")
            @info[:vm].state?("POWEROFF")
        end

        it "create 6st snapshot (poweroff) again" do
            cli_action("onevm disk-snapshot-create #{@info[:vm_id]} #{@info[:disk_id]} s6")
            @info[:vm].state?("POWEROFF")
        end

        it "create 7st snapshot (poweroff) again" do
            cli_action("onevm disk-snapshot-create #{@info[:vm_id]} #{@info[:disk_id]} s7")
            @info[:vm].state?("POWEROFF")
        end

        it "resume" do
            cli_action("onevm resume #{@info[:vm_id]}")
            @info[:vm].running?
            @info[:vm].reachable?
        end

        ############################################################################
        # Delete VM
        ############################################################################

        it "terminate vm and delete datablock" do
            cli_action("onevm terminate --hard #{@info[:vm_id]}")
            @info[:vm].done?

            img_id = @info[:img_id]
            cli_action("oneimage delete #{img_id}")
            # wait for image to be deleted
            wait_loop(:success => true) {
                cmd = cli_action("oneimage show #{img_id} 2>/dev/null", nil)
                cmd.fail?
            }
        end

        it "datastore contents are unchanged" do
            # image epilog settles...
            sleep 10

            expect(DSDriver.get(@info[:ds_id]).image_list).to eq(@info[:image_list])
        end
    end

    # Tests the Disk Snapshot Operations on Persistent Images

    describe "Cycle with Persistent images" do
        before(:all) do
            @defaults = RSpec.configuration.defaults

            # Used to pass info accross tests
            @info = {}

            @info[:vm_id]   = cli_create("onetemplate instantiate --hold '#{@defaults[:template]}'")
            @info[:vm]      = VM.new(@info[:vm_id])

            @info[:ds_id]      = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DATASTORE_ID']
            @info[:ds_driver]  = DSDriver.get(@info[:ds_id])

            @info[:rootfs_disk_id] = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/IMAGE_ID']

            @info[:image_list] = @info[:ds_driver].image_list
        end

        it "deploys" do
            cli_action("onevm release #{@info[:vm_id]}")
            @info[:vm].running?
        end

        it "ssh and context" do
            @info[:vm].reachable?
        end

        it "create datablock" do
            @info[:ds_id] = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DATASTORE_ID']
            prefix = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DEV_PREFIX']

            if (driver = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DRIVER'])
                @info[:datablock_opts] = "--format #{driver}"
            else
                @info[:datablock_opts] = ""
            end

#            cmd = "oneimage create --name snapshot_cycle_with_attach_detach_#{@info[:vm_id]} " <<
#                    "--size 100 --type datablock " <<
#                    "-d #{@info[:ds_id]} #{@info[:datablock_opts]} --prefix #{prefix} " <<
#                    "--persistent"

            cmd = "oneimage clone #{@info[:rootfs_disk_id]} snapshot_cycle_with_attach_detach_#{@info[:vm_id]}"

            img_id = cli_create(cmd)

            wait_loop(:success => "READY", :break => "ERROR") {
                xml = cli_action_xml("oneimage show -x #{img_id}")
                Image::IMAGE_STATES[xml['STATE'].to_i]
            }

            @info[:img_id] = img_id
            @info[:prefix] = prefix
        end

        it "poweroff" do
            @info[:vm].safe_poweroff
        end

        it "attach datablock" do
            img_id = @info[:img_id]
            cli_action("onevm disk-attach #{@info[:vm_id]} --image #{img_id} --prefix #{@info[:prefix]}")
            @info[:vm].state?("POWEROFF")

            disk_id = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{img_id}']/DISK_ID"].to_i
            expect(disk_id).to be > 0

            @info[:disk_id]   = disk_id

            # get target
            target = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{img_id}']/TARGET"]
            @info[:target] = target
        end

        it "resume" do
            cli_action("onevm resume #{@info[:vm_id]}")
            @info[:vm].running?
            @info[:vm].reachable?
        end

        ############################################################################
        # Take 3 snapshots
        ############################################################################

        it "create snapshot" do
            data = "s1"
            @info[:vm].ssh("echo #{data} > /dev/#{@info[:target]}; sync")

            @info[:vm].safe_poweroff #if !livesnap

            cli_action("onevm disk-snapshot-create #{@info[:vm_id]} #{@info[:disk_id]} #{data}")

            #if !livesnap
                @info[:vm].state?("POWEROFF")
                cli_action("onevm resume #{@info[:vm_id]}")
            #end

            @info[:vm].running?
            @info[:vm].reachable?
        end

        it "create snapshot" do
            data = "s2"
            @info[:vm].ssh("echo #{data} > /dev/#{@info[:target]}; sync")

            @info[:vm].safe_poweroff #if !livesnap

            cli_action("onevm disk-snapshot-create #{@info[:vm_id]} #{@info[:disk_id]} #{data}")

            #if !livesnap
                @info[:vm].state?("POWEROFF")
                cli_action("onevm resume #{@info[:vm_id]}")
            #end

            @info[:vm].running?
            @info[:vm].reachable?
        end

        it "create snapshot" do
            data = "s3"
            @info[:vm].ssh("echo #{data} > /dev/#{@info[:target]}; sync")

            @info[:vm].safe_poweroff #if !livesnap

            cli_action("onevm disk-snapshot-create #{@info[:vm_id]} #{@info[:disk_id]} #{data}")

            #if !livesnap
                @info[:vm].state?("POWEROFF")
                cli_action("onevm resume #{@info[:vm_id]}")
            #end

            @info[:vm].running?
            @info[:vm].reachable?
        end

        ############################################################################
        # Shutdown VM
        ############################################################################

        it "terminate vm" do
            img_id = @info[:img_id]

            cli_action("onevm terminate --hard #{@info[:vm_id]}")
            @info[:vm].done?
        end

        ############################################################################
        # Keep snapshots in Datablock
        ############################################################################

        it "keeps snapshots in datablock" do
            img_id = @info[:img_id]

            xml = nil
            wait_loop(:success => "READY", :break => "ERROR") {
                xml = cli_action_xml("oneimage show -x #{img_id}")
                Image::IMAGE_STATES[xml['STATE'].to_i]
            }

            snapshots = []
            xml.each('SNAPSHOTS/SNAPSHOT') do |snap|
                snapshots << snap.to_hash["SNAPSHOT"]
            end

            allow_orphans = (['YES','yes'].include? xml['SNAPSHOTS/ALLOW_ORPHANS'])

###########This should work.....has to be checked.
#            expect(snapshots[0]["PARENT"]).to eq("-1")
#            expect(snapshots[0]["NAME"]).to eq("s1")
#
#            expect(snapshots[1]["PARENT"]).to eq(allow_orphans ? "-1" : "0")
#            expect(snapshots[1]["NAME"]).to eq("s2")
#
#            expect(snapshots[2]["PARENT"]).to eq(allow_orphans ? "-1" : "1")
#            expect(snapshots[2]["NAME"]).to eq("s3")
        end

        ############################################################################
        # Relaunch VM
        ############################################################################

        it "relaunch VM" do
            @info[:vm_id]   = cli_create("onetemplate instantiate '#{@defaults[:template]}'")
            @info[:vm]      = VM.new(@info[:vm_id])

            @info[:vm].running?
            @info[:vm].reachable?
        end

        it "attach datablock" do
            @info[:vm].safe_poweroff
            img_id = @info[:img_id]
            cli_action("onevm disk-attach #{@info[:vm_id]} --image #{img_id} --prefix #{@info[:prefix]}")
            @info[:vm].state?("POWEROFF")
        end

        ############################################################################
        # Verify Snapshots
        ############################################################################

######################This operation attaches a block that should have snapshots associated.
######################Miserably fails, snapshots don't exists. Might have to due to the fact
######################that disk now is the rootfs image instead of the datablock???? Unlikely
#        it "verify snapshot s1" do
#            cli_action("onevm disk-snapshot-revert #{@info[:vm_id]} #{@info[:disk_id]} 0")
#            @info[:vm].state?("POWEROFF")
#
#            cli_action("onevm resume #{@info[:vm_id]}")
#            @info[:vm].running?
#            @info[:vm].reachable?
#
#            #cmd = @info[:vm].ssh("head -n1 /dev/#{@info[:target]}")
#            #expect(cmd.stdout.strip).to eq("s1")
#
#            @info[:vm].safe_poweroff
#        end
#
#        it "verify snapshot s2" do
#            cli_action("onevm disk-snapshot-revert #{@info[:vm_id]} #{@info[:disk_id]} 1")
#            @info[:vm].state?("POWEROFF")
#
#            cli_action("onevm resume #{@info[:vm_id]}")
#            @info[:vm].running?
#            @info[:vm].reachable?
#
#            #cmd = @info[:vm].ssh("head -n1 /dev/#{@info[:target]}")
#            #expect(cmd.stdout.strip).to eq("s2")
#
#            @info[:vm].safe_poweroff
#        end
#
#        it "verify snapshot s3" do
#            cli_action("onevm disk-snapshot-revert #{@info[:vm_id]} #{@info[:disk_id]} 2")
#            @info[:vm].state?("POWEROFF")
#
#            cli_action("onevm resume #{@info[:vm_id]}")
#            @info[:vm].running?
#            @info[:vm].reachable?
#
#            #cmd = @info[:vm].ssh("head -n1 /dev/#{@info[:target]}")
#            #expect(cmd.stdout.strip).to eq("s3")
#
#            @info[:vm].safe_poweroff
#        end

        ############################################################################
        # Detach & Flatten & Attach & Verify
        ############################################################################

        it "detach snapshot" do
            cli_action("onevm disk-detach #{@info[:vm_id]} #{@info[:disk_id]}")
            @info[:vm].state?("POWEROFF")
        end

#########Mismo problema que arriba
#        it "flatten image" do
#            img_id = @info[:img_id]
#            cli_action("oneimage snapshot-flatten #{img_id} 0")
#
#            xml = nil
#            wait_loop(:success => "READY", :break => "ERROR") {
#                xml = cli_action_xml("oneimage show -x #{img_id}")
#                Image::IMAGE_STATES[xml['STATE'].to_i]
#            }
#
#            snapshots = xml["SNAPSHOTS"]
#            expect(snapshots).to be_empty
#        end

        it "attach snapshot" do
            img_id = @info[:img_id]
            cli_action("onevm disk-attach #{@info[:vm_id]} --image #{img_id} --prefix #{@info[:prefix]}")
            @info[:vm].state?("POWEROFF")
        end

        it "verify image" do
            cli_action("onevm resume #{@info[:vm_id]}")
            @info[:vm].running?
            @info[:vm].reachable?

            #cmd = @info[:vm].ssh("head -n1 /dev/#{@info[:target]}")
            #expect(cmd.stdout.strip).to eq("s1")
        end

        ############################################################################
        # Delete VM
        ############################################################################

        it "delete vm and datablock" do
            cli_action("onevm terminate --hard #{@info[:vm_id]}")
            @info[:vm].done?

            img_id = @info[:img_id]
            cli_action("oneimage delete #{img_id}")
            # wait for image to be deleted
            wait_loop(:success => true) {
                cmd = cli_action("oneimage show #{img_id} 2>/dev/null", nil)
                cmd.fail?
            }
        end

        it "datastore contents are unchanged" do
            # image epilog settles...
            sleep 10

            expect(DSDriver.get(@info[:ds_id]).image_list).to eq(@info[:image_list])
        end
    end
end
