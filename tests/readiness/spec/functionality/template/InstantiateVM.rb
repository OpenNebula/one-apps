#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
# ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe 'Instantiate Template' do
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__), 'defaults.yaml')
    end

    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        template = <<-EOF
            NAME   = test_template
            CPU    = 2
            MEMORY = 128
            ATT1   = "VAL1"
            ATT2   = "VAL2"
        EOF

        vnet_tmpl = <<-EOF
        BRIDGE = virbr0
        VN_MAD = dummy
        AR=[TYPE = "IP4", IP = "10.0.0.10", SIZE = "100" ]
        EOF

        vnet_tmpl_2 = <<-EOF
        BRIDGE = virbr0
        VN_MAD = dummy
        AR=[TYPE = "IP4", IP = "10.0.0.200", SIZE = "100" ]
        EOF

        @template_id = cli_create('onetemplate create', template)
        @host_id     = cli_create('onehost create dummy -i dummy -v dummy')

        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update('onedatastore update system', mads, false)
        cli_update('onedatastore update default', mads, false)
        @ds_id = cli_create('onedatastore create', "NAME = system_ssh\nTM_MAD=ssh\nTYPE=system_ds")

        cli_action('onedatastore disable system_ssh')

        wait_loop do
            xml = cli_action_xml('onedatastore show -x default')
            xml['FREE_MB'].to_i > 0
        end

        @img_id = cli_create('oneimage create --name test_img ' <<
        '--size 100 --type datablock -d default')

        @cd_id = cli_create('oneimage create --name test_cd ' <<
        '--path /etc/passwd --size 5 --type cdrom -d default')
        cli_create('onevnet create ', "NAME = vnet_A\n"+vnet_tmpl)
        cli_create('onevnet create ', "NAME = vnet_B\n"+vnet_tmpl_2)

        @id_user = cli_create('oneuser create uA uA')
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it 'should allocate a new VirtualMachine that uses an existing Template' do
        id = cli_create("onetemplate instantiate #{@template_id}")
        cli_action("onevm deploy #{id} #{@host_id}")

        vm = VM.new(id)

        vm.running?

        cli_action("onevm terminate --hard #{id}")
    end

    it 'should allocate a new VirtualMachine that uses a lock vnet using stdin extra template' do
        template = <<-EOF
            NAME   = template_with_lock
            CPU = 0.1
            MEMORY = 128
            DISK =  [
                IMAGE_ID = #{@img_id}]
        EOF

        extra_template = <<-EOF
            NIC = [
                NETWORK = "vnet_A",
                NETWORK_UNAME = "oneadmin" ]
        EOF

        template_id = cli_create('onetemplate create', template)

        cli_action('onevnet lock vnet_A --use')

        cli_action("onetemplate show #{template_id} --extended", true)

        cli_create_stdin("onetemplate instantiate #{template_id}", extra_template, false)

        cli_action('onevnet unlock vnet_A')

        cli_action("oneimage lock #{@img_id} --use")

        cli_action("onetemplate show #{template_id} --extended", true)

        cli_create_stdin("onetemplate instantiate #{template_id}", extra_template, false)

        cli_action("oneimage unlock #{@img_id}")

        id = cli_create_stdin("onetemplate instantiate #{template_id}", extra_template, true)

        cli_action("onevm deploy #{id} #{@host_id}")

        vm = VM.new(id)

        vm.running?

        cli_action("onevm terminate --hard #{id}")
    end

    it 'should allocate a new VirtualMachine that uses a lock image' do
        template = <<-EOF
            NAME   = template_persistent
            CPU = 0.1
            MEMORY = 128
            DISK =  [
                IMAGE_ID = #{@img_id}]
            NIC = [
                NETWORK = "vnet_A",
                NETWORK_UNAME = "oneadmin" ]
        EOF

        template_id = cli_create('onetemplate create', template)

        cli_action("oneimage lock #{@img_id} --use")

        cli_action("onetemplate show #{template_id} --extended", true)

        cli_create("onetemplate instantiate #{template_id} --persistent", nil, false)

        cli_action("oneimage unlock #{@img_id}")

        wait_loop(:success => 'READY', :break => 'ERROR') do
            xml = cli_action_xml("oneimage show -x #{@img_id}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        end

        id = cli_create("onetemplate instantiate #{template_id} --persistent", nil, true)

        vm = VM.new(id)

        vm.state?('PENDING')

        cli_action("onevm deploy #{id} #{@host_id}")

        vm.running?

        cli_action("onevm terminate --hard #{id}")
    end

    it 'should allocate a new VirtualMachine that uses an existing Template '<<
        'replacing the instance name' do
        id = cli_create('onetemplate instantiate --name other --cpu 34'\
                        " #{@template_id}")

        xml = cli_action_xml("onevm show -x #{id}")

        expect(xml['NAME']).to eq('other')
        expect(xml['TEMPLATE/CPU']).to eq('34')

        cli_action("onevm terminate --hard #{id}")
    end

    it 'should instantiate and merge from a Template' do
        template = <<-EOF
            CPU = 0.1
            MEMORY = 128
            EXTRA = abc
        EOF

        id = cli_create("onetemplate instantiate #{@template_id}", template)

        xml = cli_action_xml("onevm show -x #{id}")

        expect(xml['TEMPLATE/CPU']).to eq('0.1')
        expect(xml['TEMPLATE/MEMORY']).to eq('128')
        expect(xml['USER_TEMPLATE/EXTRA']).to eq('abc')

        cli_action("onevm terminate --hard #{id}")
    end

    it 'should save a VirtualMachine into a new Template' do
        template = <<-EOF
            NAME   = template_with_nic
            CPU = 0.1
            MEMORY = 128
            DISK =  [
                IMAGE_ID = #{@cd_id}]
            DISK =  [
                IMAGE_ID = #{@img_id}]
            NIC = [
                NETWORK = "vnet_A",
                NETWORK_UNAME = "oneadmin" ]
            NIC = [
                NETWORK = "vnet_B",
                NETWORK_UNAME = "oneadmin" ]
        EOF
        template_id = cli_create('onetemplate create', template)
        id = cli_create("onetemplate instantiate #{template_id}")
        cli_action("onevm deploy #{id} dummy")
        vm = VM.new(id)
        vm.running?

        cli_action("onevm poweroff --hard #{id}")
        vm.state?('POWEROFF')

        cli_action("onevm save #{id} new_template")
        xml = cli_action_xml('onetemplate show -x new_template')

        expect(xml.retrieve_elements('TEMPLATE/NIC').size).to eq(2)
        expect(xml["TEMPLATE/NIC[NETWORK='vnet_A']/VLAN_ID"]).to be_nil
        expect(xml["TEMPLATE/NIC[NETWORK='vnet_B']/VLAN_ID"]).to be_nil

        disks = xml.retrieve_xmlelements('TEMPLATE/DISK')
        old_imgs = [@img_id, @cd_id]
        disks.each do |disk|
            d = old_imgs.delete(disk['IMAGE_ID'].to_i)
            expect(d).to be(@cd_id) if d
        end

        expect(old_imgs.size).to be(1)
        expect(old_imgs.first).to be(@img_id)

        cli_action("onevm terminate --hard #{id}")
    end

    it 'should save a VirtualMachine into a new Template with DISK parameters' do
        template = <<-EOF
            NAME   = template_with_total_bytes_sec
            CPU = 0.1
            MEMORY = 128
            DISK =  [
                IMAGE_ID = #{@img_id},
                TOTAL_BYTES_SEC = 1]
        EOF

        template_id = cli_create('onetemplate create', template)
        id = cli_create("onetemplate instantiate #{template_id}")
        cli_action("onevm deploy #{id} dummy")
        vm = VM.new(id)
        vm.running?

        cli_action("onevm poweroff --hard #{id}")
        vm.state?('POWEROFF')

        cli_action("onevm save #{id} new_template_total_bytes_sec")
        xml = cli_action_xml('onetemplate show -x new_template_total_bytes_sec')

        disks = xml.retrieve_xmlelements('TEMPLATE/DISK')
        disks.each do |disk|
            expect(disk.to_hash['DISK'].count).to eq(3)
            expect(disk['IMAGE_ID']).not_to eq(@img_id)
            expect(disk['TOTAL_BYTES_SEC']).to eq('1')
        end

        cli_action("onevm terminate --hard #{id}")
    end

    it 'should instantiate a template with a disk without TM_MAD_SYSTEM' do
        template = <<-EOF
            NAME   = template_without
            CPU = 0.1
            MEMORY = 128
            DISK =  [
                IMAGE_ID = #{@img_id}
            ]

        EOF

        template_id = cli_create('onetemplate create', template)
        id = cli_create("onetemplate instantiate #{template_id}")

        xml_ds = cli_action_xml('onedatastore show -x default')

        xml = cli_action_xml("onevm show -x #{id}")

        expect(xml["TEMPLATE/DISK[IMAGE_ID='#{@img_id}']/LN_TARGET"]).to eq(xml_ds['TEMPLATE/LN_TARGET'])
        expect(xml["TEMPLATE/DISK[IMAGE_ID='#{@img_id}']/CLONE_TARGET"]).to eq(xml_ds['TEMPLATE/CLONE_TARGET'])
        expect(xml["TEMPLATE/DISK[IMAGE_ID='#{@img_id}']/DISK_TYPE"]).to eq(xml_ds['TEMPLATE/DISK_TYPE'])
        expect(xml['TEMPLATE/AUTOMATIC_DS_REQUIREMENTS']).to eq('("CLUSTERS/ID" @> 0)')

        cli_action("onevm terminate --hard #{id}")
    end

    it 'should instantiate a template with a disk with TM_MAD_SYSTEM = SSH' do
        template = <<-EOF
            NAME   = template_ssh
            CPU = 0.1
            MEMORY = 128
            TM_MAD_SYSTEM = "ssh"
            DISK =  [
                IMAGE_ID = #{@img_id}
            ]
        EOF

        template_id = cli_create('onetemplate create', template)
        id = cli_create("onetemplate instantiate #{template_id}")

        xml_ds = cli_action_xml('onedatastore show -x default')

        xml = cli_action_xml("onevm show -x #{id}")

        expect(xml["TEMPLATE/DISK[IMAGE_ID='#{@img_id}']/TM_MAD_SYSTEM"].upcase).to eq 'SSH'
        expect(xml["TEMPLATE/DISK[IMAGE_ID='#{@img_id}']/LN_TARGET"]).to eq(xml_ds['TEMPLATE/LN_TARGET_SSH'])
        expect(xml["TEMPLATE/DISK[IMAGE_ID='#{@img_id}']/CLONE_TARGET"]).to eq(xml_ds['TEMPLATE/CLONE_TARGET_SSH'])
        expect(xml["TEMPLATE/DISK[IMAGE_ID='#{@img_id}']/DISK_TYPE"]).to eq(xml_ds['TEMPLATE/DISK_TYPE_SSH'])
        expect(xml['TEMPLATE/AUTOMATIC_DS_REQUIREMENTS']).to eq('("CLUSTERS/ID" @> 0) & (TM_MAD = "ssh")')

        cli_action("onevm terminate --hard #{id}")
    end

    it 'should instantiate a template with a different owner' do
        template = <<-EOF
            NAME   = template_uid
            CPU = 0.1
            MEMORY = 128
            AS_UID = #{@id_user}
            DISK =  [
                IMAGE_ID = #{@img_id}
            ]
        EOF

        template_id = cli_create('onetemplate create', template)
        id = cli_create("onetemplate instantiate #{template_id}")

        xml = cli_action_xml("onevm show -x #{id}")

        expect(xml['UNAME']).to eq('uA')
        expect(xml['GNAME']).to eq('oneadmin')

        cli_action("onevm terminate --hard #{id}")
    end

    it 'should instantiate a template with a different group' do
        template = <<-EOF
            NAME   = template_gid
            CPU = 0.1
            MEMORY = 128
            DISK =  [
                IMAGE_ID = #{@img_id}
            ]
        EOF

        template_id = cli_create('onetemplate create', template)
        id = cli_create("onetemplate instantiate #{template_id} --as_gid 1")

        xml = cli_action_xml("onevm show -x #{id}")

        expect(xml['UNAME']).to eq('oneadmin')
        expect(xml['GNAME']).to eq('users')

        cli_action("onevm terminate --hard #{id}")
    end

    it 'should instantiate a template with a different group and owner' do
        @ga_id = cli_create('onegroup create ga')
        @user_admin = cli_create('oneuser create uadmin uadmin')
        @user = cli_create('oneuser create user user')

        cli_action('oneuser addgroup uadmin ga')
        cli_action('oneuser addgroup user ga')

        cli_action('onegroup addadmin ga uadmin')

        template = <<-EOF
            NAME   = template_uid_gid
            CPU = 0.1
            MEMORY = 128
        EOF

        template_id = cli_create('onetemplate create', template)

        cli_action("onetemplate chown #{template_id} #{@user_admin}")
        cli_action("onetemplate chgrp #{template_id} #{@ga_id}")
        cli_action("onetemplate chmod #{template_id} 640")

        as_user('uadmin') do
            id = cli_create("onetemplate instantiate #{template_id} --as_uid #{@user} --as_gid #{@ga_id}")

            xml = cli_action_xml("onevm show -x #{id}")

            expect(xml['UNAME']).to eq('user')
            expect(xml['GNAME']).to eq('ga')

            cli_action("onevm terminate --hard #{id}")
        end
    end

    it 'should instantiate a template with a disk without TM_MAD_SYSTEM and will be TM_MAD_SYSTEM' do
        cli_action('onedatastore disable system') # dummy
        cli_action('onedatastore enable system_ssh') # ssh

        template = <<-EOF
            NAME   = template
            CPU = 0.1
            MEMORY = 128
            DISK =  [
                IMAGE_ID = #{@img_id}
            ]
        EOF

        template_id = cli_create('onetemplate create', template)
        id = cli_create("onetemplate instantiate #{template_id} --hold")

        xml_ds = cli_action_xml('onedatastore show -x default')

        xml = cli_action_xml("onevm show -x #{id}")

        expect(xml["TEMPLATE/DISK[IMAGE_ID='#{@img_id}']/TM_MAD_SYSTEM"]).to be_nil
        expect(xml["TEMPLATE/DISK[IMAGE_ID='#{@img_id}']/LN_TARGET"]).to eq(xml_ds['TEMPLATE/LN_TARGET'])
        expect(xml["TEMPLATE/DISK[IMAGE_ID='#{@img_id}']/CLONE_TARGET"]).to eq(xml_ds['TEMPLATE/CLONE_TARGET'])

        cli_action("onevm release #{id}")

        cli_action("onevm deploy #{id} #{@host_id} #{@ds_id}")

        vm = VM.new(id)

        vm.running?

        xml_ds = cli_action_xml('onedatastore show -x default')

        xml = cli_action_xml("onevm show -x #{id}")

        expect(xml["TEMPLATE/DISK[IMAGE_ID='#{@img_id}']/TM_MAD_SYSTEM"].upcase).to eq 'SSH'
        expect(xml["TEMPLATE/DISK[IMAGE_ID='#{@img_id}']/LN_TARGET"]).to eq(xml_ds['TEMPLATE/LN_TARGET_SSH'])
        expect(xml["TEMPLATE/DISK[IMAGE_ID='#{@img_id}']/CLONE_TARGET"]).to eq(xml_ds['TEMPLATE/CLONE_TARGET_SSH'])
        expect(xml["TEMPLATE/DISK[IMAGE_ID='#{@img_id}']/DISK_TYPE"]).to eq(xml_ds['TEMPLATE/DISK_TYPE_SSH'])

        cli_action("onevm terminate --hard #{id}")

        cli_action('onedatastore enable system') # dummy
        cli_action('onedatastore disable system_ssh') # ssh
    end

    it 'should instantiate template without persistent flag' do
        template = <<-EOF
            NAME   = template_test_nonpersistent
            CPU = 0.1
            MEMORY = 128
            DISK =  [
                IMAGE_ID = #{@img_id}
            ]
        EOF

        template_id = cli_create('onetemplate create', template)

        id = cli_create("onetemplate instantiate --name nonpers #{template_id}")

        vm = VM.new(id)
        xml = vm.info

        # Check new disk has new image ID and has not persistent flag
        expect(xml['TEMPLATE/DISK[DISK_ID="0"]/IMAGE_ID'].to_i).to eq(@img_id)
        expect(xml['TEMPLATE/DISK[DISK_ID="0"]/PERSISTENT']).to be_nil

        vm.terminate_hard
    end

    it 'should instantiate template with persistent flag' do
        template = <<-EOF
            NAME   = template_test_persistent
            CPU = 0.1
            MEMORY = 128
            DISK =  [
                IMAGE_ID = #{@img_id}
            ]
        EOF

        template_id = cli_create('onetemplate create', template)

        id = cli_create("onetemplate instantiate --name pers --persistent #{template_id}")

        vm = VM.new(id)
        xml = vm.info

        # Check new disk has new image ID and has persistent flag
        expect(xml['TEMPLATE/DISK[DISK_ID="0"]/IMAGE_ID']).not_to eq(@img_id)
        expect(xml['TEMPLATE/DISK[DISK_ID="0"]/PERSISTENT']).to eq('YES')

        vm.terminate_hard
    end

    it 'extra template should remove (override) disk/nic/sched_action values' do
        template = <<-EOF
            NAME   = template_override
            CPU = 0.1
            MEMORY = 128
            DISK =  [
                IMAGE_ID = #{@img_id}]
            NIC = [
                NETWORK = "vnet_A",
                NETWORK_UNAME = "oneadmin" ]
            SCHED_ACTION = [
                ACTION = "hold",
                TIME = 1 ]
        EOF

        template_id = cli_create('onetemplate create', template)

        id = cli_create("onetemplate instantiate #{template_id}")

        vm = VM.new(id)
        xml = vm.info

        # Check disk, nic and sched action exists, if there is no extra template
        expect(xml['TEMPLATE/DISK']).not_to be_nil
        expect(xml['TEMPLATE/NIC']).not_to be_nil
        expect(xml['TEMPLATE/SCHED_ACTION']).not_to be_nil

        vm.terminate_hard

        # Set disk, nic, sched action as empty vector
        extra_template = <<-EOF
            DISK =  []
            NIC = []
            SCHED_ACTION = []
        EOF

        id = cli_create("onetemplate instantiate #{template_id}", extra_template)

        vm = VM.new(id)
        xml = vm.info

        # Check disk, nic and sched action exists
        expect(xml['TEMPLATE/DISK']).to be_nil
        expect(xml['TEMPLATE/NIC']).to be_nil
        expect(xml['TEMPLATE/SCHED_ACTION']).to be_nil

        vm.terminate_hard

        # In XML we can't set empty vector, any Single Attribute value can be used
        extra_template = <<-EOF
            <ROOT>
                <DISK>![CDATA[]]</DISK>
                <NIC> </NIC>
                <SCHED_ACTION>anything</SCHED_ACTION>
            </ROOT>
        EOF

        id = cli_create("onetemplate instantiate #{template_id}", extra_template)

        vm = VM.new(id)
        xml = vm.info

        # Check disk, nic and sched action exists
        expect(xml['TEMPLATE/DISK']).to be_nil
        expect(xml['TEMPLATE/NIC']).to be_nil
        expect(xml['TEMPLATE/SCHED_ACTION']).to be_nil

        vm.terminate_hard
    end

end
