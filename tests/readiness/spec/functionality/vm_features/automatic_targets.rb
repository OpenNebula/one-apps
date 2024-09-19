
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

require 'tempfile'

describe "VirtualMachine automatic target assignment test" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do
        @tmp_file = Tempfile.new('one')
        tmp_file_path = @tmp_file.path

        cli_update("onedatastore update system", "TM_MAD=dummy", false)
        cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)
        wait_loop() {
            xml = cli_action_xml("onedatastore show -x default")
            xml['FREE_MB'].to_i > 0
        }

        cli_create("oneimage create -d default --name os_img --type os " <<
                   "--path #{tmp_file_path}")

        cli_create("oneimage create -d default --name os_img_2 --type os " <<
                   "--path #{tmp_file_path}")

        cli_create("oneimage create -d default --name cd_img --type cdrom " <<
                   "--path #{tmp_file_path}")

        cli_create("oneimage create -d default --name cd_img_2 --type cdrom " <<
                   "--path #{tmp_file_path}")

        cli_create("oneimage create -d default --name db_img --type datablock " <<
                   "--path #{tmp_file_path}")

        cli_create("oneimage create -d default --name db_img_xvd " <<
                   "--type datablock --prefix xvd " <<
                   "--path #{tmp_file_path}")

        cli_create("oneimage create -d default --name db_img_sd " <<
                   "--type datablock --prefix sd " <<
                   "--path #{tmp_file_path}")

        cli_create("oneimage create -d default --name db_img_sdd " <<
                   "--type datablock --target sdd " <<
                   "--path #{tmp_file_path}")

        cli_create("oneimage create -d default --name db_img_sde " <<
                   "--type datablock --target sde " <<
                   "--path #{tmp_file_path}")
    end

    after(:each) do
        system("onevm recover --delete test_vm")
    end

    it "should create a new VM without context and check targets" do
        cli_create("onevm create --cpu 1 --memory 1 --name test_vm " <<
                   "--disk cd_img,db_img,os_img")

        vm_xml = cli_action_xml("onevm show test_vm -x")

        expect(vm_xml["TEMPLATE/DISK[IMAGE='os_img']/TARGET"]).to eql("sda")
        expect(vm_xml["TEMPLATE/DISK[IMAGE='cd_img']/TARGET"]).to eql("hda")
        expect(vm_xml["TEMPLATE/DISK[IMAGE='db_img']/TARGET"]).to eql("sdb")
    end

    it "should create a new VM with context and check targets" do
        cli_create("onevm create --cpu 1 --memory 1 --name test_vm " <<
                   "--disk cd_img,db_img,os_img --context a=b")

        vm_xml = cli_action_xml("onevm show test_vm -x")

        expect(vm_xml["TEMPLATE/DISK[IMAGE='os_img']/TARGET"]).to eql("sda")
        expect(vm_xml["TEMPLATE/DISK[IMAGE='cd_img']/TARGET"]).to eql("hda")
        expect(vm_xml["TEMPLATE/CONTEXT/TARGET"]).to eql("hdb")
        expect(vm_xml["TEMPLATE/DISK[IMAGE='db_img']/TARGET"]).to eql("sdb")
    end

    it "should create a new VM with multiple OS and CD and check targets" do
        cli_create("onevm create --cpu 1 --memory 1 --name test_vm " <<
                   "--disk cd_img,db_img,os_img,cd_img_2,os_img_2 " <<
                   "--context a=b")

        vm_xml = cli_action_xml("onevm show test_vm -x")

        expect(vm_xml["TEMPLATE/DISK[IMAGE='os_img']/TARGET"]).to eql("sda")
        expect(vm_xml["TEMPLATE/DISK[IMAGE='cd_img']/TARGET"]).to eql("hda")
        expect(vm_xml["TEMPLATE/DISK[IMAGE='cd_img_2']/TARGET"]).to eql("hdb")
        expect(vm_xml["TEMPLATE/CONTEXT/TARGET"]).to eql("hdc")
        expect(vm_xml["TEMPLATE/DISK[IMAGE='db_img']/TARGET"]).to eql("sdb")
        expect(vm_xml["TEMPLATE/DISK[IMAGE='os_img_2']/TARGET"]).to eql("sdc")
    end

    it "should create a new VM with targets and check targets" do
        cli_create("onevm create --cpu 1 --memory 1 --name test_vm " <<
                   "--disk cd_img,db_img:target=hdb,os_img " <<
                   "--context a=b")

        vm_xml = cli_action_xml("onevm show test_vm -x")

        expect(vm_xml["TEMPLATE/DISK[IMAGE='os_img']/TARGET"]).to eql("sda")
        expect(vm_xml["TEMPLATE/DISK[IMAGE='db_img']/TARGET"]).to eql("hdb")
        expect(vm_xml["TEMPLATE/DISK[IMAGE='cd_img']/TARGET"]).to eql("hda")
        expect(vm_xml["TEMPLATE/CONTEXT/TARGET"]).to eql("hdc")
    end

    it "should create a new VM with different buses and check targets" do
        cli_create("onevm create --cpu 1 --memory 1 --name test_vm " <<
                   "--disk cd_img,db_img_xvd,db_img_sd,os_img " <<
                   "--context a=b")

        vm_xml = cli_action_xml("onevm show test_vm -x")

        expect(vm_xml["TEMPLATE/DISK[IMAGE='os_img']/TARGET"]).to eql("sda")
        expect(vm_xml["TEMPLATE/DISK[IMAGE='cd_img']/TARGET"]).to eql("hda")
        expect(vm_xml["TEMPLATE/CONTEXT/TARGET"]).to eql("hdb")

        expect(vm_xml["TEMPLATE/DISK[IMAGE='db_img_xvd']/TARGET"]).to eql("xvda")
        expect(vm_xml["TEMPLATE/DISK[IMAGE='db_img_sd']/TARGET"]).to eql("sdb")
    end


    it "should check the target precedence" do
        cli_create("onevm create --cpu 1 --memory 1 --name test_vm " <<
                   "--disk db_img_sdd:target=hdb,db_img_sde")

        vm_xml = cli_action_xml("onevm show test_vm -x")

        expect(vm_xml["TEMPLATE/DISK[IMAGE='db_img_sdd']/TARGET"]).to eql("hdb")
        expect(vm_xml["TEMPLATE/DISK[IMAGE='db_img_sde']/TARGET"]).to eql("sde")
    end

    it "should set the same target twice and check the error" do
        o = cli_action("onevm create --cpu 1 --memory 1 --name test_vm " <<
                   "--disk db_img_sdd:target=sde,db_img_sde", false)

        expect(o.stderr).to match /Two disks have defined the same target sde/
    end
end
