require 'init'
require 'socket'

require_relative '../lib/image'
require_relative '../lib/backup_restic'
require_relative '../lib/VMTemplate'

RSpec.describe 'VM Backups: Restic - LXC' do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        if Socket.gethostname.include?('debian') # Strictly speaking check /etc/os-release

            cmd = '+ systemd-run --user --quiet --pipe --collect --wait --slice=backup.102.slice /var/tmp/one/tm/lib/backup_qcow2.rb -l -d 0: -x /var/lib/one//datastores/0/56/backup/vm.xml -p /var/lib/one//datastores/0/56'
            err = 'Failed to connect to bus: No such file or directory'

            reason = "Backups do not work on debian. The command '#{cmd}' fails with the error '#{err}'"

            skip reason
        end

        @info = {}
    end

    it 'creates datastore for backups' do
        @info[:backup_ds] = ResticDS.create(ResticDS.random_name, Host.private_ip)
    end

    it 'creates VM with SSH access' do
        @info[:vm] = VM.instantiate(@defaults[:template], true)
        @info[:vm].backup_ds_id = @info[:backup_ds].id
    end

    # still returns exitstatus 0 as backup is async
    it 'fails to backup running container' do
        @info[:vm].backup
        expect(@info[:vm].backups?).to be false
    end

    it 'creates file diff file inside Guest OS' do
        @info[:vm].file_write
    end

    it 'backs up VM' do
        @info[:vm].poweroff_hard
        @info[:vm].backup
        expect(@info[:vm].backups?).to be true

        @info[:backup_image] = CLIImage.new(@info[:vm].backup_id)
    end

    it 'deletes VM' do
        @info[:vm].terminate_hard
    end

    it 'restores a VM backup from backup image' do
        ids = @info[:backup_image].restore
        @info[:restored_template] = VMTemplate.new(ids[0])
    end

    it 'deploys restored VM Template' do
        @info[:vm] = @info[:restored_template].instantiate(true)
    end

    it 'restored backup contains diff file' do
        pp @info[:vm].file_check
    end

    it 'deletes restored backup VM Template' do
        @info[:restored_template].delete(true)
    end

    it 'deletes VM' do
        @info[:vm].terminate_hard
    end

    it 'deletes backup image' do
        @info[:backup_image].delete
        @info[:backup_image].deleted?
    end

    it 'deletes backup datastore' do
        @info[:backup_ds].delete
    end
end
