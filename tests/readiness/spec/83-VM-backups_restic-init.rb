require 'init'
require_relative '../lib/image'
require_relative '../lib/backup_restic'
require_relative '../lib/VMTemplate'

RSpec.describe 'VM Backups: Restic' do
    before(:all) do
        @defaults = RSpec.configuration.defaults
        @info = {}
    end

    it 'creates datastore for backups' do
        @info[:backup_ds] = ResticDS.create(ResticDS.random_name, Host.private_ip)
    end
end
