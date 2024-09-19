#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "VirtualMachine GRAPHICS section test" do

  before(:all) do
    @hid = cli_create("onehost create host01 --im dummy --vm dummy")

    cli_update("onedatastore update system", "TM_MAD=dummy\nDS_MAD=dummy", false)
    cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)

    @tmpl = <<-EOF
        NAME = testvm1
        CPU  = 1
        MEMORY = 128
        GRAPHICS = [
          TYPE = "vnc",
          LISTEN = "127.0.0.1"
        ]
    EOF

    @info = {}
  end

  after(:each) do
    #FileUtils.remove_dir('/tmp/opennebula_dummy_actions/', true)
    FileUtils.rm(Dir.glob('/tmp/opennebula_dummy_actions/*'), force: true)

    vm = VM.new(@info[:vmid])

    cli_action("onevm recover --delete #{@info[:vmid]}") if vm.state != 'DONE'
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "should allocate a VirtualMachine that defines a GRAPHICS section" <<
  " without port and check that the default one (VNC_PORT+VM_ID)" <<
  " is set" do

    @info[:vmid] = cli_create("onevm create", @tmpl)

    cli_action("onevm deploy #{@info[:vmid]} #{@hid}")

    vm = VM.new(@info[:vmid])

    vm.running?

    xml = vm.info
    expect(xml["TEMPLATE/GRAPHICS/TYPE"]).to eql("vnc")
    expect(xml["TEMPLATE/GRAPHICS/LISTEN"]).to eql("127.0.0.1")
    expect(xml["TEMPLATE/GRAPHICS/PORT"].to_i).to eql(5900 + @info[:vmid])
  end

  it "should allocate a VirtualMachine that defines a GRAPHICS section" <<
  " and check that the defined port overwrites the default one" do
    tmpl = <<-EOF
        NAME = testvm1
        CPU  = 1
        MEMORY = 128
        GRAPHICS = [
          TYPE = "vnc",
          LISTEN = "127.0.0.1",
          PORT = 5
        ]
    EOF

    @info[:vmid] = cli_create("onevm create", tmpl)

    cli_action("onevm deploy #{@info[:vmid]} #{@hid}")

    vm = VM.new(@info[:vmid])

    vm.running?

    xml = vm.info
    expect(xml["TEMPLATE/GRAPHICS/TYPE"]).to eql("vnc")
    expect(xml["TEMPLATE/GRAPHICS/LISTEN"]).to eql("127.0.0.1")
    expect(xml["TEMPLATE/GRAPHICS/PORT"].to_i).to eql(5)
  end

  it "check VNC port after poweroff fails/success" do
    File.open('/tmp/opennebula_dummy_actions/shutdown', 'w') do |file|
      file.write("0\n")
    end

    @info[:vmid] = cli_create("onevm create", @tmpl)

    cli_action("onevm deploy #{@info[:vmid]} #{@hid}")

    vm = VM.new(@info[:vmid])

    vm.running?

    # Fail to poweroff
    cli_action("onevm poweroff #{@info[:vmid]}")

    vm.running?

    xml = vm.info
    expect(xml["TEMPLATE/GRAPHICS/PORT"]).not_to be_nil

    # Success poweroff
    File.delete('/tmp/opennebula_dummy_actions/shutdown')

    cli_action("onevm poweroff #{@info[:vmid]}")

    vm.stopped?

    xml = vm.info
    expect(xml["TEMPLATE/GRAPHICS/PORT"]).not_to be_nil
  end

  it "check VNC port after poweroff hard fails/success" do
    File.open('/tmp/opennebula_dummy_actions/cancel', 'w') do |file|
      file.write("0\n")
    end

    @info[:vmid] = cli_create("onevm create", @tmpl)

    cli_action("onevm deploy #{@info[:vmid]} #{@hid}")

    vm = VM.new(@info[:vmid])

    vm.running?

    # Fail to poweroff
    cli_action("onevm poweroff --hard #{@info[:vmid]}")

    vm.running?

    xml = vm.info
    expect(xml["TEMPLATE/GRAPHICS/PORT"]).not_to be_nil

    # Success poweroff
    File.delete('/tmp/opennebula_dummy_actions/cancel')

    cli_action("onevm poweroff --hard #{@info[:vmid]}")

    vm.stopped?

    xml = vm.info
    expect(xml["TEMPLATE/GRAPHICS/PORT"]).not_to be_nil
  end

  it "check VNC port after stop" do
    @info[:vmid] = cli_create("onevm create", @tmpl)

    cli_action("onevm deploy #{@info[:vmid]} #{@hid}")

    vm = VM.new(@info[:vmid])

    vm.running?

    cli_action("onevm stop #{@info[:vmid]}")

    vm.state?('STOPPED')

    xml = vm.info
    expect(xml["TEMPLATE/GRAPHICS/PORT"]).not_to be_nil
  end

  it "check VNC port after undeploy fails/success" do
    File.open('/tmp/opennebula_dummy_actions/shutdown', 'w') do |file|
      file.write("0\n")
    end

    @info[:vmid] = cli_create("onevm create", @tmpl)

    cli_action("onevm deploy #{@info[:vmid]} #{@hid}")

    vm = VM.new(@info[:vmid])

    vm.running?

    # Fail to undeploy
    cli_action("onevm undeploy #{@info[:vmid]}")

    vm.running?

    xml = vm.info
    expect(xml["TEMPLATE/GRAPHICS/PORT"]).not_to be_nil

    # Success undeploy
    File.delete('/tmp/opennebula_dummy_actions/shutdown')

    cli_action("onevm undeploy #{@info[:vmid]}")

    vm.undeployed?

    xml = vm.info
    expect(xml["TEMPLATE/GRAPHICS/PORT"]).to be_nil
  end

  it "check VNC port after undpeloy hard fails/success" do
    File.open('/tmp/opennebula_dummy_actions/cancel', 'w') do |file|
      file.write("0\n")
    end

    @info[:vmid] = cli_create("onevm create", @tmpl)

    cli_action("onevm deploy #{@info[:vmid]} #{@hid}")

    vm = VM.new(@info[:vmid])

    vm.running?

    # Fail to undeploy
    cli_action("onevm undeploy --hard #{@info[:vmid]}")

    vm.running?

    xml = vm.info
    expect(xml["TEMPLATE/GRAPHICS/PORT"]).not_to be_nil

    # Success undeploy
    File.delete('/tmp/opennebula_dummy_actions/cancel')

    cli_action("onevm undeploy --hard #{@info[:vmid]}")

    vm.undeployed?

    xml = vm.info
    expect(xml["TEMPLATE/GRAPHICS/PORT"]).to be_nil
  end

  it "check VNC port after suspend" do
    @info[:vmid] = cli_create("onevm create", @tmpl)

    cli_action("onevm deploy #{@info[:vmid]} #{@hid}")

    vm = VM.new(@info[:vmid])

    vm.running?

    cli_action("onevm suspend #{@info[:vmid]}")

    vm.state?('SUSPENDED')

    xml = vm.info
    expect(xml["TEMPLATE/GRAPHICS/PORT"]).not_to be_nil
  end

  it "check VNC port after terminate fails/success" do
    File.open('/tmp/opennebula_dummy_actions/shutdown', 'w') do |file|
      file.write("0\n")
    end

    @info[:vmid] = cli_create("onevm create", @tmpl)

    cli_action("onevm deploy #{@info[:vmid]} #{@hid}")

    vm = VM.new(@info[:vmid])

    vm.running?

    # Fail to terminate
    cli_action("onevm terminate #{@info[:vmid]}")

    vm.running?

    xml = vm.info
    expect(xml["TEMPLATE/GRAPHICS/PORT"]).not_to be_nil

    # Success poweroff
    File.delete('/tmp/opennebula_dummy_actions/shutdown')

    cli_action("onevm terminate #{@info[:vmid]}")

    vm.done?

    xml = vm.info
    expect(xml["TEMPLATE/GRAPHICS/PORT"]).to be_nil
  end

  it "check VNC port after terminate hard fails/success" do
    File.open('/tmp/opennebula_dummy_actions/cancel', 'w') do |file|
      file.write("0\n")
    end

    @info[:vmid] = cli_create("onevm create", @tmpl)

    cli_action("onevm deploy #{@info[:vmid]} #{@hid}")

    vm = VM.new(@info[:vmid])

    vm.running?

    # Fail to poweroff
    cli_action("onevm terminate --hard #{@info[:vmid]}")

    vm.running?

    xml = vm.info
    expect(xml["TEMPLATE/GRAPHICS/PORT"]).not_to be_nil

    # Success poweroff
    File.delete('/tmp/opennebula_dummy_actions/cancel')

    cli_action("onevm terminate --hard #{@info[:vmid]}")

    vm.done?

    xml = vm.info
    expect(xml["TEMPLATE/GRAPHICS/PORT"]).to be_nil
  end

  it "should trim VNC password to 8 chars" do
    tmpl = <<-EOF
        NAME = testvm1
        CPU  = 1
        MEMORY = 128
        GRAPHICS = [
          TYPE = "vnc",
          PASSWD = "123456789",
          LISTEN = "127.0.0.1",
          PORT = 5
        ]
    EOF

    @info[:vmid] = cli_create("onevm create", tmpl)

    vm = VM.new(@info[:vmid])

    xml = vm.info
    expect(xml["TEMPLATE/GRAPHICS/PASSWD"]).to eql('12345678')
  end

  it "should generate VNC password with length max 8 chars" do
    tmpl = <<-EOF
        NAME = testvm1
        CPU  = 1
        MEMORY = 128
        GRAPHICS = [
          TYPE = "VNC",
          RANDOM_PASSWD = "yes",
          LISTEN = "127.0.0.1",
          PORT = 5
        ]
    EOF

    @info[:vmid] = cli_create("onevm create", tmpl)

    vm = VM.new(@info[:vmid])

    xml = vm.info
    expect(xml["TEMPLATE/GRAPHICS/PASSWD"].length).to be <= 8
  end

  it "should trim SPICE password to 59 chars" do
    tmpl = <<-EOF
        NAME = testvm1
        CPU  = 1
        MEMORY = 128
        GRAPHICS = [
          TYPE = "spice",
          PASSWD = "SuperLongPasswordWhichShouldBeTrimmedToOnlyFiftyNineCharacters",
          LISTEN = "127.0.0.1",
          PORT = 5
        ]
    EOF

    @info[:vmid] = cli_create("onevm create", tmpl)

    vm = VM.new(@info[:vmid])

    xml = vm.info
    expect(xml["TEMPLATE/GRAPHICS/PASSWD"].length).to eq(59)
  end

  it "should generate SPICE password with length max 59 chars" do
    tmpl = <<-EOF
        NAME = testvm1
        CPU  = 1
        MEMORY = 128
        GRAPHICS = [
          TYPE = "SPICE",
          RANDOM_PASSWD = "yes",
          LISTEN = "127.0.0.1",
          PORT = 5
        ]
    EOF

    @info[:vmid] = cli_create("onevm create", tmpl)

    vm = VM.new(@info[:vmid])

    xml = vm.info
    expect(xml["TEMPLATE/GRAPHICS/PASSWD"].length).to eq(59)
  end

end
