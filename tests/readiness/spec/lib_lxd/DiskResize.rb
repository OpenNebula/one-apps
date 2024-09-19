module DiskResize

    def get_disk_size(vm)
        cmd = "lsblk -b | grep '/$' | awk '{print \\$4}'"
        cmd = vm.ssh(cmd)

        if cmd.success?
            size_in_bytes = cmd.stdout.to_i
            return size_in_bytes
        end

        -1
    end

    def get_fs_size(vm)
        cmd = vm.ssh("df -P / | sed 1d | awk '{ print \\$2 }'")
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

    # Check if host can resize ext4 filesystem.
    # Checks for particular u1604 version which cannot resize
    def ext4_resize?
        # e2fsck not in path
        cmd = 'export PATH=/sbin:$PATH ; e2fsck -V 2>&1'

        # not running on the vitrualization node
        return false if `#{cmd}`.include? '1.42.13'

        true
    end

end
