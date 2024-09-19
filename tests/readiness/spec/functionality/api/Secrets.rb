#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

# Check object secrets
def check_secrets(command, id, o_class, path, eql_nil = false)
    if o_class != OpenNebula::Template
        info_e_method = false
        info_d_method = true
    else
        info_e_method = [false, false]
        info_d_method = [false, true]
    end

    # CLI
    xml = cli_action_xml(command)
    expect(xml[path]).to_not eq(nil)
    expect(xml[path]).to_not eq('password')

    # As admin
    xml = o_class.new_with_id(id, @clientAdmin)
    xml.info(*info_e_method) # Get data encrypted
    expect(xml[path]).to_not eq(nil)
    expect(xml[path]).to_not eq('password')

    xml.info(*info_d_method) # Get data decrypted
    expect(xml[path]).to eq('password')

    # As user
    xml = o_class.new_with_id(id, @clientUser)

    # Get data encrypted
    xml.info(*info_e_method)

    if eql_nil
        expect(xml[path]).to eq(nil)
    else
        expect(xml[path]).to_not eq(nil)
        expect(xml[path]).to_not eq('password')
    end

    # Try to get data decrypted
    xml.info(*info_d_method)

    if eql_nil
        expect(xml[path]).to eq(nil)
    else
        expect(xml[path]).to_not eql(nil)
        expect(xml[path]).to_not eql('password')
    end
end

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe 'API secrets tests' do
    prepend_before(:all) do
        @defaults_yaml = File.join(File.dirname(__FILE__), 'defaults.yaml')
    end

    before(:all) do
        @template = <<-EOF
            ONE_PASSWORD="password"
        EOF

        @user_id     = cli_create_user('user1', 'passwordA')
        @clientAdmin = OpenNebula::Client.new
        @clientUser  = OpenNebula::Client.new('user1:passwordA')
    end

    after(:all) do
        cli_action('oneuser delete user1')
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it 'secret in host should be encrypted' do
        id = cli_create('onehost create host-test --im dummy --vm dummy')
        cli_update("onehost update #{id}", @template, true)

        check_secrets("onehost show -x #{id}",
                      id,
                      OpenNebula::Host,
                      'TEMPLATE/ONE_PASSWORD',
                      true)

        cli_action("onehost delete #{id}")
    end

    it 'secret in cluster should be encrypted' do
        cluster_template = <<-EOF
            PROVISION = [ PACKET_TOKEN = "password" ]
        EOF

        id = cli_create('onecluster create secrets_testing')
        cli_update("onecluster update #{id}", cluster_template, true)

        check_secrets("onecluster show -x #{id}",
                      id,
                      OpenNebula::Cluster,
                      'TEMPLATE/PROVISION/PACKET_TOKEN',
                      true)

        cli_action("onecluster delete #{id}")
    end

    it 'secret in datastore should be encrypted at insert' do
        datastore_template = <<-EOF
            NAME   = secrets_testing
            DS_MAD = fs
            TM_MAD = shared

            PROVISION = [ PACKET_TOKEN = "password" ]
        EOF

        id = cli_create('onedatastore create', datastore_template)

        check_secrets("onedatastore show -x #{id}",
                      id,
                      OpenNebula::Datastore,
                      'TEMPLATE/PROVISION/PACKET_TOKEN',
                      false)

        cli_action("onedatastore delete #{id}")
    end

    it 'secret in datastore should be encrypted' do
        datastore_update_template = <<-EOF
            PROVISION = [ PACKET_TOKEN = "password" ]
        EOF

        datastore_template = <<-EOF
            NAME   = secrets_testing
            DS_MAD = fs
            TM_MAD = shared
        EOF

        id = cli_create('onedatastore create', datastore_template)
        cli_update("onedatastore update #{id}", datastore_update_template, true)

        check_secrets("onedatastore show -x #{id}",
                      id,
                      OpenNebula::Datastore,
                      'TEMPLATE/PROVISION/PACKET_TOKEN',
                      false)

        cli_action("onedatastore delete #{id}")
    end

    it 'secret in vnet should be encrypted at insert' do
        vnet_template = <<-EOF
            NAME = "vnet_test"
            BRIDGE = br0
            VN_MAD = dummy
            INSERT = [ ONE_PASSWORD = "password" ]
            AR = [ TYPE = "IP4", SIZE = "12", IP = "192.168.3.8" ]
        EOF

        id = cli_create('onevnet create', vnet_template)

        check_secrets("onevnet show -x #{id}",
                      id,
                      OpenNebula::VirtualNetwork,
                      'TEMPLATE/INSERT/ONE_PASSWORD')

        cli_action("onevnet delete #{id}")
    end

    it 'secret in vnet should be encrypted' do
        vnet_template = <<-EOF
            NAME = "vnet_test2"
            BRIDGE = br0
            VN_MAD = dummy
            AR = [ TYPE = "IP4", SIZE = "12", IP = "192.168.3.8" ]
        EOF

        id = cli_create('onevnet create', vnet_template)
        cli_update("onevnet update #{id}", @template, true)

        check_secrets("onevnet show -x #{id}",
                      id,
                      OpenNebula::VirtualNetwork,
                      'TEMPLATE/ONE_PASSWORD')

        cli_action("onevnet delete #{id}")
    end

    it 'secret in vnet ARs should be encrypted' do
        vnet_template = <<-EOF
            NAME = "vnet_test3"
            BRIDGE = br0
            VN_MAD = dummy
            AR = [ TYPE = "IP4",
                   SIZE = "12",
                   IP = "192.168.3.8",
                   ONE_PASSWORD = "password" ]
        EOF

        id = cli_create('onevnet create', vnet_template)
        cli_update("onevnet update #{id}", @template, true)

        check_secrets("onevnet show -x #{id}",
                      id,
                      OpenNebula::VirtualNetwork,
                      'AR_POOL/AR/ONE_PASSWORD')

        cli_action("onevnet delete #{id}")
    end

    it 'secret in vnet template should be encrypted' do
        vnet_template = <<-EOF
            NAME = "vnet_test4"
            BRIDGE = br0
            VN_MAD = dummy
            AR = [ TYPE = "IP4", SIZE = "12", IP = "192.168.3.8" ]
        EOF

        id = cli_create('onevntemplate create', vnet_template)
        cli_update("onevntemplate update #{id}", @template, true)

        check_secrets("onevntemplate show -x #{id}",
                      id,
                      OpenNebula::VNTemplate,
                      'TEMPLATE/ONE_PASSWORD',
                      true)

        cli_action("onevntemplate delete #{id}")
    end

    it 'secret in vm template should be encrypted' do
        vm_template = <<-EOF
            NAME   = test
            CPU    = 2
            MEMORY = 128
            ONE_PASSWORD = "password"
        EOF

        id = cli_create('onetemplate create', vm_template)
        cli_update("onetemplate update #{id}", @template, true)

        check_secrets("onetemplate show -x #{id}",
                      id,
                      OpenNebula::Template,
                      'TEMPLATE/ONE_PASSWORD',
                      true)

        cli_action("onetemplate delete #{id}")
    end

    it 'secret in vm should be encrypted with stdin template creation' do
        cli_update('onedatastore update system', 'TM_MAD=dummy', false)
        cli_update('onedatastore update default', "TM_MAD=dummy\nDS_MAD=dummy", false)

        tmp_file = Tempfile.new('one')
        cli_create('onehost create host01 --vm dummy --im dummy')
        image = cli_create('oneimage create --name testimage --type OS ' <<
                           "--target hda --path #{tmp_file.path} -d default")

        vm_template = <<-EOF
            NAME   = test
            CPU    = 1
            MEMORY = 1
            DISK=[IMAGE_ID=#{image}]
            CONTEXT=[
                HOSTNAME=host01,
                TARGET=hdb,
                ONE_PASSWORD = "password",
                PASSWORD = "password"
            ]
            ONE_PASSWORD = "password"
            PASSWORD = "password"
        EOF

        template = <<-EOF
            ONE_PASSWORD="password"
        EOF

        id = cli_create_stdin('onevm create', vm_template)
        cli_update_stdin("onevm update #{id}", template, true)

        # Test secrets on VM update template append
        cli_update("onevm update #{id}", @template, true)
        check_secrets("onevm show -x #{id}",
                      id,
                      OpenNebula::VirtualMachine,
                      'USER_TEMPLATE/ONE_PASSWORD',
                      true)
        check_secrets("onevm show -x #{id}",
                      id,
                      OpenNebula::VirtualMachine,
                      'USER_TEMPLATE/PASSWORD',
                      true)

        # Test secrets on VM update template replace
        cli_update("onevm update #{id}", @template, false)
        check_secrets("onevm show -x #{id}",
                      id,
                      OpenNebula::VirtualMachine,
                      'TEMPLATE/CONTEXT/ONE_PASSWORD',
                      true)
        check_secrets("onevm show -x #{id}",
                      id,
                      OpenNebula::VirtualMachine,
                      'TEMPLATE/CONTEXT/PASSWORD',
                      true)
        xml = cli_action_xml("onevm show -x #{id}")
        expect(xml['USER_TEMPLATE/PASSWORD']).to eq(nil)

        # Test secrets on VM updateconf append
        template_update = <<-EOF
            CONTEXT = [ ONE_PASSWORD="password" ]
        EOF

        cli_update("onevm updateconf #{id}", template_update, true)
        check_secrets("onevm show -x #{id}",
                      id,
                      OpenNebula::VirtualMachine,
                      'TEMPLATE/CONTEXT/ONE_PASSWORD',
                      true)
        check_secrets("onevm show -x #{id}",
                      id,
                      OpenNebula::VirtualMachine,
                      'TEMPLATE/CONTEXT/PASSWORD',
                      true)

        # Test secrets on VM updateconf replace
        cli_update("onevm updateconf #{id}", template_update, false)
        check_secrets("onevm show -x #{id}",
                      id,
                      OpenNebula::VirtualMachine,
                      'TEMPLATE/CONTEXT/ONE_PASSWORD',
                      true)
        xml = cli_action_xml("onevm show -x #{id}")
        expect(xml['TEMPLATE/CONTEXT/PASSWORD']).to eq(nil)

        # As admin
        xml = OpenNebula::VirtualMachine.new_with_id(id, @clientAdmin)
        xml.info(false)     # Get data encrypted
        expect(xml['USER_TEMPLATE/ONE_PASSWORD']).to_not eql(nil)
        expect(xml['USER_TEMPLATE/ONE_PASSWORD']).to_not eql('password')
        expect(xml['TEMPLATE/CONTEXT/ONE_PASSWORD']).to_not eql(nil)
        expect(xml['TEMPLATE/CONTEXT/ONE_PASSWORD']).to_not eql('password')

        xml.info(true)      # Get data decrypted
        expect(xml['USER_TEMPLATE/ONE_PASSWORD']).to eql('password')
        expect(xml['TEMPLATE/CONTEXT/ONE_PASSWORD']).to eql('password')

        # As user
        xml = OpenNebula::VirtualMachine.new_with_id(id, @clientUser)
        xml.info(false)     # Get data encrypted
        expect(xml['USER_TEMPLATE/ONE_PASSWORD']).to eql(nil)
        expect(xml['TEMPLATE/CONTEXT/ONE_PASSWORD']).to eql(nil)

        xml.info(true)      # Try to get data decrypted
        expect(xml['USER_TEMPLATE/ONE_PASSWORD']).to eql(nil)
        expect(xml['TEMPLATE/CONTEXT/ONE_PASSWORD']).to eql(nil)

        cli_action("onevm terminate #{id} --hard")
        cli_action('onehost delete host01')
    end

    it 'secret in user should be encrypted' do
        user_template = <<-EOF
            TEST_ENCRYPTED = "password"
        EOF

        cli_update('oneuser update user1', user_template, true)

        check_secrets("oneuser show -x #{@user_id}",
                      @user_id,
                      OpenNebula::User,
                      'TEMPLATE/TEST_ENCRYPTED')
    end

    it 'secret in image should be encrypted at insert' do
        image_template = <<-EOF
            NAME   = secrets_testing
            TYPE   = OS
            PATH   = #{Tempfile.new('functionality').path}
            TEST_ENCRYPTED = "password"
        EOF

        id = cli_create('oneimage create -d default', image_template)

        check_secrets("oneimage show -x #{id}",
                      id,
                      OpenNebula::Image,
                      'TEMPLATE/TEST_ENCRYPTED',
                      true)

        cli_action("oneimage delete #{id} --force")
    end

    it 'secret in img should be encrypted at update' do
        image_template = <<-EOF
            NAME   = secrets_testing2
            TYPE   = OS
            PATH   = #{Tempfile.new('functionality').path}
        EOF

        image_template_update = <<-EOF
            TEST_ENCRYPTED = "password"
        EOF

        id = cli_create('oneimage create -d default', image_template)
        cli_update("oneimage update #{id}", image_template_update, true)

        check_secrets("oneimage show -x #{id}",
                      id,
                      OpenNebula::Image,
                      'TEMPLATE/TEST_ENCRYPTED',
                      true)

        cli_action("oneimage delete #{id} --force")
    end

    it 'oned configuration should hide sensitive information' do
        if @main_defaults && @main_defaults[:db]
            unless @main_defaults[:db]['BACKEND'] == 'mysql'
                skip 'only for mysql DB backend'
            end
        end

        # admin
        config = System.new(@clientAdmin).get_configuration()

        expect(config['DB/BACKEND']).to eql('mysql')
        expect(config['DB/SERVER']).not_to eql('***')
        expect(config['DB/PORT']).not_to eql('***')
        expect(config['DB/DB_NAME']).not_to eql('***')
        expect(config['DB/USER']).not_to eql('***')
        expect(config['DB/PASSWD']).not_to eql('***')

        # Regular user
        config = System.new(@clientUser).get_configuration()

        expect(config['DB/BACKEND']).to eql('***')
        expect(config['DB/SERVER']).to eql('***')
        expect(config['DB/PORT']).to eql('***')
        expect(config['DB/DB_NAME']).to eql('***')
        expect(config['DB/USER']).to eql('***')
        expect(config['DB/PASSWD']).to eql('***')
    end
end
