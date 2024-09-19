#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "VirtualMachine live updateconf test" do
  #---------------------------------------------------------------------------
  # Defines test configuration and start OpenNebula
  #---------------------------------------------------------------------------
  prepend_before(:all) do
    @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
  end

  before(:all) do
    @hid = cli_create("onehost create host01 --im dummy --vm dummy")

    wait_loop()do
      xml = cli_action_xml("onehost show #{@hid} -x")
      OpenNebula::Host::HOST_STATES[xml['STATE'].to_i] == 'MONITORED'
    end

    cli_update("onedatastore update system", "TM_MAD=dummy\nDS_MAD=dummy", false)
    cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)
    cli_update("onedatastore update files", "TM_MAD=dummy\nDS_MAD=dummy", false)

    wait_loop() {
      xml = cli_action_xml("onedatastore show -x files")
      xml['FREE_MB'].to_i > 0
    }

    img_id1 = cli_create("oneimage create -d 2 --path /etc/passwd"\
      " --type CONTEXT --name test_context")

    @img_id_os1 = cli_create("oneimage create -d default --type OS"\
        " --name osimg1 --path /etc/passwd")

    tmpl = <<-EOF
        NAME = testvm1
        CPU  = 1
        MEMORY = 128
        CONTEXT = [
            CONTEXT = "true",
            NETWORK = "YES",
            FILES_DS = "$FILE[IMAGE=\\\"test_context\\\",IMAGE_ID=\\\"0\\\"]",
            SSH_PUBLIC_KEY = "a"]
        DISK = [
          IMAGE_ID = "#{@img_id_os1}" ]
        OS = [
          BOOT = "disk#{@img_id_os1-1}" ]
    EOF

    @tmpl_id = cli_create("onetemplate create", tmpl)
    @vmid = cli_create("onetemplate instantiate #{@tmpl_id}")
    @port = -1

    @vm = VM.new(@vmid)

    cli_action("onevm deploy #{@vmid} #{@hid}")

    tmpl_ssh_key = <<-EOF
        SSH_PUBLIC_KEY="pepe"
    EOF
    cli_update("oneuser update 0", tmpl_ssh_key, false, true)

    @vm.running?
  end

  #---------------------------------------------------------------------------
  # TESTS
  # Testing the same functionality as updateconf.rb, just for RUNNING state
  #---------------------------------------------------------------------------

  it "should try to autocomplete the ssh key" do
    xml = cli_action_xml("onevm show -x #{@vmid}")
    @port = xml["TEMPLATE/GRAPHICS/PORT"].to_i

    tmpl_auto_ssh = <<-EOF
        GRAPHICS = [
            TYPE = "vnc",
            LISTEN = "127.0.0.1",
            PORT = #{@port}
        ]
        CONTEXT = [
            CONTEXT = "true",
            NETWORK = "YES",
            SSH_PUBLIC_KEY = "$USER[SSH_PUBLIC_KEY]"]
    EOF

    cli_update("onevm updateconf #{@vmid}",tmpl_auto_ssh, false, true)

    @vm.running?

    xml = cli_action_xml("onevm show -x #{@vmid}")
    expect(xml["TEMPLATE/CONTEXT/SSH_PUBLIC_KEY"]).to eq("pepe")
  end

  it "should try to set the same port" do
    xml = cli_action_xml("onevm show -x #{@vmid}")
    @port = xml["TEMPLATE/GRAPHICS/PORT"].to_i

    tmpl_same_port = <<-EOF
      GRAPHICS = [
        TYPE = "vnc",
        LISTEN = "127.0.0.1",
        PORT = #{@port}
      ]
    EOF

    cli_update("onevm updateconf #{@vmid}",tmpl_same_port, false, true)

    @vm.running?

    xml = cli_action_xml("onevm show -x #{@vmid}")
    expect(xml["TEMPLATE/GRAPHICS/PORT"].to_i).to eq(@port)
  end

  it "should updateconf a machine with GRAPHICS" do
    vmid = cli_create("onetemplate instantiate #{@tmpl_id}")

    vm = VM.new(vmid)

    cli_action("onevm deploy #{vmid} #{@hid}")

    vm.running?

    tmpl_without_port = <<-EOF
      GRAPHICS = [
        TYPE = "vnc",
        LISTEN = "127.0.0.1"
      ]
    EOF

    cli_update("onevm updateconf #{vmid}",tmpl_without_port, false, true)

    vm.running?

    xml = cli_action_xml("onevm show -x #{vmid}")

    expect(xml["TEMPLATE/GRAPHICS/TYPE"]).to eq("vnc")
    expect(xml["TEMPLATE/GRAPHICS/LISTEN"]).to eq("127.0.0.1")
    expect(xml["TEMPLATE/GRAPHICS/PORT"]).not_to be_nil
  end

  it "should try to delete PORT" do
    tmpl = <<-EOF
      NAME = testvm_port
      CPU  = 1
      MEMORY = 128
      CONTEXT = [
          CONTEXT = "true",
          NETWORK = "YES",
          FILES_DS = "$FILE[IMAGE=\\\"test_context\\\",IMAGE_ID=\\\"0\\\"]",
          SSH_PUBLIC_KEY = "a"]
      GRAPHICS = [
        TYPE = "vnc",
        LISTEN = "127.0.0.1"
      ]
    EOF

    vmid = cli_create("onevm create", tmpl)

    vm = VM.new(vmid)

    cli_action("onevm deploy #{vmid} #{@hid}")

    vm.running?

    xml = cli_action_xml("onevm show -x #{vmid}")
    port = xml["TEMPLATE/GRAPHICS/PORT"].to_i

    tmpl_same_port = <<-EOF
      GRAPHICS = [
        TYPE = "vnc",
        LISTEN = "127.0.0.1"
      ]
    EOF

    cli_update("onevm updateconf #{vmid}",tmpl_same_port, false, true)

    vm.running?

    xml = cli_action_xml("onevm show -x #{vmid}")
    expect(xml["TEMPLATE/GRAPHICS/PORT"].to_i).to eq(port)
  end

  it "should delete FILES_DS from CONTEXT" do
    tmpl = <<-EOF
      NAME = testvm_files
      CPU  = 1
      MEMORY = 128
      CONTEXT = [
          CONTEXT = "true",
          NETWORK = "YES",
          FILES_DS = "$FILE[IMAGE=\\\"test_context\\\",IMAGE_ID=\\\"0\\\"]",
          SSH_PUBLIC_KEY = "a"]
      GRAPHICS = [
        TYPE = "vnc",
        LISTEN = "127.0.0.1"
      ]
    EOF

    vmid = cli_create("onevm create", tmpl)

    vm = VM.new(vmid)

    cli_action("onevm deploy #{vmid} #{@hid}")

    vm.running?

    xml = cli_action_xml("onevm show -x #{vmid}")
    expect(xml["TEMPLATE/CONTEXT/FILES_DS"]).not_to be_nil

    tmpl_without_files = <<-EOF
      CONTEXT = [
        CONTEXT = "true",
        NETWORK = "YES",
        SSH_PUBLIC_KEY = "a"]
    EOF

    cli_update("onevm updateconf #{vmid}",tmpl_without_files, false, true)

    xml = cli_action_xml("onevm show -x #{vmid}")
    expect(xml["TEMPLATE/CONTEXT/FILES_DS"]).to be_nil
  end

  it "should update CPU_MODEL" do
    tmpl = <<-EOF
      NAME = testvm_cpumodel
      CPU  = 1
      MEMORY = 128
      CPU_MODEL = [
        MODEL = "MODEL1"
      ]
      GRAPHICS = [
        TYPE = "vnc",
        LISTEN = "127.0.0.1"
      ]
    EOF

    vmid = cli_create("onevm create", tmpl)

    vm = VM.new(vmid)

    cli_action("onevm deploy #{vmid} #{@hid}")

    vm.running?

    xml = cli_action_xml("onevm show -x #{vmid}")
    expect(xml["TEMPLATE/CPU_MODEL/MODEL"]).to eq("MODEL1")

    tmpl_change_cpu_model = <<-EOF
        CPU_MODEL = [
          MODEL = "MODEL2"
        ]
    EOF

    cli_update("onevm updateconf #{vmid}",tmpl_change_cpu_model, false, true)

    vm.running?

    xml = cli_action_xml("onevm show -x #{vmid}")
    expect(xml["TEMPLATE/CPU_MODEL/MODEL"]).to eq("MODEL2")
  end

end
