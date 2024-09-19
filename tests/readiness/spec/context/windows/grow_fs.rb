###########################################################
#
# Main Tests
#

shared_examples_for 'context_windows_grow_fs' do |image, hv, prefix|
    include_examples 'context_windows', image, hv, prefix, <<~EOT
        CONTEXT=[
          NETWORK="YES",
          TOKEN="YES",
          SSH_PUBLIC_KEY="$USER[SSH_PUBLIC_KEY]",
          PASSWORD_BASE64="#{Base64.encode64(WINRM_PSWD).strip}",
          GROW_FS="X Y:\"
        ]
    EOT

    include_examples 'context_windows_safe_poweroff'

    it 'attach new disks' do
        2.upto(3).each do |i|
            disk_template = TemplateParser.template_like_str(
                :disk => {
                    :size => 1000,
                    :type => 'fs',
                    :dev_prefix => 'hd', # TODO
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
        @info[:vm].wait_ping
        @info[:vm].reachable?('oneadmin')
    end

    it 'disks exist (required)' do
        disks = [false, false, false]

        o, _e, _s = @info[:vm].winrm('echo list disk | diskpart')

        o.lines.each do |line|
            case line.to_s.downcase
            when /disk 0/
                disks[0] = true
            when /disk 1/
                disks[1] = true
            when /disk 2/
                disks[2] = true
            end
        end

        disks.each do |disk|
            expect(disk).to eq(true)
        end
    end

    it 'format disk X:' do
        o, _e, s = @info[:vm].powershell('(Get-Disk 1).PartitionStyle')
        expect(s).to eq(true)
        expect(o.downcase).to eq('raw')

        sleep 5

        o, e, s = @info[:vm].powershell('Initialize-Disk -Number 1')
        expect(s).to eq(true)
        expect(o).to be_empty

        sleep 5

        o, _e, s = @info[:vm].powershell('(Get-Disk 1).PartitionStyle')
        expect(s).to eq(true)
        expect(o.downcase).to eq('gpt')

        cmd = '(New-Partition -DiskNumber 1 -UseMaximumSize | Format-Volume -FileSystem NTFS).Size'
        o, e, s = @info[:vm].powershell(cmd)

        expect(s).to eq(true)
        expect(o).to match(/^[0-9]+$/)
        disk_size = o.to_i
        expect(disk_size).to be > 0

        o, _e, s = @info[:vm].powershell(
            'Set-Partition -DiskNumber 1 -PartitionNumber 2 -NewDriveLetter X'
        )
        expect(s).to eq(true)
        expect(o).to be_empty

        o, _e, s = @info[:vm].powershell('(Get-Volume -DriveLetter X).Size')
        expect(s).to eq(true)
        expect(o).to match(/^[0-9]+$/)
        expect(o.to_i).to eq(disk_size)
    end

    it 'format disk Y:' do
        o, _e, s = @info[:vm].powershell('(Get-Disk 2).PartitionStyle')
        expect(s).to eq(true)
        expect(o.downcase).to eq('raw')

        o, _e, s = @info[:vm].powershell('Initialize-Disk -Number 2')
        expect(s).to eq(true)
        expect(o).to be_empty

        o, _e, s = @info[:vm].powershell('(Get-Disk 2).PartitionStyle')
        expect(s).to eq(true)
        expect(o.downcase).to eq('gpt')

        cmd = '(New-Partition -DiskNumber 2 -UseMaximumSize | Format-Volume -FileSystem NTFS).Size'
        o, _e, s = @info[:vm].powershell(cmd)
        expect(s).to eq(true)
        expect(o).to match(/^[0-9]+$/)
        disk_size = o.to_i
        expect(disk_size).to be > 0

        o, _e, s = @info[:vm].powershell(
            'Set-Partition -DiskNumber 2 -PartitionNumber 2 -NewDriveLetter Y'
        )
        expect(s).to eq(true)
        expect(o).to be_empty

        o, _e, s = @info[:vm].powershell('(Get-Volume -DriveLetter Y).Size')
        expect(s).to eq(true)
        expect(o).to match(/^[0-9]+$/)
        expect(o.to_i).to eq(disk_size)
    end

    it 'measures disk C: size' do
        o, _e, s = @info[:vm].powershell('(Get-Disk -Number 0).Size')
        expect(s).to eq(true)
        expect(o).to match(/^[0-9]+$/)

        @info[:diskC_size] = o.to_i
        expect(@info[:diskC_size]).to be > 0

        o, _e, s = @info[:vm].powershell('(Get-Volume -DriveLetter C).Size')
        expect(s).to eq(true)
        expect(o).to match(/^[0-9]+$/)

        @info[:diskC_fs_size] = o.to_i
        expect(@info[:diskC_fs_size]).to be > 0
    end

    it 'measures disk X: size' do
        o, _e, s = @info[:vm].powershell('(Get-Disk -Number 1).Size')
        expect(s).to eq(true)
        expect(o).to match(/^[0-9]+$/)

        @info[:diskX_size] = o.to_i
        expect(@info[:diskX_size]).to be > 0

        o, e, s = @info[:vm].powershell('(Get-Volume -DriveLetter X).Size')

        expect(s).to eq(true)
        expect(o).to match(/^[0-9]+$/)

        @info[:diskX_fs_size] = o.to_i
        expect(@info[:diskX_fs_size]).to be > 0
    end

    it 'measures disk Y: size' do
        o, _e, s = @info[:vm].powershell('(Get-Disk -Number 2).Size')
        expect(s).to eq(true)
        expect(o).to match(/^[0-9]+$/)

        @info[:diskY_size] = o.to_i
        expect(@info[:diskY_size]).to be > 0

        o, _e, s = @info[:vm].powershell('(Get-Volume -DriveLetter Y).Size')
        expect(s).to eq(true)
        expect(o).to match(/^[0-9]+$/)

        @info[:diskY_fs_size] = o.to_i
        expect(@info[:diskY_fs_size]).to be > 0
    end

    include_examples 'context_windows_safe_poweroff'

    it 'resize disk X:' do
        s = (@info[:diskX_size] / (1024 * 1024)) + 1024
        cli_action("onevm disk-resize #{@info[:vm_id]} 2 #{s}")
        @info[:vm].state?('POWEROFF')
    end

    it 'resize disk Y:' do
        s = (@info[:diskY_size] / (1024 * 1024)) + 1024
        cli_action("onevm disk-resize #{@info[:vm_id]} 3 #{s}")
        @info[:vm].state?('POWEROFF')
    end

    it 'resume (required)' do
        @info[:vm].resume
        @info[:vm].wait_ping
        @info[:vm].reachable?('oneadmin')
    end

    it 'has resized disk X: (required)' do
        sleep 5

        o, _e, s = @info[:vm].powershell('(Get-Disk -Number 1).Size')
        expect(s).to eq(true)
        expect(o).to match(/^[0-9]+$/)

        new_disk_size = o.to_i
        expect(new_disk_size).to be > @info[:diskX_size]

        @info[:diskX_size] = new_disk_size
    end

    it 'has resized fs on disk X: (required)' do
        new_fs_size = 0

        wait_loop(:timeout => 100) do
            o, _e, s = @info[:vm].powershell('(Get-Volume -DriveLetter X).Size')
            expect(s).to eq(true)
            expect(o).to match(/^[0-9]+$/)

            new_fs_size = o.to_i
            new_fs_size > @info[:diskX_fs_size]
        end

        @info[:diskX_fs_size] = new_fs_size
    end

    it 'has resized disk Y: (required)' do
        sleep 5

        o, _e, s = @info[:vm].powershell('(Get-Disk -Number 2).Size')
        expect(s).to eq(true)
        expect(o).to match(/^[0-9]+$/)

        new_disk_size = o.to_i
        expect(new_disk_size).to be > @info[:diskY_size]

        @info[:diskY_size] = new_disk_size
    end

    it 'has resized fs on disk Y: (required)' do
        new_fs_size = 0

        wait_loop(:timeout => 100) do
            o, _e, s = @info[:vm].powershell('(Get-Volume -DriveLetter Y).Size')
            expect(s).to eq(true)
            expect(o).to match(/^[0-9]+$/)

            new_fs_size = o.to_i
            new_fs_size > @info[:diskY_fs_size]
        end

        @info[:diskY_fs_size] = new_fs_size
    end
end
