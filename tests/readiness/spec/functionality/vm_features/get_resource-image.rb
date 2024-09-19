
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

describe "VirtualMachine get IMAGE in DISK section test" do
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

        @image = cli_create("oneimage create --name testimage --type os " <<
                            "--target hda --path #{tmp_file_path} -d default")

        wait_loop do
            xml = cli_action_xml("oneimage show -x #{@image}")
            xml["STATE"] == "1"
        end

        img_xml = cli_action_xml("oneimage show -x #{@image}")
        @image_source = img_xml["SOURCE"]
    end

    it "should get the image by its id" do
        vm_id = cli_create("onevm create --name test --cpu 1 --memory 1 " <<
                           "--disk #{@image}")

        xml = cli_action_xml("onevm show -x #{vm_id}")
        expect(xml["TEMPLATE/DISK[1]/SOURCE"]).to eq @image_source
    end

    it "should get the image by its name" do
        vm_id = cli_create("onevm create --name test --cpu 1 --memory 1 " <<
                           "--disk testimage")

        xml = cli_action_xml("onevm show -x #{vm_id}")
        expect(xml["TEMPLATE/DISK[1]/SOURCE"]).to eq @image_source
    end

    it "should get the image by its name and uid" do
        vm_id = cli_create("onevm create --name test --cpu 1 --memory 1 " <<
                           "--disk testimage:image_uid=0")

        xml = cli_action_xml("onevm show -x #{vm_id}")
        expect(xml["TEMPLATE/DISK[1]/SOURCE"]).to eq @image_source
    end

    it "should get the image by its name and uname" do
        cli_create_user("userA", "passwordA")

        image = false

        as_user("userA") do
            image = cli_create("oneimage create --name testimage --type os " <<
                               "--target hda --path #{@tmp_file.path} " <<
                               "-d default")
        end

        vm_id = cli_create("onevm create --name test --cpu 1 --memory 1 " <<
                           "--disk testimage:image_uname=userA")

        img_xml = cli_action_xml("oneimage show -x #{image}")
        image_source = img_xml["SOURCE"]

        xml = cli_action_xml("onevm show -x #{vm_id}")
        expect(xml["TEMPLATE/DISK[1]/SOURCE"]).to eq image_source
    end

    it "should not create a VM with non existent image" do
        cli_action("onevm create --name test --cpu 1 --memory 1 " <<
                   "--disk testimage:image_uid=3", false)

        cli_action("onevm create --name test --cpu 1 --memory 1 " <<
                   "--disk DOES_NOT_EXIST", false)

        cli_action("onevm create --name test --cpu 1 --memory 1 " <<
                   "--disk testimage:image_uname=userB", false)

        cli_action("onevm create --name test --cpu 1 --memory 1 " <<
                   "--disk 23", false)
    end
end