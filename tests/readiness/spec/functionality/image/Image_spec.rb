#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
# ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
require 'image'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe 'Image operations test' do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        @cp_dummy  = "#{ONE_VAR_LOCATION}/remotes/datastore/dummy/cp"
        @rm_dummy  = "#{ONE_VAR_LOCATION}/remotes/datastore/dummy/rm"

        template = <<-EOF
            NAME   = testimage
            TYPE   = OS
            PATH   = #{Tempfile.new('functionality').path}
            ATT1   = VAL1
            ATT2   = VAL2
        EOF

        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update('onedatastore update system', mads, false)
        cli_update('onedatastore update default', mads, false)

        wait_loop do
            xml = cli_action_xml('onedatastore show -x default')
            xml['FREE_MB'].to_i > 0
        end

        @iid = cli_create('oneimage create -d default', template)

        @uA1 = cli_create_user('uA1', 'passa')
        @uA2 = cli_create_user('uA2', 'passb')

        @image = CLIImage.new(@iid)
        @image.ready?
    end

    after(:all) do
        FileUtils.cp("#{@cp_dummy}.orig", @cp_dummy)
        FileUtils.cp("#{@rm_dummy}.orig", @rm_dummy)
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it 'should create a new Template from XML' do
        xml_text =
            '<TEMPLATE>'<<
            '  <NAME>xml_test</NAME>'<<
            '  <TYPE>os</TYPE>'<<
            "  <PATH>#{Tempfile.new('functionality').path}</PATH>"<<
            '</TEMPLATE>'

        iid = cli_create('oneimage create -d default', xml_text)

        image = CLIImage.new(iid)

        image.ready?

        xml = image.xml

        expect(xml['PERSISTENT']).to eq('0')
        expect(xml['TYPE']).to eq('0')
    end

    it 'should create a new Image, type OS, using a generic SOURCE with stdin template' do
        template = <<-EOF
            NAME   = generic_source
            TYPE   = OS
            SOURCE = /this/is/a/path
            SIZE   = 2048
            FORMAT = raw
        EOF

        cmd = 'oneimage create -d default'

        stdin_cmd = <<~BASH
            #{cmd} <<EOF
            #{template}
            EOF
        BASH

        image = CLIImage.new(cli_create(stdin_cmd))

        image.ready?

        xml = image.xml

        expect(xml['PERSISTENT']).to eq('0')
        expect(xml['TYPE']).to eq('0')
        expect(xml['SOURCE']).to eq('/this/is/a/path')
    end

    it 'should create a new Image, type DATABLOCK' do
        iid = cli_create('oneimage create -d default --name datablock'\
                         ' --size 512 --type DATABLOCK')

        image = CLIImage.new(iid)

        image.ready?

        xml = image.xml

        expect(xml['PERSISTENT']).to eq('0')
        expect(xml['TYPE']).to eq('2')
        expect(xml['SOURCE']).to eq('dummy_path')
        expect(xml['SIZE']).to eq('512')
    end

    it 'should not create an Image using an existing name' do
        cli_create('oneimage create -d default --name datablock --size 512'\
                   ' --type DATABLOCK', nil, false)
    end

    it 'should not create an Image without a name' do
        cli_create('oneimage create -d default --size 512 --type DATABLOCK', nil, false)
    end

    it 'should not create an OS Image without SIZE' do
        cli_create('oneimage create -d default --name fail --type OS', nil, false)
    end

    it 'should create an OS Image without PATH or SOURCE' do
        iid = cli_create('oneimage create -d default --name empty-os --type OS --size 100', nil,
                         true)

        image = CLIImage.new(iid)

        image.ready?

        expect(image.xml['SIZE']).to eq('100')
    end

    it 'should not create an Image exceeding the Datastore size' do
        cli_create('oneimage create -d default --name fail --type DATABLOCK'\
                   ' --size 30480', nil, false)
    end

    it 'should create an Image with no_capacity_check, exceeding the Datastore size ' do
        # No_check_capacity is only for admin
        as_user 'uA1' do
            cli_create('oneimage create -d default --name fail --type DATABLOCK'\
                   ' --size 30480', nil, false)
        end

        cli_create('oneimage create -d default --name no_check --type DATABLOCK'\
                   ' --size 30480 --no_check_capacity', nil)
    end

    it 'should use LIMIT_MB to exceed Datastore size' do
        # Fail to create image with size > DS free size
        cli_create('oneimage create -d default --name limit_mb --type DATABLOCK'\
                   ' --size 30480', nil, false)

        # Overcommit DS
        cli_update('onedatastore update default', 'LIMIT_MB=50000', true)

        cli_create('oneimage create -d default --name limit_mb --type DATABLOCK'\
                   ' --size 30480', nil)
    end

    it 'should edit dynamically an existing Image template (append)' do
        str = <<-EOF
            ATT1="other value"
            ATT3=VAL3
        EOF

        cli_update("oneimage update #{@iid}", str, true)

        xml = cli_action_xml("oneimage show -x #{@iid}")

        expect(xml['TEMPLATE/ATT1']).to eq('other value')
        expect(xml['TEMPLATE/ATT2']).to eq('VAL2')
        expect(xml['TEMPLATE/ATT3']).to eq('VAL3')
    end

    it 'should edit dynamically an existing Image template (replace)' do
        str = <<-EOF
            NEW_ATT2=VAL2
            NEW_ATT3=VAL3
        EOF

        cli_update("oneimage update #{@iid}", str, false)

        xml = cli_action_xml("oneimage show -x #{@iid}")

        expect(xml['TEMPLATE/ATT1']).to be_nil
        expect(xml['TEMPLATE/ATT2']).to be_nil
        expect(xml['TEMPLATE/ATT3']).to be_nil
        expect(xml['TEMPLATE/NEW_ATT2']).to eq('VAL2')
        expect(xml['TEMPLATE/NEW_ATT3']).to eq('VAL3')
    end

    it 'should publish an existing Image' do
        cli_action("oneimage chmod #{@iid} 640")

        xml = cli_action_xml("oneimage show -x #{@iid}")

        expect(xml['PERMISSIONS/OWNER_U']).to eq('1')
        expect(xml['PERMISSIONS/OWNER_M']).to eq('1')
        expect(xml['PERMISSIONS/OWNER_A']).to eq('0')
        expect(xml['PERMISSIONS/GROUP_U']).to eq('1')
        expect(xml['PERMISSIONS/GROUP_M']).to eq('0')
        expect(xml['PERMISSIONS/GROUP_A']).to eq('0')
        expect(xml['PERMISSIONS/OTHER_U']).to eq('0')
        expect(xml['PERMISSIONS/OTHER_M']).to eq('0')
        expect(xml['PERMISSIONS/OTHER_A']).to eq('0')
    end

    it 'should make an existing Image persistent' do
        cli_action("oneimage persistent #{@iid}")
        xml = cli_action_xml("oneimage show -x #{@iid}")

        expect(xml['PERSISTENT']).to eq('1')
    end

    it 'should disable/enable an existing Image' do
        cli_action("oneimage disable #{@iid}")

        xml = cli_action_xml("oneimage show -x #{@iid}")
        expect(xml['STATE']).to eq('3')

        cli_action("oneimage enable #{@iid}")

        xml = cli_action_xml("oneimage show -x #{@iid}")
        expect(xml['STATE']).to eq('1')
    end

    it 'should delete an existing Image' do
        cli_action("oneimage delete #{@iid}")

        @image.deleted?
    end

    it 'should not create a template with restricted attributes (SOURCE)' do
        cli_create('oneimage create -d default --name dname'\
                   ' --source /no/path --type OS --size 512', nil, false)
    end

    it 'should verify that image namespaces is user scope' do
        as_user 'uA1' do
            cli_create('oneimage create -d default --name dname'\
                       ' --path /etc/passwd --type OS --size 512')

            cli_create('oneimage create -d default --name dname'\
                       ' --path /etc/passwd --type OS --size 512', nil, false)
        end

        as_user 'uA2' do
            cli_create('oneimage create -d default --name dname'\
                       ' --path /etc/passwd --type OS --size 512')
        end
    end

    it 'should require admin permissions and force flag for deleting an image at LOCKED state' do
        FileUtils.mv(@cp_dummy, "#{@cp_dummy}.orig")

        sleep 1

        File.open(@cp_dummy, File::CREAT|File::TRUNC|File::RDWR, 0o744) do |f|
            f.write("#!/bin/bash\n")
            f.write("sleep 10\n")
            f.write('echo "dummy_path dummy_format"')
        end

        # get image from marketplace
        wait_app_ready(60, "'CentOS 7'")

        app_xml = cli_action_xml("onemarketapp show -x 'CentOS 7'")
        app_id = app_xml['ID']

        as_user 'uA1' do
            cli_action("onemarketapp export --datastore 1 #{app_id} lock")
        end

        # check image state is LOCKED
        img = CLIImage.new('lock')
        img.state?('LOCKED')

        # try to delete the image as uA1
        as_user 'uA1' do
            cli_action('oneimage delete lock', false)
        end

        # check image state keep been LOCKED
        img.state?('LOCKED')

        # try to delete the image as oneadmin
        cli_action('oneimage delete lock', false)

        cli_action('oneimage delete --force lock')

        img.deleted?
    end

    it 'should delete all images and check images count' do
        images = CLIImage.list('-l ID')
        img = CLIImage.new(images[-1])

        xml = cli_action_xml('onedatastore show 1 -x')
        expect(xml['IMAGES'].split.size).not_to eq 0

        images.each do |image|
            cli_action("oneimage delete #{image}")
        end

        img.deleted?

        xml = cli_action_xml('onedatastore show 1 -x')
        expect(xml['IMAGES'].split.size).to eq 0
    end

    it 'should fail to delete image and check image state' do
        FileUtils.cp("#{@cp_dummy}.orig", @cp_dummy)
        FileUtils.mv(@rm_dummy, "#{@rm_dummy}.orig")

        sleep 1

        File.open(@rm_dummy, File::CREAT|File::TRUNC|File::RDWR, 0o744) do |f|
            f.write("#!/bin/bash\n")
            f.write("exit 1\n")
        end

        img = CLIImage.create('test_force', 1,
                              '--path /etc/passwd --type OS --size 512')

        img.ready?

        img.delete

        img.error?

        xml = cli_action_xml('onedatastore show 1 -x')
        expect(xml['IMAGES'].split.size).to eq 1
    end

    it 'delete --force should delete image even if driver action fails' do
        img = CLIImage.new('test_force')

        cli_action('oneimage delete --force test_force')

        img.deleted?

        xml = cli_action_xml('onedatastore show 1 -x')
        expect(xml['IMAGES'].split.size).to eq 0

        cli_action('onedatastore delete 1')
    end
end
