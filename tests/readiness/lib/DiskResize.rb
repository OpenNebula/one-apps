module DiskResize

    # TODO: Return output in MB. Add an options = {:unit} to default to MB =>>> / (1024 * 1024)
    def get_disk_size(vm, id = 0)
        target = vm.xml["TEMPLATE/DISK[DISK_ID=\"#{id}\"]/TARGET"]
        vm_mad = vm.xml['HISTORY_RECORDS/HISTORY[last()]/VM_MAD']

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
