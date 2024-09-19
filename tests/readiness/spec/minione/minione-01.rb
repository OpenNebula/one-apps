require 'init'

RSpec.describe 'Minione tests' do
    it 'Sunstone is active' do
        SafeExec.run('systemctl is-active opennebula-sunstone').expect_success
    end

    it "OpenNebula services don't fail" do
        cmd = SafeExec.run('systemctl  | grep opennebula | grep failed')
        expect(cmd.stdout).to be_empty
    end

    it 'Run purge' do
        cmd = SafeExec.run('sudo /usr/local/bin/minione -v --force --purge --yes --preserve-user')
        expect(cmd.success?).to be(true)
    end

    it 'Run minione again' do
        cmd = SafeExec.run('cat /tmp/minione.lastrun')

        raise 'Can not read /tmp/minione.lastrun file' unless cmd.success?

        minione_cmd = cmd.stdout
        cmd = SafeExec.run("sudo #{minione_cmd}", 600)
        expect(cmd.success?).to be(true)
    end
end
