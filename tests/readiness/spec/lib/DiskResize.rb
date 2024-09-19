module DiskResize

    # TODO: Return output in MB. Add an options = {:unit} to default to MB =>>> / (1024 * 1024)
    def get_disk_size(vm, id = 0)
        target = vm.xml["TEMPLATE/DISK[DISK_ID=\"#{id}\"]/TARGET"]
        vm_mad = vm.xml['HISTORY_RECORDS/HISTORY[last()]/VM_MAD']

        # LXD
        if vm_mad.upcase == 'LXD'
            # LXD does not support disk id
            raise "Disk ID='#{id}' is not supported on LXD" unless id == 0

            # TODO: sync with 'get_disk_size' from spec/lib_lxd/DiskResize.rb
            cmd = vm.ssh('lsblk -bno pkname,size,mountpoint')

            # set the correct 'target'
            if cmd.success?
                target = %r{.*/$}.match(cmd.stdout).to_s.split[0]
            else
                # workaround for ubuntu 14 and similarly old distros
                cmd = vm.ssh('lsblk -bno kname,size,mountpoint')
                if cmd.success?
                    partname = %r{.*/$}.match(cmd.stdout).to_s.split[0]
                    if partname =~ /.*p[0-9]+$/
                        target = partname.gsub(/p[0-9]+$/, '')
                    elsif partname =~ /[0-9]+$/
                        target = partname.gsub(/[0-9]+$/, '')
                    else
                        target = partname
                    end
                end
            end
        end

        # Linux
        if vm.ssh("test -d /sys/block/#{target}/").success?
            cmd = "echo \\$(cat /sys/block/#{target}/queue/physical_block_size) " <<
                "\\$(cat /sys/block/#{target}/size)"

            cmd = vm.ssh(cmd)
            bs, sectors = cmd.stdout.strip.split(' ')
            return bs.to_i * sectors.to_i
        end

        # FreeBSD, translate target devices
        # TODO: not sure about sd/hd
        case target
        when /^vd([a-z])$/
            target = 'vtbd' + (::Regexp.last_match(1)[0].ord - 'a'.ord).to_s

        when /^sd([a-z])$/
            target = 'da' + (::Regexp.last_match(1)[0].ord - 'a'.ord).to_s

        when /^hd([a-z])$/
            target = 'ad' + (::Regexp.last_match(1)[0].ord - 'a'.ord).to_s
        end

        cmd = vm.ssh("diskinfo /dev/#{target}")
        if cmd.success?
            return cmd.stdout.strip.split("\t")[2].to_i
        end

        -1
    end

    # TODO: Return output in MB. Add an options = {:unit} to default to MB =>>> / (1024 * 1024)
    def get_fs_size(vm, fs = '/')
        cmd = vm.ssh("df -P #{fs} | sed 1d | awk '{ print \\$2 }'")
        cmd.stdout.strip.to_i
    end

    def again(expected, times = 10)
        value = nil

        while times > 0
            value = yield
            break if value == expected

            times -= 1
            sleep 1
        end

        value
    end

end
