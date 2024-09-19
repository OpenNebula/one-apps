require 'init_functionality'
require 'sunstone_test'
require 'sunstone/File'

RSpec.describe "Sunstone file tab", :type => 'skip' do

    before(:all) do
        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        @sunstone_test = SunstoneTest.new(@auth)
        @sunstone_test.login
        @file = Sunstone::FileImage.new(@sunstone_test)
    end

    before(:each) do
        sleep 10
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "should create a kernel file" do
        hash = {
            type: "KERNEL", # 3
            path: '/etc/passwd'
        }

        @file.create("test_kernel", hash)
        @sunstone_test.wait_resource_create("image", "test_kernel")
    end

    it "should check kernel file via UI" do
        hash = [
            { key: "Type", value: "KERNEL" }
        ]

        @file.check("test_kernel", hash)
    end

    it "should create a context file" do
        hash = {
            type: "CONTEXT", # 5
            path: '/etc/passwd'
        }

        @file.create("test_context", hash)

        @sunstone_test.wait_resource_create("image", "test_context")
        file = cli_action_xml("oneimage show -x test_context") rescue nil

        expect(file['TYPE']).to eql "5" # context
        expect(file['PATH']).to eql "/etc/passwd"
    end

    it "should create ramdisk file" do
        hash = {
            type: "RAMDISK", # 4
            path: '/etc/passwd'
        }

        @file.create("test_ramdisk", hash)

        @sunstone_test.wait_resource_create("image", "test_ramdisk")
        file = cli_action_xml("oneimage show -x test_ramdisk") rescue nil
    
        expect(file['TYPE']).to eql "4" # ramdisk
        expect(file['PATH']).to eql "/etc/passwd"
    end

    it "should update a kernel file" do
        hash = {
            info: [
                { key: "Type", value: "RAMDISK" }
            ],
            attr: [
                { key: "ERROR", value: "Testing attributes..." }
            ]
        }
        @file.update("test_kernel", "", hash)

        @sunstone_test.wait_resource_update("image", "test_kernel", { :key=>"TYPE", :value=>"4"}, 180)
        file = cli_action_xml("oneimage show -x test_kernel") rescue nil
    
        expect(file['TYPE']).to eql "4" # ramdisk
        expect(file['PATH']).to eql "/etc/passwd"
        expect(file['TEMPLATE/ERROR']).to eql "Testing attributes..."
    end

    it "should delete a context file" do
        @file.delete("test_context")

        @sunstone_test.wait_resource_delete("image", "test_context")
        xml = cli_action_xml("oneimage list -x") rescue nil
        if !xml.nil?
            expect(xml['IMAGE[NAME="test_context"]']).to be(nil)
        end
    end

    it "should create a file advanced mode" do
        file_template = <<-EOT
            NAME = test-file-advanced
            TYPE = CONTEXT
            PATH = /etc/passwd
        EOT

        @file.create_advanced(file_template)

        @sunstone_test.wait_resource_create("image", "test-file-advanced")
        file = cli_action_xml("oneimage show -x test-file-advanced") rescue nil

        expect(file['TYPE']).to eql "5" # context
        expect(file['PATH']).to eql "/etc/passwd"
    end

end
