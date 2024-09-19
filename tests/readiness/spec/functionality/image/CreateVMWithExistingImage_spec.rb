#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Create a VirtualMachine using an Image test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update("onedatastore update system", mads, false)
        cli_update("onedatastore update default", mads, false)

        wait_loop do
            xml = cli_action_xml("onedatastore show -x default")
            xml['FREE_MB'].to_i > 0
        end

        @iid1 = cli_create("oneimage create -d default --type OS"\
                          " --name testimage1 --path /etc/passwd")

        @iid2 = cli_create("oneimage create -d default --type OS --format qcow2"\
                          " --name testimage2 --target hdj --path /etc/passwd")

        wait_loop() {
            xml1 = cli_action_xml("oneimage show -x #{@iid1}")
            xml2 = cli_action_xml("oneimage show -x #{@iid2}")
            ( xml1['STATE'] == '1' ) && ( xml2['STATE'] == '1' )
        }

        @host_id = cli_create("onehost create dummy -i dummy -v dummy")
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should allocate a new VirtualMachine that uses an existing Image" do
        vmid = cli_create("onevm create --name test --cpu 1 --memory 128"\
                          " --disk testimage2")

        xml  = cli_action_xml("onevm show -x #{vmid}")

        expect(xml['TEMPLATE/DISK/TARGET']).to eq('hdj')
        expect(xml['TEMPLATE/DISK/DRIVER']).to eq('dummy_format')
        expect(xml['TEMPLATE/DISK/SOURCE']).to eq('dummy_path')

        cli_action("onevm terminate #{vmid}")
    end

    it "should allocate a new VirtualMachine an overwrite Image attributes" do
        vmid = cli_create("onevm create --name test --cpu 1 --memory 128"\
                          " --disk testimage2:target=vdb:driver=raw")

        xml  = cli_action_xml("onevm show -x #{vmid}")

        expect(xml['TEMPLATE/DISK/TARGET']).to eq('vdb')
        expect(xml['TEMPLATE/DISK/DRIVER']).to eq('dummy_format')
        expect(xml['TEMPLATE/DISK/SOURCE']).to eq('dummy_path')

        cli_action("onevm terminate #{vmid}")
    end

    it "should allocate a new VirtualMachine an generate a target for it" do
        vmid = cli_create("onevm create --name test --cpu 1 --memory 128"\
                          " --disk testimage1")

        xml  = cli_action_xml("onevm show -x #{vmid}")

        expect(xml['TEMPLATE/DISK/TARGET']).to eq('sda')

        cli_action("onevm terminate #{vmid}")
    end

    it "should not allocate a new VirtualMachine using a non-exist Image " do
        vmid = cli_create("onevm create --name test --cpu 1 --memory 128"\
                          " --disk noexists", nil, false)
    end

    it "should not allocate a new VirtualMachine that uses a disabled Image" do
        wait_loop() {
            cli_action_xml("oneimage show -x testimage1")['RUNNING_VMS'] == '0'
        }

        cli_action("oneimage disable testimage1")

        vmid = cli_create("onevm create --name test --cpu 1 --memory 128"\
                          " --disk testimage1", nil, false)

        cli_action("oneimage enable testimage1")
    end

    it "should not allocate a VirtualMachine with a persistent image in use" do
        cli_action("oneimage persistent testimage1")

        vmid = cli_create("onevm create --name test --cpu 1 --memory 128"\
                          " --disk testimage1")

        cli_create("onevm create --name test --cpu 1 --memory 128"\
                          " --disk testimage1", nil, false)

        cli_action("oneimage delete testimage1", false)

        cli_action("onevm terminate #{vmid}")

        wait_loop() {
            cli_action_xml("oneimage show -x testimage1")['RUNNING_VMS'] == '0'
        }

        cli_action("oneimage nonpersistent testimage1")
    end

    it "should allocate VirtualMachine with a swap disk" do
        vmid = cli_create("onevm create --name test --cpu 1 --memory 128"\
          " --disk testimage1 --raw \"DISK=[TYPE=swap, SIZE=100]\"")

        cli_action("onevm deploy #{vmid} #{@host_id}")

        vm = VM.new(vmid)
        vm.running?

        xml = vm.xml

        expect(xml['TEMPLATE/DISK[ TYPE = "swap"]/TARGET']).to eq('sdb')

        cli_action("onevm terminate #{vmid}")

        vmid = cli_create("onevm create --name test --cpu 1 --memory 128"\
          " --disk testimage1 --raw \"DISK=[TYPE=swap, SIZE=100, TARGET=vda]\"")

        cli_action("onevm deploy #{vmid} #{@host_id}")

        vm = VM.new(vmid)
        vm.running?

        xml = vm.xml

        expect(xml['TEMPLATE/DISK[ TYPE = "swap"]/TARGET']).to eq('vda')
        expect(xml['TEMPLATE/DISK[ TYPE = "swap"]/FORMAT']).to eq('raw')
        expect(xml['TEMPLATE/DISK[ TYPE = "swap"]/DRIVER']).to eq('raw')

        cli_action("onevm terminate #{vmid}")
    end

    it "should fail to create VM with shareable disk (no support from hypervisor)" do
        iid_raw = cli_create("oneimage create -d default --type DATABLOCK "\
            "--format raw --name image_pers --size 1 --persistent")

        cli_update("oneimage update image_pers",
            "PERSISTENT_TYPE=\"shareable\"", true)

        wait_loop() {
            xml = cli_action_xml("oneimage show -x #{iid_raw}")
            xml['STATE'] == '1'
        }

        vmid = cli_create("onevm create --name test --cpu 1 --memory 128"\
                   " --disk #{iid_raw} --hold")

        cli_action("onevm deploy #{vmid} #{@host_id}", false)
        cli_action("onevm terminate #{vmid}")
    end

    it "should track VM IDs using the image" do
        vmid = cli_create("onevm create --name test --cpu 1 --memory 128"\
                          " --disk testimage1")

        cli_action("onevm deploy #{vmid} #{@host_id}")

        vm = VM.new(vmid)
        vm.running?

        image = cli_action_xml("oneimage show -x testimage1")

        expect(image['RUNNING_VMS']).to eq('1')
        expect(image['VMS/ID']).to eq(vmid.to_s)

        # Attach other image
        cli_action("onevm disk-attach #{vmid} -i testimage2")

        vm.running?

        image = cli_action_xml("oneimage show -x testimage2")

        expect(image['RUNNING_VMS']).to eq('1')
        expect(image['VMS/ID']).to eq(vmid.to_s)

        # Dettach attached image
        cli_action("onevm disk-detach #{vmid} 1")

        vm.running?

        image = cli_action_xml("oneimage show -x testimage2")

        expect(image['RUNNING_VMS']).to eq('0')
        expect(image['VMS/ID']).to be(nil)

        # Attach image which is already attached, running_vms should remain 1
        cli_action("onevm disk-attach #{vmid} -i testimage1")

        vm.running?

        image = cli_action_xml("oneimage show -x testimage1")

        expect(image['RUNNING_VMS']).to eq('1')
        expect(image['VMS/ID']).to eq(vmid.to_s)

        # Detach image, running_vms should be still 1
        cli_action("onevm disk-detach #{vmid} 1")

        vm.running?

        image = cli_action_xml("oneimage show -x testimage1")

        expect(image['RUNNING_VMS']).to eq('1')
        expect(image['VMS/ID']).to eq(vmid.to_s)

        cli_action("onevm terminate #{vmid}")

        vm.done?

        image = cli_action_xml("oneimage show -x testimage1")

        expect(image['RUNNING_VMS']).to eq('0')
        expect(image['VMS/ID']).to be(nil)
    end


end

