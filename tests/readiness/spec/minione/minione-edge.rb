require 'init'

RSpec.describe "Basic Configuration" do
    it "OpenNebula is running" do
        expect(`pgrep -lf oned`.empty?).to be(false)
    end

    it "CLI is working" do
        xml = cli_action_xml("oneuser show -x")
        expect(xml['ID']).to eq("0")
    end
end

RSpec.describe "On Edge" do
    before(:all) do
        @info = {}
    end

    it 'deploys' do
        vm_id = cli_create('onetemplate instantiate 0')
        @info[:vm] = VM.new(vm_id)
        @info[:vm].running?
    end

    it 'ping to public interface' do
        vm_xml = cli_action_xml("onevm show #{@info[:vm].id} -x")
        @info[:vm].wait_ping(vm_xml['//NIC/IP'])
    end

    it 'terminates VM' do
        @info[:vm].terminate
    end
end


RSpec.describe "Cleanup" do
    it "oneprovision cleanup" do
        cmd = SafeExec.run("oneprovision list -l ID | tail -1")
        expect(cmd.success?).to be(true)

        id = cmd.stdout.strip
        cmd = SafeExec.run("oneprovision delete #{id} --cleanup")
        expect(cmd.success?).to be(true)
    end
end
