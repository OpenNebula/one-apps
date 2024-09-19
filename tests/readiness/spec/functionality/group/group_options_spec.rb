#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Group create options test" do
  #---------------------------------------------------------------------------
  # OpenNebula bootstraping:
  #   - Define infrastructure: hosts, datastore, users, networks,...
  #   - Common instance variables: templates,...
  #---------------------------------------------------------------------------

  after(:each) do
    `oneuser delete testgroup-admin`
    `onegroup delete testgroup`

    expect(`onegroup list | wc -l`.strip).to eql "3"
    expect(`oneacl list | wc -l`.strip).to eql "7"
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "should create a group from a name option" do
    id = cli_create("onegroup create --name testgroup")

    cli_action("onegroup show #{id}")
    cli_action("onegroup show testgroup")
  end

  ############################################################################
  # ACL Rules
  ############################################################################

  it "should create a default acl rule to create resources" do
    id = cli_create("onegroup create --name testgroup")

    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{id} *V--I-T---O-S-R--P-B *\* *---c/)
  end

  it "should create an acl rule to create the defined resources" do
    id = cli_create("onegroup create --name testgroup --resources VM+IMAGE")

    expect(cli_action("oneacl list").stdout).not_to match(/ *\d+ *@#{id} *V--I-T---O-S-R--P-B *\* *---c/)
    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@\d+ *V--I--------------- *\* *---c/)
  end

  it "should fail to create a group with a malformed acl rule resources" do
    cli_create("onegroup create --name testgroup --resources VM+IMAGE+SOMETHING", nil, false)
    cli_action("onegroup show testgroup", false)
  end

  ############################################################################
  # Admin user
  ############################################################################

  it "should create a group with an admin user" do
    id = cli_create("onegroup create --name testgroup "<<
      "--admin_user testgroup-admin --admin_password abc")

    cli_action("onegroup show #{id}")
    cli_action("onegroup show testgroup")

    cli_action("oneuser show testgroup-admin")

    user = cli_action_xml("oneuser show testgroup-admin -x")
    expect(user["AUTH_DRIVER"]).to eql "core"
    expect(user["GID"]).to eql id.to_s
  end

  it "should not create an admin user if the password is not defined" do
    cli_create("onegroup create --name testgroup "<<
      "--admin_user testgroup-admin", nil, false)

    cli_action("onegroup show testgroup", false)
    cli_action("oneuser show testgroup-admin", false)
  end

  it "should create an admin user with a defined auth driver" do
    id = cli_create("onegroup create --name testgroup "<<
      "--admin_user testgroup-admin --admin_password abc "<<
      " --admin_driver ldap")

    cli_action("onegroup show #{id}")
    cli_action("onegroup show testgroup")

    cli_action("oneuser show testgroup-admin")

    user = cli_action_xml("oneuser show testgroup-admin -x")
    expect(user["AUTH_DRIVER"]).to eql "ldap"
    expect(user["GID"]).to eql id.to_s
  end

  it "should create a default acl rule for the group and the admin user" do
    id = cli_create("onegroup create --name testgroup "<<
      "--admin_user testgroup-admin --admin_password abc")

    admin_id = cli_action_xml("oneuser show testgroup-admin -x")['ID']

    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{id} *V--I-T---O-S-R--P-B *\* *---c/)
    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *##{admin_id} *----U-------------- *@#{id} *umac/)
    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *##{admin_id} *V-NI-T---O-S-R--P-B *@#{id} *um--/)
  end

  it "should create acl rules for the group and the admin user with the resources option" do
    id = cli_create("onegroup create --name testgroup "<<
      "--admin_user testgroup-admin --admin_password abc "<<
      "--resources VM+IMAGE")

    admin_id = cli_action_xml("oneuser show testgroup-admin -x")['ID']

    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *@#{id} *V--I--------------- *\* *---c/)
    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *##{admin_id} *----U-------------- *@#{id} *umac/)
    expect(cli_action("oneacl list").stdout).to match(/ *\d+ *##{admin_id} *V-NI-T---O-S-R--P-B *@#{id} *um--/)
  end

end