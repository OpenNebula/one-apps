require 'init_functionality'
require 'VN'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

describe 'Attach/Detach disks to/from a VM' do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__), 'defaults.yaml')
    end

    before(:all) do
        cli_update('onedatastore update default', "TM_MAD=dummy\nDS_MAD=dummy", false)
        wait_loop do
            xml = cli_action_xml('onedatastore show -x default')
            xml['FREE_MB'].to_i > 0
        end

        cli_create_user('uA', 'abc')

        cli_create('onegroup create gA')
        cli_action('oneuser chgrp uA gA')

        cli_action('onevdc create vdcA')
        cli_action('onevdc addgroup vdcA gA')
        cli_action('onevdc addcluster vdcA 0 ALL')

        cli_create('onehost create host0 --im dummy --vm dummy')

        net = VN.create(<<-EOT)
            NAME = "test_vnet"
            VN_MAD = "dummy"
            BRIDGE = "dummy"
        EOT
        net.ready?

        cli_action('onevnet addar test_vnet --ip 10.0.0.1 --size 255')
        cli_action('onevnet chown test_vnet uA')

        as_user('uA') do
            @img1_id = cli_create('oneimage create -d 1', <<-EOT)
                NAME = "test_img1"
                TYPE = "DATABLOCK"
                FSTYPE = "ext3"
                SIZE = 1000
            EOT
            wait_loop do
                xml = cli_action_xml("oneimage show -x #{@img1_id}")
                Image::IMAGE_STATES[xml['STATE'].to_i] == 'READY'
            end

            @img2_id = cli_create('oneimage create -d 1', <<-EOT)
                name = "test_img2"
                type = "DATABLOCK"
                fstype = "ext3"
                size = 1000
            EOT
            wait_loop do
                xml = cli_action_xml("oneimage show -x #{@img2_id}")
                Image::IMAGE_STATES[xml['STATE'].to_i] == 'READY'
            end

            @id = cli_create('onevm create --hold', <<-EOT)
                NAME = "test_vm"
                MEMORY = "1024"
                CPU    = "1"
                NIC = [NETWORK = "test_vnet"]
                DISK = [IMAGE = "test_img1"]
                TM_MAD_SYSTEM = "ssh"
            EOT

            @vm = VM.new(@id)
        end
    end

    it 'should fail to attach to a disk to a non-running VM' do
        as_user('uA') do
            cli_action("onevm disk-attach #{@id} --image #{@img2_id}", false)

            uxml = cli_action_xml('oneuser show -x')

            expect(uxml['VM_QUOTA/VM/CPU_USED']).to eq('1')
            expect(uxml['VM_QUOTA/VM/MEMORY_USED']).to eq('1024')

            expect(uxml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eq('1')
            expect(uxml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to be_nil
            expect(uxml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq('1000')

            img1 = cli_action_xml("oneimage show -x #{@img1_id}")
            expect(img1['STATE']).to eq('2') # used

            img2 = cli_action_xml("oneimage show -x #{@img2_id}")
            expect(img2['STATE']).to eq('1') # ready

            i1xml = cli_action_xml("oneimage show #{@img1_id} -x")
            i2xml = cli_action_xml("oneimage show #{@img2_id} -x")

            expect(i1xml['RUNNING_VMS']).to eq('1')
            expect(i2xml['RUNNING_VMS']).to eq('0')
        end
    end

    it 'should attach a disk image to a VM and update user quotas' do
        cli_action("onevm deploy #{@id} 0")

        @vm.running?

        as_user('uA') do
            cli_action("onevm disk-attach #{@id} --image #{@img2_id}")

            @vm.running?

            vxml = cli_action_xml("onevm show -x #{@id}")

            expect(vxml["TEMPLATE/DISK[DISK_ID='1']/IMAGE_ID"]).to eql "#{@img2_id}"

            uxml = cli_action_xml('oneuser show -x')

            expect(uxml['VM_QUOTA/VM/CPU_USED']).to eql '1'
            expect(uxml['VM_QUOTA/VM/MEMORY_USED']).to eql '1024'

            expect(uxml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eq '1'
            expect(uxml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eq '1'
            expect(uxml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eq '2000'

            img1 = cli_action_xml("oneimage show -x #{@img1_id}")
            expect(img1['STATE']).to eq('2') # used

            img2 = cli_action_xml("oneimage show -x #{@img2_id}")
            expect(img2['STATE']).to eq('2') # used

            i1xml = cli_action_xml("oneimage show #{@img1_id} -x")
            i2xml = cli_action_xml("oneimage show #{@img2_id} -x")

            expect(i1xml['RUNNING_VMS']).to eq '1'
            expect(i2xml['RUNNING_VMS']).to eq '1'

            xml_ds = cli_action_xml('onedatastore show -x default')

            expect(vxml["TEMPLATE/DISK[IMAGE_ID='#{@img1_id}']/TM_MAD_SYSTEM"].upcase).to eq 'SSH'

            expect(vxml["TEMPLATE/DISK[IMAGE_ID='#{@img1_id}']/LN_TARGET"]).to eq(xml_ds['TEMPLATE/LN_TARGET_SSH'])
            expect(vxml["TEMPLATE/DISK[IMAGE_ID='#{@img1_id}']/CLONE_TARGET"]).to eq(xml_ds['TEMPLATE/CLONE_TARGET_SSH'])
            expect(vxml["TEMPLATE/DISK[IMAGE_ID='#{@img1_id}']/DISK_TYPE"]).to eq(xml_ds['TEMPLATE/DISK_TYPE_SSH'])
            expect(vxml['TEMPLATE/AUTOMATIC_DS_REQUIREMENTS']).to eq('("CLUSTERS/ID" @> 0) & (TM_MAD = "ssh")')
        end
    end

    it 'should attach a volatile disk to a VM and update user quotas' do
        @vm.running?

        as_user('uA') do
            cli_update("onevm disk-attach #{@id} --file", <<-EOT, false)
                DISK = [ TYPE = fs, SIZE = 20 ]
            EOT

            @vm.running?

            vxml = cli_action_xml("onevm show -x #{@id}")

            expect(vxml["TEMPLATE/DISK[DISK_ID='1']/IMAGE_ID"]).to eql "#{@img2_id}"
            expect(vxml["TEMPLATE/DISK[DISK_ID='2']/SIZE"]).to eql '20'

            uxml = cli_action_xml('oneuser show -x')

            expect(uxml['VM_QUOTA/VM/CPU_USED']).to eql '1'
            expect(uxml['VM_QUOTA/VM/MEMORY_USED']).to eql '1024'

            expect(uxml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql '1'
            expect(uxml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql '1'
            expect(uxml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eql '2020'

            img1 = cli_action_xml("oneimage show -x #{@img1_id}")
            expect(img1['STATE']).to eq('2') # used

            img2 = cli_action_xml("oneimage show -x #{@img2_id}")
            expect(img2['STATE']).to eq('2') # used

            i1xml = cli_action_xml("oneimage show #{@img1_id} -x")
            i2xml = cli_action_xml("oneimage show #{@img2_id} -x")

            expect(i1xml['RUNNING_VMS']).to eql '1'
            expect(i2xml['RUNNING_VMS']).to eql '1'
        end
    end

    it 'should attach a disk image to a poweroff VM and update user quotas' do
        @vm.safe_poweroff

        as_user('uA') do
            cli_action("onevm disk-attach #{@id} --image #{@img2_id}")

            @vm.state?('POWEROFF')

            vxml = @vm.info

            expect(vxml["TEMPLATE/DISK[DISK_ID='1']/IMAGE_ID"]).to eql "#{@img2_id}"
            expect(vxml["TEMPLATE/DISK[DISK_ID='2']/SIZE"]).to eql '20'
            expect(vxml["TEMPLATE/DISK[DISK_ID='3']/IMAGE_ID"]).to eql "#{@img2_id}"

            uxml = cli_action_xml('oneuser show -x')

            expect(uxml['VM_QUOTA/VM/CPU_USED']).to eql '1'
            expect(uxml['VM_QUOTA/VM/MEMORY_USED']).to eql '1024'

            expect(uxml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql '1'
            expect(uxml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql '2'
            expect(uxml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eql '3020'

            img1 = cli_action_xml("oneimage show -x #{@img1_id}")
            expect(img1['STATE']).to eq('2') # used
            expect(img1['RUNNING_VMS']).to eql '1'

            img2 = cli_action_xml("oneimage show -x #{@img2_id}")
            expect(img2['STATE']).to eq('2') # used
            expect(img2['RUNNING_VMS']).to eql '1'
        end

        cli_action("onevm resume #{@id}")
        @vm.state?('RUNNING')
    end

    it 'should fail to attach a volatile disk with wrong size to a VM and update user quotas' do
        @vm.running?

        as_user('uA') do
            cli_update("onevm disk-attach #{@id} --file", <<-EOT, false, false)
                DISK = [ TYPE = fs, SIZE = "20.5" ]
            EOT

            @vm.running?

            vxml = @vm.info

            expect(vxml["TEMPLATE/DISK[DISK_ID='1']/IMAGE_ID"]).to eql "#{@img2_id}"
            expect(vxml["TEMPLATE/DISK[DISK_ID='2']/SIZE"]).to eql '20'
            expect(vxml["TEMPLATE/DISK[DISK_ID='3']/IMAGE_ID"]).to eql "#{@img2_id}"

            uxml = cli_action_xml('oneuser show -x')

            expect(uxml['VM_QUOTA/VM/CPU_USED']).to eql '1'
            expect(uxml['VM_QUOTA/VM/MEMORY_USED']).to eql '1024'

            expect(uxml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql '1'
            expect(uxml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql '2'
            expect(uxml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eql '3020'

            img1 = cli_action_xml("oneimage show -x #{@img1_id}")
            expect(img1['STATE']).to eq('2') # used
            expect(img1['RUNNING_VMS']).to eql '1'

            img2 = cli_action_xml("oneimage show -x #{@img2_id}")
            expect(img2['STATE']).to eq('2') # used
            expect(img2['RUNNING_VMS']).to eql '1'
        end
    end

    it 'should not detach a non-existing disk from a VM' do
        as_user('uA') do
            cli_action("onevm disk-detach #{@id} 23", false)
        end
    end

    it 'should detach a disk image from a VM and update user quotas' do
        as_user('uA') do
            cli_action("onevm disk-detach #{@id} 1")

            @vm.running?

            uxml = cli_action_xml('oneuser show -x')

            expect(uxml['VM_QUOTA/VM/CPU_USED']).to eql '1'
            expect(uxml['VM_QUOTA/VM/MEMORY_USED']).to eql '1024'

            expect(uxml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql '1'
            expect(uxml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql '1'
            expect(uxml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eql '2020'

            vxml = @vm.info

            expect(vxml["TEMPLATE/DISK[DISK_ID='1']"]).to be_nil
            expect(vxml["TEMPLATE/DISK[DISK_ID='2']/SIZE"]).to eql '20'
            expect(vxml["TEMPLATE/DISK[DISK_ID='3']/IMAGE_ID"]).to eql "#{@img2_id}"

            img1 = cli_action_xml("oneimage show -x #{@img1_id}")
            expect(img1['STATE']).to eq('2') # used
            expect(img1['RUNNING_VMS']).to eql '1'

            # *********************************************************
            # Fails because of bug #3888
            # *********************************************************
            # img2 = cli_action_xml("oneimage show -x #{@img2_id}")
            # expect(img2["STATE"]).to eq("2") # used
            # expect(img2["RUNNING_VMS"]).to eql "1"
        end
    end

    it 'should detach a volatile disk from a VM and update user quotas' do
        as_user('uA') do
            cli_action("onevm disk-detach #{@id} 2")

            @vm.running?

            uxml = cli_action_xml('oneuser show -x')

            expect(uxml['VM_QUOTA/VM/CPU_USED']).to eql '1'
            expect(uxml['VM_QUOTA/VM/MEMORY_USED']).to eql '1024'

            expect(uxml["IMAGE_QUOTA/IMAGE[ID='#{@img1_id}']/RVMS_USED"]).to eql '1'
            expect(uxml["IMAGE_QUOTA/IMAGE[ID='#{@img2_id}']/RVMS_USED"]).to eql '1'
            expect(uxml['VM_QUOTA/VM/SYSTEM_DISK_SIZE_USED']).to eql '2000'

            vxml = @vm.info

            expect(vxml["TEMPLATE/DISK[DISK_ID='1']"]).to be_nil
            expect(vxml["TEMPLATE/DISK[DISK_ID='2']"]).to be_nil
            expect(vxml["TEMPLATE/DISK[DISK_ID='3']/IMAGE_ID"]).to eql "#{@img2_id}"

            img1 = cli_action_xml("oneimage show -x #{@img1_id}")
            expect(img1['STATE']).to eq('2') # used
            expect(img1['RUNNING_VMS']).to eql '1'

            # ******************************************************************
            # Fails because of bug #3888
            # ******************************************************************
            # img2 = cli_action_xml("oneimage show -x #{@img2_id}")
            # expect(img2["STATE"]).to eq("2") # used
            # expect(img2["RUNNING_VMS"]).to eql "1"
        end
    end

    it 'should attach a volatile disk to a VM with a template via STDIN' do
        cmd = "onevm disk-attach #{@id}"

        template = <<~EOT
            DISK = [ TYPE = fs, SIZE = 69 ]
        EOT

        stdin_cmd = <<~BASH
            #{cmd} <<EOF
            #{template}
            EOF
        BASH

        cli_action(stdin_cmd)
        @vm.running?
        vxml = cli_action_xml("onevm show -x #{@id}")
        expect(vxml["TEMPLATE/DISK[DISK_ID='4']/SIZE"]).to eql '69'
    end
end
