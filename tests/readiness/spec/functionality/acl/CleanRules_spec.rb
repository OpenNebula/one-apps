#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "ACL Clean rules test" do
  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "should delete a user, and check that his ACLs are also cleaned" do
    uid = cli_create("oneuser create abc abc")

    cli_action("oneacl create '##{uid} HOST/* USE'")
    cli_action("oneacl create '@#{uid} HOST/* USE'")

    cli_action("oneacl create '#1050 IMAGE/@#{uid} USE'")

    expect(cli_action("oneacl list").stdout).to match(/##{uid}/)
    expect(cli_action("oneacl list").stdout).to match(/@#{uid}/)

    cli_action("oneuser delete #{uid}")

    expect(cli_action("oneacl list").stdout).not_to match(/##{uid}/)
    expect(cli_action("oneacl list").stdout).to match(/@#{uid}/)
  end

  it "should delete a group, and check that its ACLs are also cleaned" do
    gid = cli_create("onegroup create abc")

    cli_action("oneacl create '##{gid} HOST/* USE'")
    cli_action("oneacl create '@#{gid} HOST/* USE'")

    cli_action("oneacl create '#1060 IMAGE/##{gid} USE'")
    cli_action("oneacl create '#1060 IMAGE/@#{gid} USE'")

    expect(cli_action("oneacl list").stdout).to match(/##{gid}/)
    expect(cli_action("oneacl list").stdout).to match(/@#{gid}/)

    cli_action("onegroup delete #{gid}")

    expect(cli_action("oneacl list").stdout).to match(/##{gid}/)
    expect(cli_action("oneacl list").stdout).not_to match(/@#{gid}/)
  end

  it "should delete a template, and check that its ACLs are also cleaned" do
    id = cli_create("onetemplate create --name test")

    acl_a = cli_action("oneacl create '#1234 TEMPLATE/##{id} USE'").stdout.split[1]
    acl_b = cli_action("oneacl create '#1234 TEMPLATE/@#{id} USE'").stdout.split[1]
    acl_c = cli_action("oneacl create '#1234 IMAGE+TEMPLATE/##{id} USE'").stdout.split[1]

    expect(cli_action("oneacl list").stdout).to match(/ #{acl_a} /)
    expect(cli_action("oneacl list").stdout).to match(/ #{acl_b} /)
    expect(cli_action("oneacl list").stdout).to match(/ #{acl_c} /)

    cli_action("onetemplate delete #{id}")

    expect(cli_action("oneacl list").stdout).not_to match(/ #{acl_a} /)
    expect(cli_action("oneacl list").stdout).to match(/ #{acl_b} /)
    expect(cli_action("oneacl list").stdout).to match(/ #{acl_c} /)
  end

  it "should delete a cluster, and check that its ACLs are also cleaned" do
    id = cli_create("onecluster create abc")

    cli_action("oneacl create '#1234 HOST/* MANAGE'")
    cli_action("oneacl create '@1234 HOST/* MANAGE'")

    cli_action("oneacl create '#321  CLUSTER/##{id} USE'")

    cli_action("oneacl create '#5678 HOST/%#{id} MANAGE'")
    cli_action("oneacl create '@5678 HOST/%#{id} MANAGE'")

    expect(cli_action("oneacl list").stdout).to match(/1234/)
    expect(cli_action("oneacl list").stdout).to match(/321/)
    expect(cli_action("oneacl list").stdout).to match(/5678/)

    cli_action("onecluster delete #{id}")

    expect(cli_action("oneacl list").stdout).to match(/1234/)
    expect(cli_action("oneacl list").stdout).not_to match(/321/)
    expect(cli_action("oneacl list").stdout).not_to match(/5678/)
  end

end