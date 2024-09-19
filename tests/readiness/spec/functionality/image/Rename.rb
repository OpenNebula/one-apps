#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Rename Images test"  do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update("onedatastore update default", mads, false)

        wait_loop do
            xml = cli_action_xml("onedatastore show -x default")
            xml['FREE_MB'].to_i > 0
        end
    end

    before(:each) do
        @img_id = cli_create("oneimage create -d 1 --name test_name --source "\
                            "/no/path --size 200 --format raw")
    end

    after(:each) do
        delete_image(@img_id)
    end

    def delete_image(img_id_name)
        cli_action("oneimage delete #{img_id_name}")

        wait_loop do
            cmd = cli_action("oneimage show #{img_id_name}", nil)
            !cmd.success?
        end
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should rename an image and check the list and show commands" do
        expect(cli_action("oneimage list").stdout).to match(/test_name/)
        expect(cli_action("oneimage show test_name").stdout).to match(/NAME *: *test_name/)

        cli_action("oneimage rename test_name new_name")

        expect(cli_action("oneimage list").stdout).to_not match(/test_name/)
        cli_action("oneimage show test_name", false)

        expect(cli_action("oneimage list").stdout).to match(/new_name/)
        expect(cli_action("oneimage show new_name").stdout).to match(/NAME *: *new_name/)
    end

    it "should rename an image, restart opennebula and check its name" do
        expect(cli_action("oneimage list").stdout).to match(/test_name/)
        expect(cli_action("oneimage show test_name").stdout).to match(/NAME *: *test_name/)

        cli_action("oneimage rename test_name new_name")

        @one_test.stop_one()
        @one_test.start_one()

        expect(cli_action("oneimage list").stdout).to_not match(/test_name/)
        cli_action("oneimage show test_name", false)

        expect(cli_action("oneimage list").stdout).to match(/new_name/)
        expect(cli_action("oneimage show new_name").stdout).to match(/NAME *: *new_name/)
    end

    it "should try to rename an image to an existing name, and fail" do
        cli_create("oneimage create -d 1 --name foo --source /no/path --size 200 --format raw")
        cli_action("oneimage rename foo test_name", false)

        expect(cli_action("oneimage list").stdout).to match(/test_name/)
        expect(cli_action("oneimage show test_name").stdout).to match(/NAME *: *test_name/)
        expect(cli_action("oneimage list").stdout).to match(/foo/)
        expect(cli_action("oneimage show foo").stdout).to match(/NAME *: *foo/)

        delete_image("foo")
    end

    it "should rename an image to an existing name, case sensitive" do

        # Require binary collate on mysql backend
        if @main_defaults && @main_defaults[:db] \
                && @main_defaults[:db]['BACKEND'] == 'mysql'
                skip 'Does not work with mysql DB backend'
        end

        cli_create("oneimage create -d 1 --name foo1 --source /no/path --size 200 --format raw")
        cli_action("oneimage rename foo1 TeSt_NAmE")

        expect(cli_action("oneimage list").stdout).to match(/test_name/)
        expect(cli_action("oneimage show test_name").stdout).to match(/NAME *: *test_name/)
        expect(cli_action("oneimage list").stdout).to match(/TeSt_NAmE/)
        expect(cli_action("oneimage show TeSt_NAmE").stdout).to match(/NAME *: *TeSt_NAmE/)

        delete_image("TeSt_NAmE")
    end

    it "should rename an image to an existing name but with different owner" do
        cli_create_user("uA", "abc")

        as_user "uA" do
            img_id = cli_create("oneimage create -d 1 --name test_name --path "\
                                "/etc/passwd --size 200")
            wait_loop() do
                xml = cli_action_xml("oneimage show -x #{img_id}")
                Image::IMAGE_STATES[xml['STATE'].to_i] == "READY"
            end
            delete_image(img_id)
        end
    end
end
