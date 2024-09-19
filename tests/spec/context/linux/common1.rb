###########################################################
#
# Main Tests
#

shared_examples_for 'context_linux_common1' do |image, hv, prefix, context|
    include_examples 'context_linux', image, hv, prefix, <<~EOT
        #{context}
        FEATURES=[
          GUEST_AGENT="yes"]
        CONTEXT=[
          ETH0_ROUTES="8.8.4.4/32 via 192.168.150.2, 1.0.0.1/32 via 192.168.150.2",
          NETWORK="YES",
          SSH_PUBLIC_KEY="\$USER[SSH_PUBLIC_KEY]",
          START_SCRIPT="echo ok >/tmp/start_script1;
        echo ok >/tmp/start_script2;
        echo ok >>/tmp/start_script3
        ",
          TOKEN="YES",
          VROUTER_ID="255",
          REPORT_READY="YES",
          USERNAME_PASSWORD_RESET="YES"]
    EOT

    it 'generated new instance unique files' do
        # new SSH host keys
        if @info[:vm].ssh('test -d /etc/ssh/').success?
            cmd = "find /etc/ssh/ -name 'ssh_host_\*' ! -mmin -10"
            cmd = @info[:vm].ssh(cmd)
            expect(cmd.success?).to be(true)
            expect(cmd.stdout.strip).to be_empty, cmd.stdout.strip
        end

        if @info[:vm].ssh('test -d /etc/openssh/').success?
            cmd = "find /etc/openssh/ -name 'ssh_host_\*' ! -mmin -10"
            cmd = @info[:vm].ssh(cmd)
            expect(cmd.success?).to be(true)
            expect(cmd.stdout.strip).to be_empty, cmd.stdout.strip
        end

        # new/updated machine-id
        cmd = "find /etc/ -maxdepth 1 -name 'machine-id' ! -mmin -10 -a ! -size 0"
        cmd = @info[:vm].ssh(cmd)
        expect(cmd.success?).to be(true)
        expect(cmd.stdout.strip).to be_empty
    end

    it 'ssh fails for user with password' do
        ssh_opts = '-o StrictHostKeyChecking=no ' \
                   '-o UserKnownHostsFile=/dev/null ' \
                   '-o PasswordAuthentication=yes ' \
                   '-o PubkeyAuthentication=no'

        cmd = "sshpass -p 6be4AO@ld ssh #{ssh_opts} root@#{@info[:vm].ip} \"echo\" 2>/dev/null"
        cmd = SafeExec.run(cmd)
        expect(cmd.success?).to be(false)
    end

    it 'has installed qemu-ga' do
        skip_freebsd(image)
        skip_amazon2023(image)
        out = @info[:vm].ssh('qemu-ga --version').stdout.strip
        expect(out).to match(/^QEMU Guest Agent/i)
    end

    it 'has qemu-ga running' do
        skip_freebsd(image)
        skip_amazon2023(image)
        kvm_only(hv)

        cmd = @info[:vm].ssh('pidof qemu-ga')
        cmd = @info[:vm].ssh('pgrep qemu-ga') unless cmd.success?
        expect(cmd.success?).to be(true)
    end

    it 'has installed vmtoolsd' do
        cmd = 'which vmtoolsd'
        cmd = @info[:vm].ssh(cmd)
        expect(cmd.success?).to be(true)
    end

    it 'has vmtoolsd running' do
        vcenter_only(hv)
        skip_freebsd(image)

        cmd = @info[:vm].ssh('pidof vmtoolsd')
        cmd = @info[:vm].ssh('pgrep vmtoolsd') unless cmd.success?
        expect(cmd.success?).to be(true)
    end

    it 'runs START_SCRIPT' do
        out = @info[:vm].ssh('cat /tmp/start_script1').stdout.strip
        expect(out).to eq('ok')
        out = @info[:vm].ssh('cat /tmp/start_script2').stdout.strip
        expect(out).to eq('ok')
        out = @info[:vm].ssh('cat /tmp/start_script3').stdout.strip
        expect(out).to eq('ok')
    end

    it "doesn't have kernel serial console" do
        skip_containers(hv)

        cmd = @info[:vm].ssh('cat /proc/cmdline')
        if cmd.success?
            expect(cmd.stdout).not_to match(/=ttyS/)
        else
            cmd = @info[:vm].ssh('sysctl -n kern.console')
            expect(cmd.success?).to be(true)
            expect(cmd.stdout).not_to match(/ttyu\d/)
        end
    end

    it 'has UTC timezone' do
        out = @info[:vm].ssh("date '+%Z'").stdout.strip
        expect(out).to eq('UTC')
    end

    it 'resolves machines' do
        @defaults[:resolve_names].each do |name|
            cmd = @info[:vm].ssh("nslookup #{name}")
            cmd = @info[:vm].ssh("host -v #{name}") if cmd.fail?

            if cmd.fail?
                puts cmd.stdout
                puts cmd.stderr
            end

            expect(cmd.success?).to be(true)
        end
    end

    it 'sets custom password for root' do
        # detect shadow file
        cmd = @info[:vm].ssh('find /etc/tcb/root/shadow /etc/shadow /etc/master.passwd')
        @info[:file_shadow] = cmd.stdout.strip.split("\n")[0]
        expect(@info[:file_shadow]).not_to be_nil
        expect(@info[:file_shadow]).not_to be_empty

        # directly hack password and validate
        cmd = @info[:vm].ssh("sed -i -e 's/^\\(root\\):[^:]*/\\1:password/' #{@info[:file_shadow]}")
        expect(cmd.success?).to be(true)
        cmd = @info[:vm].ssh("grep '^root:password:' #{@info[:file_shadow]}")
        expect(cmd.success?).to be(true)
    end

    it 'measures disk size' do
        @info[:disk_size] = get_disk_size(@info[:vm])
        expect(@info[:disk_size]).to be > 0

        @info[:rootfs_size] = get_fs_size(@info[:vm])
        expect(@info[:rootfs_size]).to be > 0
    end

    include_examples 'context_linux_network_common', image, hv

    it 'refresh bootloader' do
        skip_containers(hv)
        nosup_os(image) if image =~ /(centos6|debian8|alpine|freebsd)/i
        nosup_os(image) if image =~ /service_VRouter/i

        cmd = @info[:vm].ssh('update-grub2')
        cmd = @info[:vm].ssh('update-bootloader --refresh') if cmd.fail?

        if cmd.fail?
            # detect configuration file
            cmd = 'ls -1 /boot/grub/grub.cfg /boot/grub2/grub.cfg /boot/efi/EFI/redhat/grub.cfg'
            cmd = @info[:vm].ssh(cmd)
            grub_cfg = cmd.stdout.strip.split("\n")[0]
            expect(grub_cfg).not_to be_nil
            expect(grub_cfg).not_to be_empty

            # refresh configuration
            cmd = @info[:vm].ssh("grub2-mkconfig -o #{grub_cfg} || grub-mkconfig -o #{grub_cfg}")
        end

        expect(cmd.success?).to be(true)
    end

    it 'poweroff' do
        # on ALT p9 the qemu-ga ?segfaults? and system services goes crazy
        if image =~ /^alt9/
            @info[:vm].ssh('poweroff')
            @info[:vm].state?('POWEROFF')
        else
            @info[:vm].safe_poweroff
        end
    end

    it 'resume after refreshing bootloader' do
        @info[:vm].resume
    end

    it 'contextualized' do
        @info[:vm].wait_context
    end

    it "doesn't have kernel serial console after reboot" do
        skip_containers(hv)

        cmd = @info[:vm].ssh('cat /proc/cmdline')
        if cmd.success?
            expect(cmd.stdout).not_to match(/=ttyS/)
        else
            cmd = @info[:vm].ssh('sysctl -n kern.console')
            expect(cmd.success?).to be(true)
            expect(cmd.stdout).not_to match(/ttyu\d/)
        end
    end

    it 'reset root password' do
        cmd = @info[:vm].ssh("grep '^root:\\*:' #{@info[:file_shadow]}")
        expect(cmd.success?).to be(true)
    end

    it 'break the time' do
        skip_containers(hv)

        sync = `grep -i sync_time=yes /var/lib/one/remotes/etc/vmm/kvm/kvmrc`.strip
        skip 'Sync time not enabled' if sync.empty?

        # First (Linux) date might fail, the second one should
        # provide exit code 2 if time was set. We better check
        # time inside VM, instead of depending on exit codes.
        cmd = @info[:vm].ssh('date -s 1995-04-13')
        @info[:vm].ssh('date 199504130000') if cmd.fail?

        cmd = @info[:vm].ssh('date +%Y-%m-%d')
        expect(cmd.success?).to be(true)
        expect(cmd.stdout.strip).to eq('1995-04-13')
    end

    it 'suspend' do
        skip_containers(hv)

        sync = `grep -i sync_time=yes /var/lib/one/remotes/etc/vmm/kvm/kvmrc`.strip
        skip 'Sync time not enabled' if sync.empty?

        cli_action("onevm suspend #{@info[:vm_id]}")
        @info[:vm].state?('SUSPENDED')
    end

    it 'resume' do
        skip_containers(hv)

        sync = `grep -i sync_time=yes /var/lib/one/remotes/etc/vmm/kvm/kvmrc`.strip
        skip 'Sync time not enabled' if sync.empty?

        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it 'check time has changed' do
        skip_containers(hv)
        nosup_os(image) if image =~ /(freebsd|min)/i

        sync = `grep -i sync_time=yes /var/lib/one/remotes/etc/vmm/kvm/kvmrc`.strip
        skip 'Sync time not enabled' if sync.empty?

        wait_loop(:timeout => 30) do
            break if @info[:vm].ssh('TZ=UTC date +%Y-%m-%d').stdout.strip != '1995-04-13'
        end

        c_date = Time.now.strftime('%Y-%m-%d')

        expect(@info[:vm].ssh('date +%Y-%m-%d').stdout.strip).not_to eq('1995-04-13')
        expect(@info[:vm].ssh('date +%Y-%m-%d').stdout.strip).to eq(c_date)
    end

    it 'poweroff' do
        @info[:vm].poweroff
    end

    it 'attach swap' do
        kvm_only(hv)

        disk_swap_template = TemplateParser.template_like_str(
            :disk => {
                :size => 100,
                :type => 'swap',
                :dev_prefix => 'vd', # TODO
                :driver => 'raw'
            }
        )

        disk_swap = Tempfile.new('disk_swap')
        disk_swap.write(disk_swap_template)
        disk_swap.close

        cli_action("onevm disk-attach #{@info[:vm_id]} --file #{disk_swap.path}")
        @info[:vm].state?('POWEROFF')

        disk_swap.unlink
    end

    it 'resume after attaching a swap disk' do
        @info[:vm].resume
    end

    it 'contextualized' do
        @info[:vm].wait_context
    end

    it 'activates all swap(s)' do
        kvm_only(hv)
        skip_freebsd(image)

        # detect swap partitions
        blkid = 'blkid -t TYPE=swap -o device'
        cmd = @info[:vm].ssh("#{blkid}| xargs realpath")
        cmd = @info[:vm].ssh(blikid) if cmd.fail?
        expect(cmd.success?).to be(true)
        swaps = cmd.stdout.strip.split.sort
        expect(swaps.size).to be >= 1

        # check activated swaps
        cmd = "cat /proc/swaps | awk '\\$1!~/Filename/ { print \\$1 }'"
        active_swaps = @info[:vm].ssh(cmd).stdout.strip.split.sort
        expect(active_swaps.size).to be >= 1
        expect(active_swaps).to match_array(swaps)

        # get swap size
        cmd = "free -m | grep Swap | awk '{ print \\$2 }'"
        @info[:swap_size] = @info[:vm].ssh(cmd).stdout.strip.to_i
        expect(@info[:swap_size]).to be >= 1
    end

    it 'hot attach swap' do
        kvm_only(hv)

        disk_swap_template = TemplateParser.template_like_str(
            :disk => {
                :size => 100,
                :type => 'swap',
                :dev_prefix => 'vd', # TODO
                :driver => 'raw'
            }
        )

        disk_swap = Tempfile.new('disk_swap')
        disk_swap.write(disk_swap_template)
        disk_swap.close

        cli_action("onevm disk-attach #{@info[:vm_id]} --file #{disk_swap.path}")
        @info[:vm].running?

        disk_swap.unlink
    end

    it 'contextualized' do
        @info[:vm].wait_context
    end

    it 'guest activated swap' do
        kvm_only(hv)
        skip_freebsd(image)

        cmd = "free -m | grep Swap | awk '{ print \\$2 }'"
        size = @info[:vm].ssh(cmd).stdout.strip.to_i
        expect(size).to be > @info[:swap_size]
    end

    it 'poweroff' do
        @info[:vm].poweroff
    end

    it 'resize disk' do
        s = @info[:disk_size] / (1024 * 1024) + 1024
        cli_action("onevm disk-resize #{@info[:vm_id]} 0 #{s}")

        @info[:vm].state?('DISK_RESIZE_POWEROFF')
        @info[:vm].state?('POWEROFF')
    end

    it 'resume after resize' do
        @info[:vm].resume
    end

    it 'contextualized' do
        @info[:vm].wait_context
    end

    it 'guest resized disk' do
        skip_containers(hv)
        skip_freebsd(image) # https://github.com/OpenNebula/addon-context-linux/issues/298

        new_disk_size = get_disk_size(@info[:vm])
        expect(new_disk_size).to be > @info[:disk_size]
        @info[:disk_size] = new_disk_size
    end

    it 'guest resized rootfs' do
        skip_containers(hv)
        skip_freebsd(image) # https://github.com/OpenNebula/addon-context-linux/issues/298

        new_rootfs_size = get_fs_size(@info[:vm])
        expect(new_rootfs_size).to be > @info[:rootfs_size]
        @info[:rootfs_size] = new_rootfs_size
    end

    it 'live resize disk' do
        kvm_only(hv)

        s = (@info[:disk_size] / (1024 * 1024)) + 2048
        cli_action("onevm disk-resize #{@info[:vm_id]} 0 #{s}")
        @info[:vm].running?
    end

    it 'contextualized' do
        @info[:vm].wait_context
    end

    it 'guest resized disk' do
        kvm_only(hv)
        skip_freebsd(image) # https://github.com/OpenNebula/addon-context-linux/issues/298

        expect(get_disk_size(@info[:vm])).to be > @info[:disk_size]
    end

    it 'guest resized rootfs' do
        kvm_only(hv)
        skip_freebsd(image) # https://github.com/OpenNebula/addon-context-linux/issues/298

        expect(get_fs_size(@info[:vm])).to be > @info[:rootfs_size]
    end
end
