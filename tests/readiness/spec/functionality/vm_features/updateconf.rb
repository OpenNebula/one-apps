#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe 'VirtualMachine section test' do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__), 'defaults.yaml')
    end

    before(:all) do
        @hid = cli_create('onehost create host01 --im dummy --vm dummy')

        wait_loop do
            xml = cli_action_xml("onehost show #{@hid} -x")
            OpenNebula::Host::HOST_STATES[xml['STATE'].to_i] == 'MONITORED'
        end

        cli_update('onedatastore update system', "TM_MAD=dummy\nDS_MAD=dummy", false)
        cli_update('onedatastore update default', "TM_MAD=dummy\nDS_MAD=dummy", false)
        cli_update('onedatastore update files', "TM_MAD=dummy\nDS_MAD=dummy", false)

        wait_loop do
            xml = cli_action_xml('onedatastore show -x files')
            xml['FREE_MB'].to_i > 0
        end

        img_id1 = cli_create('oneimage create -d 2 --path /etc/passwd'\
          ' --type CONTEXT --name test_context')

        @img_id_os1 = cli_create('oneimage create -d default --type OS'\
            ' --name osimg1 --path /etc/passwd')

        @img_id_os2 = cli_create('oneimage create -d default --type OS'\
          ' --name osimg2 --path /etc/passwd')

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
        DISK = [
          IMAGE_ID = "#{@img_id_os2}" ]
        OS = [
          BOOT = "disk#{@img_id_os1-1}" ]
        EOF

        @tmpl_id = cli_create('onetemplate create', tmpl)
        @vmid = cli_create("onetemplate instantiate #{@tmpl_id}")
        @port = -1

        @vm = VM.new(@vmid)

        cli_action("onevm deploy #{@vmid} #{@hid}")

        tmpl_ssh_key = <<-EOF
        SSH_PUBLIC_KEY="pepe"
        EOF
        cli_update('oneuser update 0', tmpl_ssh_key, false, true)

        @vm.running?
    end

    def updateconf_graphics_vms(action, state, allow_update, port)
        vmid = cli_create("onetemplate instantiate #{@tmpl_id}")

        vm = VM.new(vmid)

        cli_action("onevm deploy #{vmid} #{@hid}")

        vm.running?

        cli_action("onevm #{action} #{vmid}")

        vm.state?("#{state}")

        tmpl_without_port = <<-EOF
      GRAPHICS = [
        TYPE = "vnc",
        LISTEN = "127.0.0.1"
      ]
        EOF

        cli_update("onevm updateconf #{vmid}", tmpl_without_port, false, allow_update)

        xml = cli_action_xml("onevm show -x #{vmid}")

        if allow_update
            expect(xml['TEMPLATE/GRAPHICS/TYPE']).to eq('vnc')
            expect(xml['TEMPLATE/GRAPHICS/LISTEN']).to eq('127.0.0.1')
        end

        if port
            expect(xml['TEMPLATE/GRAPHICS/PORT']).not_to be_nil
        else
            expect(xml['TEMPLATE/GRAPHICS/PORT']).to be_nil
        end
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    it 'should add graphics section with update conf functionality' do
        cli_action("onevm poweroff --hard #{@vmid}")

        @vm.state? 'POWEROFF'

        template_graphics = <<-EOF
        GRAPHICS = [
            TYPE = "vnc",
            LISTEN = "127.0.0.1"
        ]
        EOF

        cli_update("onevm updateconf #{@vmid}", template_graphics, false, true)

        xml = cli_action_xml("onevm show -x #{@vmid}")

        expect(xml['TEMPLATE/GRAPHICS/PORT']).not_to be_nil
    end

    it 'should try to change port using stdin template' do
        xml = cli_action_xml("onevm show -x #{@vmid}")
        @port = xml['TEMPLATE/GRAPHICS/PORT'].to_i

        cmd = "onevm updateconf #{@vmid}"

        tmpl_new_port = <<-EOF
        GRAPHICS = [
          TYPE = "vnc",
          LISTEN = "127.0.0.1",
          PORT = 5
        ]
        EOF

        stdin_cmd = <<~BASH
            #{cmd} <<EOF
            #{tmpl_new_port}
            EOF
        BASH

        cli_action(stdin_cmd)

        xml = cli_action_xml("onevm show -x #{@vmid}")

        expect(xml['TEMPLATE/GRAPHICS/PORT'].to_i).not_to eq(5)
        expect(xml['TEMPLATE/GRAPHICS/PORT'].to_i).to eq(@port)
    end

    it 'should try to autocomplete the ssh key' do
        xml = cli_action_xml("onevm show -x #{@vmid}")
        @port = xml['TEMPLATE/GRAPHICS/PORT'].to_i

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

        cli_update("onevm updateconf #{@vmid}", tmpl_auto_ssh, false, true)

        xml = cli_action_xml("onevm show -x #{@vmid}")

        expect(xml['TEMPLATE/CONTEXT/SSH_PUBLIC_KEY']).to eq('pepe')
    end

    it 'should try to set the same port' do
        xml = cli_action_xml("onevm show -x #{@vmid}")
        @port = xml['TEMPLATE/GRAPHICS/PORT'].to_i

        tmpl_same_port = <<-EOF
      GRAPHICS = [
        TYPE = "vnc",
        LISTEN = "127.0.0.1",
        PORT = #{@port}
      ]
      OS = [
        BOOT = "disk#{@img_id_os2-1}" ]
        EOF

        cli_update("onevm updateconf #{@vmid}", tmpl_same_port, false, true)

        cli_action("onevm resume #{@vmid}")

        @vm.running?

        xml = cli_action_xml("onevm show -x #{@vmid}")

        expect(xml['TEMPLATE/GRAPHICS/PORT'].to_i).to eq(@port)
    end

    it 'should updateconf a HOLD machine with GRAPHICS' do
        vmid = cli_create("onetemplate instantiate #{@tmpl_id} --hold")

        vm = VM.new(vmid)

        tmpl_without_port = <<-EOF
      GRAPHICS = [
        TYPE = "vnc",
        LISTEN = "127.0.0.1"
      ]
        EOF

        cli_update("onevm updateconf #{vmid}", tmpl_without_port, false, true)

        xml = cli_action_xml("onevm show -x #{vmid}")

        expect(xml['TEMPLATE/GRAPHICS/TYPE']).to eq('vnc')
        expect(xml['TEMPLATE/GRAPHICS/LISTEN']).to eq('127.0.0.1')
        expect(xml['TEMPLATE/GRAPHICS/PORT']).to be_nil
    end

    it 'should updateconf a POWEROFF machine with GRAPHICS' do
        updateconf_graphics_vms('poweroff --hard', 'POWEROFF', true, true)
    end

    it 'should updateconf a UNDEPLOYED machine with GRAPHICS' do
        updateconf_graphics_vms('undeploy --hard', 'UNDEPLOYED', true, false)
    end

    it 'should updateconf a PENDING machine with GRAPHICS' do
        tmpl = <<-EOF
      NAME = testvm_pending
      SCHED_DS_REQUIREMENTS = "ID=\\\"200\\\""
      CPU  = 1
      MEMORY = 128
      CONTEXT = [
          CONTEXT = "true",
          NETWORK = "YES",
          FILES_DS = "$FILE[IMAGE=\\\"test_context\\\",IMAGE_ID=\\\"0\\\"]",
          SSH_PUBLIC_KEY = "a"]
        EOF

        vmid = cli_create('onevm create', tmpl)

        vm = VM.new(vmid)

        vm.state?('PENDING')

        tmpl_without_port = <<-EOF
      GRAPHICS = [
        TYPE = "vnc",
        LISTEN = "127.0.0.1"
      ]
        EOF

        cli_update("onevm updateconf #{vmid}", tmpl_without_port, false, true)

        xml = cli_action_xml("onevm show -x #{vmid}")

        expect(xml['TEMPLATE/GRAPHICS/TYPE']).to eq('vnc')
        expect(xml['TEMPLATE/GRAPHICS/LISTEN']).to eq('127.0.0.1')
        expect(xml['TEMPLATE/GRAPHICS/PORT']).to be_nil
    end

    it 'should updateconf a STOPPED machine with GRAPHICS' do
        updateconf_graphics_vms('stop', 'STOPPED', false, false)
    end

    it 'should try to delete PORT' do
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

        vmid = cli_create('onevm create', tmpl)

        vm = VM.new(vmid)

        cli_action("onevm deploy #{vmid} #{@hid}")

        vm.running?

        cli_action("onevm poweroff --hard #{vmid}")

        vm.state?('POWEROFF')

        xml = cli_action_xml("onevm show -x #{vmid}")
        port = xml['TEMPLATE/GRAPHICS/PORT'].to_i

        tmpl_same_port = <<-EOF
      GRAPHICS = [
        TYPE = "vnc",
        LISTEN = "127.0.0.1"
      ]
        EOF

        cli_update("onevm updateconf #{vmid}", tmpl_same_port, false, true)

        xml = cli_action_xml("onevm show -x #{vmid}")

        expect(xml['TEMPLATE/GRAPHICS/PORT'].to_i).to eq(port)
    end

    it 'should delete FILES_DS from CONTEXT' do
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

        vmid = cli_create('onevm create', tmpl)

        vm = VM.new(vmid)

        cli_action("onevm deploy #{vmid} #{@hid}")

        vm.running?

        cli_action("onevm poweroff --hard #{vmid}")

        vm.state?('POWEROFF')

        xml = cli_action_xml("onevm show -x #{vmid}")

        expect(xml['TEMPLATE/CONTEXT/FILES_DS']).not_to be_nil

        tmpl_without_files = <<-EOF
      CONTEXT = [
        CONTEXT = "true",
        NETWORK = "YES",
        SSH_PUBLIC_KEY = "a"]
        EOF

        cli_update("onevm updateconf #{vmid}", tmpl_without_files, false, true)

        xml = cli_action_xml("onevm show -x #{vmid}")

        expect(xml['TEMPLATE/CONTEXT/FILES_DS']).to be_nil
    end

    it 'should add FILES_DS to CONTEXT' do
        tmpl = <<-EOF
      NAME = testvm_files
      CPU  = 1
      MEMORY = 128
      CONTEXT = [
          CONTEXT = "true",
          NETWORK = "YES",
          SSH_PUBLIC_KEY = "a"]
      GRAPHICS = [
        TYPE = "vnc",
        LISTEN = "127.0.0.1"
      ]
        EOF

        vmid = cli_create('onevm create', tmpl)

        vm = VM.new(vmid)

        cli_action("onevm deploy #{vmid} #{@hid}")

        vm.running?

        cli_action("onevm poweroff --hard #{vmid}")

        vm.state?('POWEROFF')

        xml = cli_action_xml("onevm show -x #{vmid}")

        expect(xml['TEMPLATE/CONTEXT/FILES_DS']).to be_nil

        tmpl_without_files = <<-EOF
      CONTEXT = [
        CONTEXT = "true",
        NETWORK = "YES",
        FILES_DS = "$FILE[IMAGE=\\\"test_context\\\",IMAGE_ID=\\\"0\\\"]",
        SSH_PUBLIC_KEY = "a"]
        EOF

        cli_update("onevm updateconf #{vmid}", tmpl_without_files, false, true)

        xml = cli_action_xml("onevm show -x #{vmid}")

        expect(xml['TEMPLATE/CONTEXT/FILES_DS']).not_to be_nil
    end

    it 'should change FILES_DS in CONTEXT' do
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

        vmid = cli_create('onevm create', tmpl)

        vm = VM.new(vmid)

        cli_action("onevm deploy #{vmid} #{@hid}")

        vm.running?

        cli_action("onevm poweroff --hard #{vmid}")

        vm.state?('POWEROFF')

        xml = cli_action_xml("onevm show -x #{vmid}")

        expect(xml['TEMPLATE/CONTEXT/FILES_DS']).not_to be_nil
        expect(xml['TEMPLATE/CONTEXT/FILES_DS']).to include('test_context')

        img = cli_create('oneimage create -d 2 --path /etc/passwd'\
          ' --type CONTEXT --name replace_context')

        tmpl_without_files = <<-EOF
      CONTEXT = [
        CONTEXT = "true",
        NETWORK = "YES",
        FILES_DS = "$FILE[IMAGE=\\\"replace_context\\\",IMAGE_ID=\\\"#{img}\\\"]",
        SSH_PUBLIC_KEY = "a"]
        EOF

        cli_update("onevm updateconf #{vmid}", tmpl_without_files, false, true)

        xml = cli_action_xml("onevm show -x #{vmid}")

        expect(xml['TEMPLATE/CONTEXT/FILES_DS']).not_to be_nil
        expect(xml['TEMPLATE/CONTEXT/FILES_DS']).to include('replace_context')
    end

    it 'should update CPU_MODEL' do
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

        vmid = cli_create('onevm create', tmpl)

        vm = VM.new(vmid)

        cli_action("onevm deploy #{vmid} #{@hid}")

        vm.running?

        cli_action("onevm poweroff --hard #{vmid}")

        vm.state?('POWEROFF')

        xml = cli_action_xml("onevm show -x #{vmid}")

        expect(xml['TEMPLATE/CPU_MODEL/MODEL']).to eq('MODEL1')

        tmpl_change_cpu_model = <<-EOF
        CPU_MODEL = [
          MODEL = "MODEL2"
        ]
        EOF

        cli_update("onevm updateconf #{vmid}", tmpl_change_cpu_model, false, true)

        xml = cli_action_xml("onevm show -x #{vmid}")

        expect(xml['TEMPLATE/CPU_MODEL/MODEL']).to eq('MODEL2')
    end

    it "updateconf without 'append' should remove other attributes" do
        tmpl = <<-EOF
        NAME = test_append
        CPU  = 1
        MEMORY = 128
        CONTEXT = [
            CONTEXT = "true",
            NETWORK = "YES",
            FILES_DS = "$FILE[IMAGE=\\\"test_context\\\",IMAGE_ID=\\\"0\\\"]",
            SSH_PUBLIC_KEY = "a"]
        OS = [
          ARCH = "dummy" ]
        GRAPHICS = [
          TYPE = "vnc",
          LISTEN = "127.0.0.1" ]
        EOF

        vmid = cli_create('onevm create', tmpl)
        vm = VM.new(vmid)

        xml = vm.xml
        expect(xml['TEMPLATE/OS/ARCH']).to eq('dummy')
        expect(xml['TEMPLATE/GRAPHICS/TYPE']).to eq('vnc')
        expect(xml['TEMPLATE/CONTEXT/NETWORK']).to eq('YES')

        template = <<-EOF
        CONTEXT = [
            NEW_VAR = "test"
        ]
        EOF

        cli_update("onevm updateconf #{vmid}", template, false, true)

        xml = vm.xml

        expect(xml['TEMPLATE/OS/ARCH']).to be_nil
        expect(xml['TEMPLATE/GRAPHICS/TYPE']).to be_nil
        expect(xml['TEMPLATE/CONTEXT/NETWORK']).to be_nil
        expect(xml['TEMPLATE/CONTEXT/NEW_VAR']).to eq('test')
    end

    it 'updateconf append should not remove any attributes' do
        tmpl = <<-EOF
        NAME = test_append
        CPU  = 1
        MEMORY = 128
        CONTEXT = [
            CONTEXT = "true",
            NETWORK = "YES",
            VAR = "old",
            SSH_PUBLIC_KEY = "a"]
        OS = [
          ARCH = "dummy" ]
        GRAPHICS = [
          TYPE = "vnc",
          LISTEN = "127.0.0.1" ]
        EOF

        vmid = cli_create('onevm create', tmpl)
        vm = VM.new(vmid)

        xml = vm.xml
        expect(xml['TEMPLATE/OS/ARCH']).to eq('dummy')
        expect(xml['TEMPLATE/GRAPHICS/TYPE']).to eq('vnc')
        expect(xml['TEMPLATE/CONTEXT/NETWORK']).to eq('YES')
        expect(xml['TEMPLATE/CONTEXT/VAR']).to eq('old')

        template = <<-EOF
        CONTEXT = [
            VAR = "new",
            NEW_VAR = "test"
        ]
        GRAPHICS = [
            PASSWD = "secret"
        ]
        EOF

        cli_update("onevm updateconf #{vmid}", template, true, true)

        xml = vm.xml

        expect(xml['TEMPLATE/OS/ARCH']).to eq('dummy')
        expect(xml['TEMPLATE/GRAPHICS/TYPE']).to eq('vnc')
        expect(xml['TEMPLATE/GRAPHICS/PASSWD']).to eq('secret')
        expect(xml['TEMPLATE/CONTEXT/NETWORK']).to eq('YES')
        expect(xml['TEMPLATE/CONTEXT/VAR']).to eq('new')
        expect(xml['TEMPLATE/CONTEXT/NEW_VAR']).to eq('test')
    end
end
