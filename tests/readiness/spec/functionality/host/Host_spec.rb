#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Host operations test" do

  prepend_before(:all) do
    @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "should create a non existing Host" do
    @hid = cli_create("onehost create first_host --im dummy --vm dummy")
    cli_action("onehost show first_host")
  end

  it "should try to create an existing Host and check the failure" do
    cli_create("onehost create first_host --im dummy --vm dummy", nil, false)
  end

  it "should disable/enable an existing Host" do
    host = Host.new("first_host")
    host.monitored?
    cli_action("onehost disable first_host")
    host.disabled?
    cli_action("onehost enable first_host")
    host.monitored?
  end

  it "should monitor host" do
    host = Host.new("first_host")
    host.monitored?

    fields = %w(MONITORING/CAPACITY/FREE_CPU
        MONITORING/CAPACITY/FREE_MEMORY
        MONITORING/CAPACITY/USED_MEMORY
        MONITORING/CAPACITY/USED_CPU
        MONITORING/SYSTEM/NETRX
        MONITORING/SYSTEM/NETTX
        HOST_SHARE/TOTAL_MEM
        HOST_SHARE/TOTAL_CPU)

    fields.each do |field|
      expect(host[field]).to_not be_nil
      expect(host[field].to_i).to be > 0
    end
  end

  it "should edit dynamically an existing Host template" do
    xml = cli_action_xml("onehost show first_host -x")
    expect(xml['TEMPLATE/ATT1']).to eql(nil)
    expect(xml['TEMPLATE/ATT2']).to eql(nil)

    template =  "ATT2 = NEW_VAL\n" <<
                "ATT3 = VAL3"

    cli_update("onehost update first_host", template, true)

    xml = cli_action_xml("onehost show first_host -x")
    expect(xml['TEMPLATE/ATT1']).to eql(nil)
    expect(xml['TEMPLATE/ATT2']).to eql("NEW_VAL")
    expect(xml['TEMPLATE/ATT3']).to eql("VAL3")
  end

  it "should delete an existing Host and check that, now, it doesn't exist" do
    cli_action("onehost delete first_host")
    cli_action("onehost show first_host", false)
  end

  it "should rename hostname and check if history vm has changed" do
    hid_rename = cli_create("onehost create host_not_rename --im dummy --vm dummy")

    vmid = cli_create("onevm create --name test --cpu 1 --memory 128")

    vm = VM.new(vmid)

    cli_action("onevm deploy #{vmid} #{hid_rename}")

    vm.running?

    cli_action("onehost rename #{hid_rename} host_rename")

    vm_xml = vm.info

    expect(vm_xml["HISTORY_RECORDS/HISTORY/HOSTNAME"]).to eq("host_rename")
  end

end