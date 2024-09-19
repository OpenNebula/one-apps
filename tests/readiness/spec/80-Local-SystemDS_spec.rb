require 'init'
require 'pry'

# Tests DS Operations

RSpec.describe "DS Operations" do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        @info[:vm_id] = cli_create("onetemplate instantiate '#{@defaults[:template_no_ssh]}'")
        @info[:vm_id_ssh] = cli_create("onetemplate instantiate '#{@defaults[:template]}'")

        @info[:vm]    = VM.new(@info[:vm_id])
        @info[:vm_ssh]    = VM.new(@info[:vm_id_ssh])

        @info[:ds_id]  = @info[:vm].xml["TEMPLATE/DISK[IMAGE='alpine']/DATASTORE_ID"]
        @info[:ds_id_ssh]  = @info[:vm_ssh].xml["TEMPLATE/DISK[IMAGE='alpine']/DATASTORE_ID"]

	@info[:ds] = cli_action_xml("onedatastore show -x #{@info[:ds_id]}")
        @info[:ds_ssh] = cli_action_xml("onedatastore show -x #{@info[:ds_id_ssh]}")

        expect(@info[:vm].xml["TEMPLATE/DISK[IMAGE='alpine']/LN_TARGET"]).to eq(@info[:ds]["TEMPLATE/LN_TARGET"])
        expect(@info[:vm_ssh].xml["TEMPLATE/DISK[IMAGE='alpine']/LN_TARGET"]).to eq(@info[:ds_ssh]["TEMPLATE/LN_TARGET_SSH"])

        expect(@info[:vm].xml["TEMPLATE/DISK[IMAGE='alpine']/CLONE_TARGET"]).to eq(@info[:ds]["TEMPLATE/CLONE_TARGET"])
        expect(@info[:vm_ssh].xml["TEMPLATE/DISK[IMAGE='alpine']/CLONE_TARGET"]).to eq(@info[:ds_ssh]["TEMPLATE/CLONE_TARGET_SSH"])

        expect(@info[:vm].xml["TEMPLATE/DISK[IMAGE='alpine']/DISK_TYPE"]).to eq(@info[:ds]["TEMPLATE/DISK_TYPE"])
        expect(@info[:vm_ssh].xml["TEMPLATE/DISK[IMAGE='alpine']/DISK_TYPE"]).to eq(@info[:ds_ssh]["TEMPLATE/DISK_TYPE_SSH"])

        @info[:vm].running?
        @info[:vm_ssh].running?
    end

    after(:all) do
    end

    ############################################################################
    # CP
    ############################################################################
=begin
    it "verify vms have ping" do
        @info[:vm].reachable?
        @info[:vm_ssh].reachable?
    end
=end
    it "verify disk created well" do
        cmd = cli_action("ssh #{@info[:vm].xml["HISTORY_RECORDS/HISTORY/HOSTNAME"]} virsh -c qemu:///system dumpxml one-#{@info[:vm_id]}")
        cmd_ssh = cli_action("ssh #{@info[:vm_ssh].xml["HISTORY_RECORDS/HISTORY/HOSTNAME"]} virsh -c qemu:///system dumpxml one-#{@info[:vm_id_ssh]}")

        elem = XMLElement.new
        elem.initialize_xml(cmd.stdout, "")
        elem_ssh = XMLElement.new
        elem_ssh.initialize_xml(cmd_ssh.stdout, "")

        secret = @info[:vm].xml["TEMPLATE/DISK[IMAGE='alpine']/CEPH_SECRET"]
        disk_id_ssh = @info[:vm_ssh].xml["TEMPLATE/DISK[IMAGE='alpine']/DISK_ID"]

	expect(elem["domain/devices/disk/auth/secret[contains(@uuid,'#{secret}')]/../../source[@protocol='#{@info[:ds]["TEMPLATE/DISK_TYPE"].downcase}']"]).not_to be_nil
        expect(elem_ssh["domain/devices/disk/source[contains(@file,'#{disk_id_ssh}')]/../../disk[@type='#{@info[:ds_ssh]["TEMPLATE/DISK_TYPE_SSH"].downcase}']"]).not_to be_nil
    end

end

