#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Image precedence test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        wait_loop do
            xml = cli_action_xml("onedatastore show -x default")
            xml['FREE_MB'].to_i > 0
        end
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should create a new image with FORMAT" do
        template = <<-EOF
            NAME   = testimage_driver
            TYPE   = OS
            FORMAT = qcow2
            SIZE   = 1
        EOF

        iid = cli_create("oneimage create -d default", template)

        xml = cli_action_xml("oneimage show -x #{iid}")

        expect(xml['FORMAT']).to eq('qcow2')
        expect(xml['TEMPLATE/DRIVER']).to eq(nil)
    end

    it "should create a new image without FORMAT" do
        template = <<-EOF
            NAME   = testimage_not_driver
            TYPE   = OS
            SIZE   = 1
        EOF

        iid = cli_create("oneimage create -d default", template)

        xml = cli_action_xml("oneimage show -x #{iid}")

        expect(xml['FORMAT']).to eq('raw')
        expect(xml['TEMPLATE/DRIVER']).to eq(nil)
    end

    it "should check DS DRIVER priority" do
        mads = "TM_MAD=dummy\nDS_MAD=dummy\nDRIVER=in_ds"

        cli_update("onedatastore update system", mads, false)
        cli_update("onedatastore update default", mads, false)

        wait_loop do
            xml = cli_action_xml("onedatastore show -x default")
            xml['FREE_MB'].to_i > 0
        end

        template = <<-EOF
            NAME   = testimage_driver_2
            TYPE   = OS
            SIZE   = 1
            FORMAT = in_image
        EOF

        iid = cli_create("oneimage create -d default", template)

        xml = cli_action_xml("oneimage show -x #{iid}")

        expect(xml['FORMAT']).to eq('in_ds')
        expect(xml['TEMPLATE/DRIVER']).to eq('in_ds')
    end
end
