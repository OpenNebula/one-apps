require 'init_functionality'
require 'sunstone_test'
require 'sunstone/Image'

RSpec.describe "Sunstone image tab", :type => 'skip' do

    before(:all) do
        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        # Create file to upload
        file = File.new("file.txt", "w")
        file.puts("test")
        file.close

        @sunstone_test = SunstoneTest.new(@auth)
        @sunstone_test.login
        @image = Sunstone::Image.new(@sunstone_test)
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "should create an OS image" do
        hash = {
            name: "test_os",
            type: "OS",
            path: "/etc/passwd",
            bus: "vd"
        }

        @image.create(hash)
        @sunstone_test.wait_resource_create("image", "test_os")
    end

    it "should check an OS image via UI" do
        hash_info = [
            { key: "Type", value: "OS" }
        ]

        @image.check("test_os", hash_info)
    end

    it "should create a datablock image" do
        hash = {
            name: "test_datablock",
            type: "DATABLOCK",
            size: "2",
            bus: "vd"
        }

        @image.create(hash)

        @sunstone_test.wait_resource_create("image", "test_datablock")
        img = cli_action_xml("oneimage show -x test_datablock") rescue nil
    
        expect(img['TEMPLATE/DEV_PREFIX']).to eql "vd"
        expect(img['TYPE']).to eql "2" # datablock
        expect(img['PERSISTENT']).to eql "0" # no
    end

    it "should update a persistent OS image" do
        hash = {
            info: [
                { key: "Type", value: "DATABLOCK" }, # os -> datablock
                { key: "Persistent", value: "yes" }
            ]
        }

        @image.update("test_os", "image_updated", hash)
        @image.check_persistent()

        @sunstone_test.wait_resource_update("image", "image_updated", { :key=>"TYPE", :value=>"2" }, 180)
        img = cli_action_xml("oneimage show -x image_updated") rescue nil

        expect(img['TEMPLATE/DEV_PREFIX']).to eql "vd"
        expect(img['TYPE']).to eql "2" # datablock
        expect(img['PERSISTENT']).to eql "1" # yes
    end

    it "should delete a datablock image" do
        @image.delete("test_datablock")

        @sunstone_test.wait_resource_delete("image", "test_datablock")
        xml = cli_action_xml("oneimage list -x") rescue nil
        if !xml.nil?
            expect(xml['IMAGE[NAME="test_datablock"]']).to be(nil)
        end
    end

    it "should upload and image" do
        file_path = Dir.pwd + "/file.txt"

        hash = {
            name: "test_upload",
            type: "DATABLOCK",
            upload: file_path
        }

        # Update datastore default['SAFE_DIRS'] = /tmp
        cli_update("onedatastore update default", "SAFE_DIRS=/tmp", false)
        cli_update("onedatastore update files", "SAFE_DIRS=/tmp", false)

        @image.create(hash)
        @sunstone_test.wait_resource_create("image", hash[:name])

        image = cli_action_xml("oneimage show -x test_upload") rescue nil
        expect(image['TYPE']).to eql "2" #datablock
        expect(image['STATE']).to eql "1" #ready

        begin
            File.open(file_path, 'r') do |f|
                File.delete(f)
            end
        rescue Errno::ENOENT
        end
    end

    it "should create an image in advanced mode" do
        image_template = <<-EOT
            NAME = test-image-advanced
            TYPE = DATABLOCK
            FS = ext3
            SIZE = 1024
        EOT

        @image.create_advanced(image_template)

        @sunstone_test.wait_resource_create("image", "test-image-advanced")
        image = cli_action_xml("oneimage show -x test-image-advanced") rescue nil
        expect(image['TYPE']).to eql "2" #datablock
        expect(image['FS']).to eql "ext3"
        expect(image['SIZE']).to eql "1024"
    end

    it "should create and check dockerfile" do
      hash = {
        name: "test_dockerfile",
        datastore: "1",
        context: "yes",
        size: "1",
        dockerfile: "pepe"
      }
      @image.create_dockerfile(hash)
      @sunstone_test.wait_resource_create("image", hash[:name])
      img = cli_action_xml("oneimage show -x #{hash[:name]}") rescue nil
      expect(img['NAME']).to eql hash[:name]
      expect(img['DATASTORE_ID']).to eql hash[:datastore]
      expect(img['SIZE']).to eql hash[:size]
    end
end
