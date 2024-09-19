require 'init'
require 'image'

DSDIR='/var/lib/one/datastores'

shared_examples_for 'replica_ops' do |persistent|

    before(:all) do
        @defaults = RSpec.configuration.defaults

        if persistent
            cloned_tmpl_name = "#{@defaults[:template]}-pers-cloned"

            if cli_action("onetemplate show '#{cloned_tmpl_name}' >/dev/null", nil).fail?
                cli_create("onetemplate clone --recursive " \
                           "#{@defaults[:template]} '#{cloned_tmpl_name}'")

                wait_image_ready(300, "#{cloned_tmpl_name}-disk-0")
                cli_action("oneimage persistent #{cloned_tmpl_name}-disk-0")
            end

            @tmpl = cloned_tmpl_name
        else
            @tmpl = @defaults[:template]
        end


        @info = {}

        @info[:replica] = @defaults[:replica]
        fail "Missing :replica in defaults.yaml" if @info[:replica].nil?

        @info[:img_name] = cli_action_xml("onetemplate show -x '#{@tmpl}'")['TEMPLATE/DISK/IMAGE_ID'] \
            || cli_action_xml("onetemplate show -x '#{@tmpl}'")['TEMPLATE/DISK/IMAGE']

        @info[:img_file] = cli_action_xml(
            "oneimage show -x #{@info[:img_name]}")['SOURCE'].split('/').last

        @info[:img_ds_id] = cli_action_xml(
             "oneimage show -x '#{@info[:img_name]}'")['DATASTORE_ID']

        SafeExec.run(
            "ssh '#{@info[:replica]}' " \
            "\"find #{DSDIR}/#{@info[:img_ds_id]}/* -delete\" 2>/dev/null")
    end

    after(:all) do
        SafeExec.run(
            "ssh '#{@defaults[:hosts][0]}' " \
            "\"find #{DSDIR}/#{@info[:img_ds_id]}/* -delete\" 2>/dev/null")

        SafeExec.run(
            "ssh '#{@defaults[:hosts][1]}' " \
            "\"find #{DSDIR}/#{@info[:img_ds_id]}/* -delete\" 2>/dev/null")

        SafeExec.run("oneimage delete rs-dtblk")
        SafeExec.run("onetemplate delete #{@info[:tmplrs]}")

        if persistent
            SafeExec.run("onetemplate delete #{@tmpl} --recursive")
        end
    end

     it "Deploys, terminates" do
         @info[:vm_id] = cli_create("onetemplate instantiate #{@tmpl}")
         @info[:vm] = VM.new(@info[:vm_id])
         @info[:vm].running?

         cmd = SafeExec.run(
             "ssh '#{@info[:replica]}' " \
             "ls #{DSDIR}/#{@info[:img_ds_id]}/")
         expect(cmd.stdout.split).to eq(
             ["#{@info[:img_file]}","#{@info[:img_file]}.md5sum"])

         cli_action("onevm terminate --hard #{@info[:vm_id]}")
         @info[:vm].done?
     end

     it "Overwrite *.md5sum on replica and deploys" do
         cmd = SafeExec.run(
             "ssh '#{@info[:replica]}' " \
             "'echo nonsense > " \
             "#{DSDIR}/#{@info[:img_ds_id]}/#{@info[:img_file]}.md5sum '")
         expect(cmd.success?).to be(true)

         cmd = SafeExec.run(
             "ssh '#{@info[:replica]}' " \
             "ls #{DSDIR}/#{@info[:img_ds_id]}/")
         expect(cmd.stdout.split).to eq(
             ["#{@info[:img_file]}","#{@info[:img_file]}.md5sum"])

         @info[:vm_id] = cli_create("onetemplate instantiate '#{@tmpl}'")
         @info[:vm] = VM.new(@info[:vm_id])
         @info[:vm].running?

         cli_action("onevm terminate --hard #{@info[:vm_id]}")
         @info[:vm].done?
     end

     it "Deletes images on replica, keeps .md5sum, deploy, boot fails" do

         cmd = SafeExec.run(
             "ssh '#{@info[:replica]}' " \
             "\"find #{DSDIR}/#{@info[:img_ds_id]}/ " \
             "    -type f -regex '.*/[a-f0-9]*' -delete\"")

         @info[:vm_id] = cli_create("onetemplate instantiate '#{@tmpl}'")
         @info[:vm]    = VM.new(@info[:vm_id])

         @info[:vm].state?('PROLOG_FAILURE', /RUNNING/)

         cli_action("onevm terminate --hard #{@info[:vm_id]}")

         @info[:vm].done?

         if persistent
             # VM failure swithces persistent img to failed, revert it
             cli_action("oneimage enable #{@info[:img_name]}")
             CLIImage.new(@info[:img_name]).ready?
         end
     end

     it "Deletes *.md5sum on replica and deploys" do
         cmd = SafeExec.run(
             "ssh '#{@info[:replica]}' " \
             "\"find #{DSDIR}/#{@info[:img_ds_id]}/ " \
             "    -type f -name '*.md5sum*' -delete\"")

         @info[:vm_id] = cli_create("onetemplate instantiate '#{@tmpl}'")
         @info[:vm] = VM.new(@info[:vm_id])
         @info[:vm].running?

         cmd = SafeExec.run(
             "ssh '#{@info[:replica]}' " \
             "ls #{DSDIR}/#{@info[:img_ds_id]}/")
         expect(cmd.stdout.split).to eq(
             ["#{@info[:img_file]}","#{@info[:img_file]}.md5sum"])

         cli_action("onevm terminate --hard #{@info[:vm_id]}")
         @info[:vm].done?
     end

     it "Changes REPLICA_HOST to 2nd host and deploys" do
         cli_update("onedatastore update system", <<-EOT, false)
             ALLOW_ORPHANS="yes"
             DISK_TYPE="FILE"
             DS_MIGRATE="YES"
             REPLICA_HOST="#{@defaults[:hosts][1]}"
             RESTRICTED_DIRS="/"
             SAFE_DIRS="/var/tmp /tmp"
             SHARED="NO"
             TM_MAD="ssh"
             TYPE="SYSTEM_DS"
         EOT

         @info[:vm_id] = cli_create("onetemplate instantiate '#{@tmpl}'")
         @info[:vm] = VM.new(@info[:vm_id])
         @info[:vm].running?

         cmd = SafeExec.run(
             "ssh '#{@defaults[:hosts][1]}' " \
             "ls #{DSDIR}/#{@info[:img_ds_id]}/")
         expect(cmd.stdout.split).to eq(
             ["#{@info[:img_file]}","#{@info[:img_file]}.md5sum"])

         cli_action("onevm terminate --hard #{@info[:vm_id]}")
         @info[:vm].done?
     end

     it "Changes REPLICA_HOST back to 1st host" do
         cli_update("onedatastore update system", <<-EOT, false)
             ALLOW_ORPHANS="yes"
             DISK_TYPE="FILE"
             DS_MIGRATE="YES"
             REPLICA_HOST="#{@defaults[:hosts][0]}"
             RESTRICTED_DIRS="/"
             SAFE_DIRS="/var/tmp /tmp"
             SHARED="NO"
             TM_MAD="ssh"
             TYPE="SYSTEM_DS"
         EOT

     end

    it "Create datablock and template" do
        if SafeExec.run("oneimage show rs-dtblk").success?
            @info[:img_id] = cli_action_xml("oneimage show -x rs-dtblk")['ID']
        else
            img_tmpl = <<-EOF
                NAME   = rs-dtblk
                TYPE   = DATABLOCK
                SIZE   = 100
                FORMAT = qcow2
            EOF

            @info[:img_id] = cli_create("oneimage create -d #{@info[:img_ds_id]}", img_tmpl)
            cli_action("oneimage persistent rs-dtblk") if persistent

            wait_loop(:success => "READY", :break => "ERROR") {
                xml = cli_action_xml("oneimage show -x #{@info[:img_id]}")
                Image::IMAGE_STATES[xml['STATE'].to_i]
            }
        end

        @info[:tmplrs] = "#{@tmpl}-recovery-snaps"
        if SafeExec.run("onetemplate show #{@info[:tmplrs]}").success?
            @info[:tmpl_id] = cli_action_xml("onetemplate show -x #{@info[:tmplrs]}")['ID']
        else
            @info[:tmpl_id] = cli_create(
                "onetemplate clone '#{@tmpl}' '#{@info[:tmplrs]}'")

            newtmpl = cli_action_xml("onetemplate show -x \"#{@info[:tmplrs]}\"")
                .template_str << " DISK = [ IMAGE=\"rs-dtblk\", RECOVERY_SNAPSHOT_FREQ=60, FORMAT=\"qcow2\" ]"

            cli_update("onetemplate update '#{@info[:tmplrs] = "#{@tmpl}-recovery-snaps"}'", newtmpl, true)
        end
    end

    it 'Deploys' do
        @info[:vm_id] = cli_create("onetemplate instantiate '#{@info[:tmplrs] = "#{@tmpl}-recovery-snaps"}'")
        @info[:vm] = VM.new(@info[:vm_id])
        @info[:vm].running?
    end

    it 'Writes to datablock' do
        @info[:target] = @info[:vm].xml["TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id]}']/TARGET"]
        wait_loop do
            @info[:vm].ssh("test -b /dev/#{@info[:target]}").success?
        end

        @info[:vm].ssh("echo IMAGE_CHECK_1 > /dev/#{@info[:target]}; sync")
        cmd = @info[:vm].ssh("timeout 10 head -n1 /dev/#{@info[:target]}")
    end

    it 'Waits for recovery snapshot' do
        SafeExec.run(
            "ssh '#{@info[:replica]}' " \
            "\"rm -rf #{DSDIR}/replica_snaps/#{@info[:vm_id]}/disk.1.snap/base.1\"")

        wait_loop(:timeout => 150) do
            cmd =SafeExec.run(
                "ssh '#{@info[:replica]}' " \
                "\"ls #{DSDIR}/replica_snaps/#{@info[:vm_id]}/disk.1.snap/base.1\" 2>/dev/null")
            cmd.success?
        end
    end

    it "Recreate VM" do
        cli_action("onevm recover --recreate #{@info[:vm_id]}")
        @info[:vm].state?("RUNNING")
        @info[:vm].reachable?
    end

    it "Verify datablock" do
        cmd = @info[:vm].ssh("timeout 10 head -n1 /dev/#{@info[:target]}")
        expect(cmd.stdout.strip).to eq("IMAGE_CHECK_1")
    end

    it "Creates user disk-snapshot (live)" do
         cli_action("onevm disk-snapshot-create #{@info[:vm_id]} 1 snap1")
        @info[:vm].state?("RUNNING")
    end

    it "Rewrite the datablock" do
        wait_loop do
            @info[:vm].ssh("test -b /dev/#{@info[:target]}").success?
        end

        @info[:vm].ssh("echo IMAGE_CHECK_2 > /dev/#{@info[:target]}; sync")
        cmd = @info[:vm].ssh("timeout 10 head -n1 /dev/#{@info[:target]}")
    end

    it 'Poweroff' do
        @info[:vm].safe_poweroff
    end

    it 'Revert to user snapshot' do
        cli_action("onevm disk-snapshot-revert #{@info[:vm_id]} 1 snap1")
        @info[:vm].state?("POWEROFF")
    end

    it "Resume" do
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it "Verify datablock" do
        cmd = @info[:vm].ssh("timeout 10 head -n1 /dev/#{@info[:target]}")
        expect(cmd.stdout.strip).to eq("IMAGE_CHECK_1")
    end

    it "Rewrite the datablock" do
        wait_loop do
            @info[:vm].ssh("test -b /dev/#{@info[:target]}").success?
        end

        @info[:vm].ssh("echo IMAGE_CHECK_3 > /dev/#{@info[:target]}; sync")
        cmd = @info[:vm].ssh("timeout 10 head -n1 /dev/#{@info[:target]}")
    end

    it 'Waits for recovery snapshot' do
        SafeExec.run(
            "ssh '#{@info[:replica]}' " \
            "\"rm -rf #{DSDIR}/replica_snaps/#{@info[:vm_id]}/disk.1.snap/base.1\"")

        wait_loop(:timeout => 150) do
            cmd =SafeExec.run(
                "ssh '#{@info[:replica]}' " \
                "\"ls #{DSDIR}/replica_snaps/#{@info[:vm_id]}/disk.1.snap/base.1\" 2>/dev/null")
            cmd.success?
        end
    end

    it "Recreate VM" do
        cli_action("onevm recover --recreate #{@info[:vm_id]}")
        @info[:vm].state?("RUNNING")
        @info[:vm].reachable?
    end

    it "Verify datablock" do
        cmd = @info[:vm].ssh("head -n1 /dev/#{@info[:target]}")
        expect(cmd.stdout.strip).to eq("IMAGE_CHECK_3")
    end

    it "Delete vm and datablock" do
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

    it "Monitors replica cache" do
        xml = ''
        path = "HOST_SHARE/DATASTORES/DS[ID=#{@info[:img_ds_id]}]"

        # it could take a while until the host is monitored
        wait_loop(:success => 'YES', :break => 'ERROR',:timeout => 600) do

            xml = cli_action_xml("onehost show -x #{@info[:replica]}")
            xml["#{path}/REPLICA_CACHE"]
        end

        expect(xml["#{path}/REPLICA_CACHE_SIZE"].empty?).to be(false)
        expect(xml["#{path}/REPLICA_IMAGES"].empty?).to be(false)
    end
end
