#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
# ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe 'Template operations test' do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        cli_create_user('new_user', 'abc')
        cli_create('onegroup create new_group')
        cli_action('oneuser chgrp new_user new_group')
    end

    before(:each) do
        template = <<-EOF
            NAME   = test
            CPU    = 2
            MEMORU = 128
            ATT1   = "VAL1"
            ATT2   = "VAL2"
        EOF

        @template_id = cli_create_stdin('onetemplate create', template)
    end

    after(:each) do
        cli_action('onetemplate delete test')
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it 'should create a new Template' do
        expect(cli_action('onetemplate list').stdout).to match(/test/)
        expect(cli_action('onetemplate show test').stdout).to match(/CPU *= *"2"/)
    end

    it 'should create a new Template from XML' do
        xml_text =
            '<TEMPLATE>'<<
            '  <NAME>xml_test</NAME>'<<
            '  <ATT1>VAL1</ATT1>'<<
            '  <ATT2>VAL2</ATT2>'<<
            '  <CPU>5</CPU>'<<
            '  <MEMORY>1024</MEMORY>'<<
            '</TEMPLATE>'

        id = cli_create('onetemplate create', xml_text)
        expect(cli_action('onetemplate list').stdout).to match(/xml_test/)
        expect(cli_action('onetemplate show xml_test').stdout).to match(/CPU *= *"5"/)
    end

    it 'should try to create an existing Template and check the failure' do
        cli_create('onetemplate create', "NAME=test\n", false)
    end

    it 'should edit dynamically an existing VM Template (append)' do
        str = <<-EOF
            ATT2 = NEW_VAL
            ATT3 = VAL3
            ATT4 = "A new value"
        EOF

        cli_update('onetemplate update test', str, true)

        xml = cli_action_xml("onetemplate show -x #{@template_id}")

        expect(xml['TEMPLATE/ATT1']).to eq('VAL1')
        expect(xml['TEMPLATE/ATT2']).to eq('NEW_VAL')
        expect(xml['TEMPLATE/ATT3']).to eq('VAL3')
        expect(xml['TEMPLATE/ATT4']).to eq('A new value')
    end

    it 'should edit dynamically an existing VM Template (replace)' do
        str = <<-EOF
            ATT2 = NEW_VAL
            ATT3 = VAL3
            ATT4 = "A new value"
        EOF

        cli_update('onetemplate update test', str, false)

        xml = cli_action_xml("onetemplate show -x #{@template_id}")

        expect(xml['TEMPLATE/ATT1']).to be_nil
        expect(xml['TEMPLATE/ATT2']).to eq('NEW_VAL')
        expect(xml['TEMPLATE/ATT3']).to eq('VAL3')
        expect(xml['TEMPLATE/ATT4']).to eq('A new value')
    end

    it 'should chmod an existing Template' do
        cli_action('onetemplate chmod test 640')

        xml = cli_action_xml('onetemplate show -x test')

        expect(xml['PERMISSIONS/OWNER_U']).to eq('1')
        expect(xml['PERMISSIONS/OWNER_M']).to eq('1')
        expect(xml['PERMISSIONS/OWNER_A']).to eq('0')
        expect(xml['PERMISSIONS/GROUP_U']).to eq('1')
        expect(xml['PERMISSIONS/GROUP_M']).to eq('0')
        expect(xml['PERMISSIONS/GROUP_A']).to eq('0')
        expect(xml['PERMISSIONS/OTHER_U']).to eq('0')
        expect(xml['PERMISSIONS/OTHER_M']).to eq('0')
        expect(xml['PERMISSIONS/OTHER_A']).to eq('0')

        cli_action('onetemplate chmod test 400')

        xml = cli_action_xml('onetemplate show -x test')

        expect(xml['PERMISSIONS/OWNER_U']).to eq('1')
        expect(xml['PERMISSIONS/OWNER_M']).to eq('0')
        expect(xml['PERMISSIONS/OWNER_A']).to eq('0')
        expect(xml['PERMISSIONS/GROUP_U']).to eq('0')
        expect(xml['PERMISSIONS/GROUP_M']).to eq('0')
        expect(xml['PERMISSIONS/GROUP_A']).to eq('0')
        expect(xml['PERMISSIONS/OTHER_U']).to eq('0')
        expect(xml['PERMISSIONS/OTHER_M']).to eq('0')
        expect(xml['PERMISSIONS/OTHER_A']).to eq('0')
    end

    it 'should clone an existing Template' do
        cli_action('onetemplate clone test new')

        expect(cli_action('onetemplate list').stdout).to match(/test/)
        expect(cli_action('onetemplate list').stdout).to match(/new/)

        xml = cli_action_xml('onetemplate show -x new')

        expect(xml['TEMPLATE/ATT1']).to eq('VAL1')
        expect(xml['TEMPLATE/ATT2']).to eq('VAL2')
        expect(xml['TEMPLATE/CPU']).to eq('2')
    end

    it 'should clone recursively an existing Template' do
        cli_action('onetemplate clone --recursive test new_recursive')

        expect(cli_action('onetemplate list').stdout).to match(/test/)
        expect(cli_action('onetemplate list').stdout).to match(/new_recursive/)

        xml = cli_action_xml('onetemplate show -x new_recursive')

        expect(xml['TEMPLATE/ATT1']).to eq('VAL1')
        expect(xml['TEMPLATE/ATT2']).to eq('VAL2')
        expect(xml['TEMPLATE/CPU']).to eq('2')
    end

    it 'should clone an existing Template as other user' do
        cli_action('onetemplate chmod test 644')

        as_user 'new_user' do
            cli_action('onetemplate clone test new')

            expect(cli_action('onetemplate list').stdout).to match(/test/)
            expect(cli_action('onetemplate list').stdout).to match(/new/)

            xml = cli_action_xml('onetemplate show -x new')

            expect(xml['TEMPLATE/ATT1']).to eq('VAL1')
            expect(xml['TEMPLATE/ATT2']).to eq('VAL2')
            expect(xml['TEMPLATE/CPU']).to eq('2')
            expect(xml['UNAME']).to eq('new_user')
            expect(xml['GNAME']).to eq('new_group')
        end
    end

    it 'should try to change the owner of Template repeating name, and fail' do
        id = -1

        as_user 'new_user' do
            id = cli_create('onetemplate create', "NAME=test\n")
        end

        cli_action("onetemplate chown #{id} 0", false)

        as_user 'new_user' do
            id = cli_action("onetemplate delete #{id}")
        end
    end

    it 'should change the owner of an existing Template' do
        cli_action('onetemplate chown test new_user')
        xml = cli_action_xml('onetemplate show -x test')

        expect(xml['UNAME']).to eq('new_user')
        expect(xml['GNAME']).to eq('oneadmin')
    end

    it 'should respect new lines' do
        template = <<-EOF
            NAME    = test_new_lines
            TESTING = "line1
            line2
            line3"
        EOF

        template_id = cli_create('onetemplate create', template)

        xml = cli_action_xml("onetemplate show -x #{template_id}")

        testing = xml['TEMPLATE/TESTING']

        expect(testing.scan("\n").count).to eq(2)

        cli_action("onetemplate delete #{template_id}")
    end
end
