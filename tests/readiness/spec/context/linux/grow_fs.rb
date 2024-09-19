###########################################################
#
# Main Tests
#

shared_examples_for 'context_linux_grow_fs' do |image, hv, prefix, context|
    include_examples 'context_linux', image, hv, prefix, <<~EOT
        #{context}
        CONTEXT=[
            GROW_FS="/mnt/disk_2 /mnt/disk_3",
            NETWORK="YES",
            SSH_PUBLIC_KEY=\"$USER[SSH_PUBLIC_KEY]\" ]
    EOT

    it 'poweroff' do
        # on ALT p9 the qemu-ga ?segfaults? and system services goes crazy
        if hv == 'KVM' && image =~ /^alt/
            @info[:vm].ssh('poweroff')
            @info[:vm].wait_no_ping

            if @info[:vm].state == 'RUNNING'
                # issue poweroff directly, but allow command to fail silently
                # as the state of VM can already change to POWEROFF by monitoring
                cli_action("onevm poweroff #{@info[:vm].id}", nil, true)
            end

            @info[:vm].state?('POWEROFF')
        else
            @info[:vm].safe_poweroff
        end
    end

    it 'attach two disks' do
        (2..3).each do |i|
            disk_template = TemplateParser.template_like_str(
                :disk => {
                    :size => 100,
                    :type => 'fs',
                    :dev_prefix => prefix,
                    :driver => 'raw'
                }
            )

            disk = Tempfile.new("disk_#{i}")
            disk.write(disk_template)
            disk.close

            cli_action("onevm disk-attach #{@info[:vm_id]} --file #{disk.path}")
            @info[:vm].state?('POWEROFF')

            disk.unlink
        end
    end

    it 'resume (required)' do
        @info[:vm].resume
    end

    it 'contextualized' do
        @info[:vm].wait_context
    end

    it 'mounts disk2 without partition (required)' do
        cmd = @info[:vm].ssh('mkdir -p /mnt/disk_2')
        expect(cmd.success?).to be(true)

        one_target = @info[:vm].xml['TEMPLATE/DISK[2]/TARGET']

        if image =~ /(freebsd)/i
            # silly transform Linux block device name to FreeBSD
            one_target = one_target.gsub(/^vd/, 'vtbd')
                                   .gsub(/^sd/, 'da')
                                   .gsub(/a$/, '0').gsub(/b$/, '1')
                                   .gsub(/c$/, '2').gsub(/d$/, '3')

            cmd = @info[:vm].ssh("newfs -U /dev/#{one_target}")
            expect(cmd.success?).to be(true)

            cmd = @info[:vm].ssh("echo /dev/#{one_target} /mnt/disk_2 ufs rw 1 1 >> /etc/fstab")
        else
            cmd = @info[:vm].ssh("mkfs.ext4 -F /dev/#{one_target}")
            expect(cmd.success?).to be(true)

            cmd = @info[:vm].ssh("blkid /dev/#{one_target}")
            expect(cmd.success?).to be(true)

            uuid = ''
            type = ''
            cmd.stdout.split(' ').each do |x|
                x = x.strip
                if x.start_with? 'UUID='
                    uuid = x
                elsif x.start_with? 'TYPE='
                    type = x
                end
            end
            expect(uuid.downcase).to match(/^uuid="?[[:alnum:]-]+"?$/)
            expect(type.downcase).to match(/^type="?ext4"?$/)

            cmd = @info[:vm].ssh("echo #{uuid} /mnt/disk_2 ext4 defaults 0 1 >> /etc/fstab")
        end
        expect(cmd.success?).to be(true)

        cmd = @info[:vm].ssh('mount -a')
        expect(cmd.success?).to be(true)
    end

    it 'mounts disk3 with partition (required)' do
        cmd = @info[:vm].ssh('mkdir -p /mnt/disk_3')
        expect(cmd.success?).to be(true)

        one_target = @info[:vm].xml['TEMPLATE/DISK[3]/TARGET']

        if image =~ /(freebsd)/i
            # silly transform Linux block device name to FreeBSD
            one_target = one_target.gsub(/^vd/, 'vtbd')
                                   .gsub(/^sd/, 'da')
                                   .gsub(/a$/, '0').gsub(/b$/, '1')
                                   .gsub(/c$/, '2').gsub(/d$/, '3')

            cmd = @info[:vm].ssh("gpart create -s GPT #{one_target}")
            expect(cmd.success?).to be(true)

            cmd = @info[:vm].ssh("gpart add -t freebsd-ufs -a 1M #{one_target}")
            expect(cmd.success?).to be(true)

            cmd = @info[:vm].ssh("newfs -U /dev/#{one_target}p1")
            expect(cmd.success?).to be(true)

            cmd = @info[:vm].ssh("echo /dev/#{one_target}p1 /mnt/disk_3 ufs rw 1 1 >> /etc/fstab")
        else
            cmd = @info[:vm].ssh("echo ';' | sfdisk /dev/#{one_target}")
            expect(cmd.success?).to be(true)

            cmd = @info[:vm].ssh("mkfs.ext4 -F /dev/#{one_target}1")
            expect(cmd.success?).to be(true)

            cmd = @info[:vm].ssh("blkid /dev/#{one_target}1")
            expect(cmd.success?).to be(true)

            uuid = ''
            type = ''
            cmd.stdout.split(' ').each do |x|
                x = x.strip
                if x.start_with? 'UUID='
                    uuid = x
                elsif x.start_with? 'TYPE='
                    type = x
                end
            end
            expect(uuid.downcase).to match(/^uuid="?[[:alnum:]-]+"?$/)
            expect(type.downcase).to match(/^type="?ext4"?$/)

            cmd = @info[:vm].ssh("echo #{uuid} /mnt/disk_3 ext4 defaults 0 1 >> /etc/fstab")
        end
        expect(cmd.success?).to be(true)

        cmd = @info[:vm].ssh('mount -a')
        expect(cmd.success?).to be(true)
    end

    it 'measures disk2 size' do
        @info[:disk2_size] = get_disk_size(@info[:vm], 2)
        expect(@info[:disk2_size]).to be > 0

        @info[:disk2_fs_size] = get_fs_size(@info[:vm], '/mnt/disk_2')
        expect(@info[:disk2_fs_size]).to be > 0
    end

    it 'measures disk3 size' do
        @info[:disk3_size] = get_disk_size(@info[:vm], 3)
        expect(@info[:disk3_size]).to be > 0

        @info[:disk3_fs_size] = get_fs_size(@info[:vm], '/mnt/disk_3')
        expect(@info[:disk3_fs_size]).to be > 0
    end

    it 'poweroff' do
        # on ALT p9 the qemu-ga ?segfaults? and system services goes crazy
        if image =~ /^alt/
            @info[:vm].ssh('poweroff')
            @info[:vm].wait_no_ping

            if @info[:vm].state == 'RUNNING'
                # issue poweroff directly, but allow command to fail silently
                # as the state of VM can already change to POWEROFF by monitoring
                cli_action("onevm poweroff #{@info[:vm].id}", nil, true)
            end

            @info[:vm].state?('POWEROFF')
        else
            @info[:vm].safe_poweroff
        end
    end

    it 'resize disk2' do
        s = (@info[:disk2_size] / (1024 * 1024)) + 1024
        cli_action("onevm disk-resize #{@info[:vm_id]} 2 #{s}")
        @info[:vm].state?('POWEROFF')
    end

    it 'resize disk3' do
        s = (@info[:disk3_size] / (1024 * 1024)) + 1024
        cli_action("onevm disk-resize #{@info[:vm_id]} 3 #{s}")
        @info[:vm].state?('POWEROFF')
    end

    it 'resume (required)' do
        @info[:vm].resume
    end

    it 'contextualized' do
        @info[:vm].wait_context
    end

    it 'has resized disk2 (required)' do
        new_disk_size = get_disk_size(@info[:vm], 2)
        expect(new_disk_size).to be > @info[:disk2_size]
        @info[:disk2_size] = new_disk_size
    end

    it 'has resized fs on disk2 (required)' do
        new_fs_size = get_fs_size(@info[:vm], '/mnt/disk_2')
        expect(new_fs_size).to be > @info[:disk2_fs_size]
        @info[:disk2_fs_size] = new_fs_size
    end

    it 'has resized disk3 (required)' do
        new_disk_size = get_disk_size(@info[:vm], 3)
        expect(new_disk_size).to be > @info[:disk3_size]
        @info[:disk3_size] = new_disk_size
    end

    it 'has resized fs on disk3 (required)' do
        new_fs_size = get_fs_size(@info[:vm], '/mnt/disk_3')
        expect(new_fs_size).to be > @info[:disk3_fs_size]
        @info[:disk3_fs_size] = new_fs_size
    end

    # live resize on vCenter and some legacy OSes requires reboot
    # (which would only repeat cold-resize tests above)
    if kvm?(hv) && !freebsd12?(image)
        context 'live resize' do
            it 'resize disk2' do
                size = (@info[:disk2_size] / (1024 * 1024)) + 2048
                cmd = "onevm disk-resize #{@info[:vm_id]} 2 #{size}"

                cli_action(cmd)
                @info[:vm].running?
            end

            it 'contextualized' do
                @info[:vm].wait_context
            end

            it 'has resized disk2 (required)' do
                size = get_disk_size(@info[:vm], 2)
                expect(size).to be > @info[:disk2_size]
            end

            it 'has resized fs on disk2 (required)' do
                size = get_fs_size(@info[:vm], '/mnt/disk_2')
                expect(size).to be > @info[:disk2_fs_size]
            end

            it 'resize disk3' do
                size = (@info[:disk3_size] / (1024 * 1024)) + 2048
                cmd = "onevm disk-resize #{@info[:vm_id]} 3 #{size}"

                cli_action(cmd)
                @info[:vm].running?
            end

            it 'contextualized' do
                @info[:vm].wait_context
            end

            it 'has resized disk3 (required)' do
                size = get_disk_size(@info[:vm], 3)
                expect(size).to be > @info[:disk3_size]
            end

            it 'has resized fs on disk3 (required)' do
                size = get_fs_size(@info[:vm], '/mnt/disk_3')
                expect(size).to be > @info[:disk3_fs_size]
            end
        end
    end
end
