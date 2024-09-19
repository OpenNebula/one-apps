#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------


def n_users(group)
  xml = cli_action_xml("onegroup show #{group} -x")
  elems = xml.retrieve_elements("USERS/ID")
  return elems.nil? ? 0 : elems.size
end

def group_contains(group_id, user_id)
  xml = cli_action_xml("onegroup show #{group_id} -x")
  id = xml.retrieve_elements("USERS/ID[.=#{user_id}]")

  expect(id).not_to eql nil
  expect(id.size).to eql 1

  xml = cli_action_xml("oneuser show #{user_id} -x")
  id = xml.retrieve_elements("GROUPS/ID[.=#{group_id}]")

  expect(id).not_to eql nil
  expect(id.size).to eql 1
end

def group_contains_admin(group_id, user_id)
  group_contains(group_id, user_id)

  xml = cli_action_xml("onegroup show #{group_id} -x")
  id = xml.retrieve_elements("ADMINS/ID[.=#{user_id}]")

  expect(id).not_to eql nil
  expect(id.size).to eql 1
end

def group_does_not_contain_admin(group_id, user_id)
  group_contains(group_id, user_id)

  xml = cli_action_xml("onegroup show #{group_id} -x")
  id = xml.retrieve_elements("ADMINS/ID[.=#{user_id}]")

  expect(id).to eql nil
end

def user_has_gid?(user_id, group_id)
  xml = cli_action_xml("oneuser show #{user_id} -x")
  return xml["GROUPS/ID[.=#{group_id}]"] != nil
end

def group_has_uid?(group_id, user_id)
  xml = cli_action_xml("onegroup show #{group_id} -x")
  return xml["USERS/ID[.=#{user_id}]"] != nil
end
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Group users operations test" do
  #---------------------------------------------------------------------------
  # OpenNebula bootstraping:
  #   - Define infrastructure: hosts, datastore, users, networks,...
  #   - Common instance variables: templates,...
  #---------------------------------------------------------------------------

  before(:all) do

    @ga_id = cli_create "onegroup create ga"
    @gb_id = cli_create "onegroup create gb"
    @gc_id = cli_create "onegroup create gc"

    @ua_id = cli_create_user("ua", "abc")
    @ub_id = cli_create_user("ub", "abc")
    @uc_id = cli_create_user("uc", "abc")

    expect(n_users("users")).to eql 3

    @gd_id = cli_create "onegroup create gd"
    @ge_id = cli_create "onegroup create ge"
    @gf_id = cli_create "onegroup create gf"

    @ud_id = cli_create_user("ud", "abc")
    @ue_id = cli_create_user("ue", "abc")
    @uf_id = cli_create_user("uf", "abc")

    cli_action("oneuser chgrp ud gd")
    cli_action("oneuser chgrp ue ge")
    cli_action("oneuser chgrp uf gf")
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  ############################################################################
  # Addgroup
  ############################################################################

  it "should add a User to a new secondary Group" do
    cli_action "oneuser addgroup ua ga"

    expect(cli_action_xml("oneuser show ua -x")['GID']).to eql("1")

    expect(n_users("users")).to eql 3
    expect(n_users("ga")).to eql 1

    group_contains(1, @ua_id)
    group_contains(@ga_id, @ua_id)
  end

  it "should try to add a User to a secondary Group that doens't exist "<<
  "and check the failure" do

    cli_action("oneuser addgroup ua #{@uc_id + 5}", false)

    expect(cli_action_xml("oneuser show ua -x")['GID']).to eql("1")

    expect(n_users("users")).to eql 3
    expect(n_users("ga")).to eql 1

    group_contains(1, @ua_id)
    group_contains(@ga_id, @ua_id)
  end

  it "should try to add a User to a secondary Group he already belongs to "<<
  "and check the failure" do

    cli_action("oneuser addgroup ua ga", false)

    expect(cli_action_xml("oneuser show ua -x")['GID']).to eql("1")

    expect(n_users("users")).to eql 3
    expect(n_users("ga")).to eql 1

    group_contains(1, @ua_id)
    group_contains(@ga_id, @ua_id)
  end

  it "should try to add a User to his main Group and check the failure" do
    cli_action("oneuser addgroup ua users", false)

    expect(cli_action_xml("oneuser show ua -x")['GID']).to eql("1")

    expect(n_users("users")).to eql 3
    expect(n_users("ga")).to eql 1

    group_contains(1, @ua_id)
    group_contains(@ga_id, @ua_id)
  end

  it "should try to add a secondary Group as a regular User, and check the failure" do
    as_user("ua") do
      cli_action("oneuser addgroup ua #{@gc_id}", false)
    end
  end

  ############################################################################
  # Delgroup
  ############################################################################

  it "should remove a User from a secondary Group" do
    cli_action "oneuser addgroup ua gb"

    expect(cli_action_xml("oneuser show ua -x")['GID']).to eql("1")

    expect(n_users("users")).to eql 3
    expect(n_users("ga")).to eql 1
    expect(n_users("gb")).to eql 1

    group_contains(1, @ua_id)
    group_contains(@ga_id, @ua_id)
    group_contains(@gb_id, @ua_id)

    cli_action "oneuser delgroup ua gb"

    expect(cli_action_xml("oneuser show ua -x")['GID']).to eql("1")

    expect(n_users("users")).to eql 3
    expect(n_users("ga")).to eql 1
    expect(n_users("gb")).to eql 0

    group_contains(1, @ua_id)
    group_contains(@ga_id, @ua_id)
  end

  it "should try to delete a secondary Group as a User, and check the failure" do
    cli_action "oneuser addgroup ua gb"

    expect(cli_action_xml("oneuser show ua -x")['GID']).to eql("1")


    as_user("ua") do
      cli_action("oneuser delgroup ua #{@gb_id}", false)
    end

    cli_action "oneuser delgroup ua gb"
  end

  it "should try to remove a User from his main Group and check the failure" do
    cli_action("oneuser delgroup ua users", false)

    expect(cli_action_xml("oneuser show ua -x")['GID']).to eql("1")

    expect(n_users("users")).to eql 3
    expect(n_users("ga")).to eql 1

    group_contains(1, @ua_id)
    group_contains(@ga_id, @ua_id)
  end

  it "should try to remove a User from a non-existent Group "<<
  "and check the failure" do

    cli_action("oneuser delgroup ua 350", false)

    expect(cli_action_xml("oneuser show ua -x")['GID']).to eql("1")

    expect(n_users("users")).to eql 3
    expect(n_users("ga")).to eql 1

    group_contains(1, @ua_id)
    group_contains(@ga_id, @ua_id)
  end

  it "should try to remove a User from an existent Group he doesn't "<<
  "belong to and check the failure" do

    cli_action("oneuser delgroup ua gc", false)

    expect(cli_action_xml("oneuser show ua -x")['GID']).to eql("1")

    expect(n_users("users")).to eql 3
    expect(n_users("ga")).to eql 1

    group_contains(1, @ua_id)
    group_contains(@ga_id, @ua_id)
  end

  it "should try to delete a group with Users assigned "<<
  "and check the failure" do

    cli_action("onegroup delete users", false)
    cli_action("onegroup delete ga", false)
  end

  it "should delete a User and check that his ID is removed from "<<
  "all his groups" do

    cli_action "oneuser delete ua"

    expect(n_users("users")).to eql 2
    expect(n_users("ga")).to eql 0
  end

  ############################################################################
  # Chgrp
  ############################################################################

  it "should allow a user to chgrp to a secondary group" do
    cli_action "oneuser addgroup uc ga"
    cli_action "oneuser addgroup uc gb"

    expect(n_users("users")).to eql 2
    expect(n_users("ga")).to eql 1
    expect(n_users("gb")).to eql 1
    expect(n_users("gc")).to eql 0

    group_contains(1, @uc_id)
    group_contains(@ga_id, @uc_id)
    group_contains(@gb_id, @uc_id)

    expect(cli_action_xml("oneuser show uc -x")['GID']).to eql("1")

    as_user("uc") do
      cli_action "onegroup show users"
      cli_action "onegroup show ga"
      cli_action "onegroup show gb"
      cli_action("oneuser show #{@gc_id}", false)

      cli_action "oneuser chgrp uc gb"
    end

    expect(n_users("users")).to eql 2
    expect(n_users("ga")).to eql 1
    expect(n_users("gb")).to eql 1
    expect(n_users("gc")).to eql 0

    group_contains(1, @uc_id)
    group_contains(@ga_id, @uc_id)
    group_contains(@gb_id, @uc_id)

    expect(cli_action_xml("oneuser show uc -x")['GID']).to eql(@gb_id.to_s)
  end

  it "should try to chgrp to a non existing group, and check the failure" do
    as_user("ua") do
      cli_action("oneuser chgrp ua 350", false)
    end
  end

  it "should try to chgrp to a group not in the secondary groups, and check the failure" do
    as_user("ua") do
      cli_action("oneuser chgrp ua #{@gc_id}", false)
    end
  end

  it "should try to chgrp to the current primary group, and check the failure" do
    as_user("ua") do
      cli_action("oneuser chgrp ua #{@gb_id}", false)
    end
  end


  ############################################################################
  # Addadmin
  ############################################################################

  it "should make a User admin" do
    cli_action "onegroup addadmin gd ud"
    group_contains_admin(@gd_id, @ud_id)
  end

  it "should try to make a User admin to a Group he doesn't belong to "<<
  "and check the failure" do

    cli_action("onegroup addadmin gd ue", false)
  end

  it "should try to make a User admin to a Group he already is admin to "<<
  "and check the failure" do

    cli_action("onegroup addadmin gd ud", false)
    group_contains_admin(@gd_id, @ud_id)
  end

  it "should try to make a User admin as a regular User, and check the failure" do
    as_user("ue") do
      cli_action("onegroup addadmin ge ue", false)
    end
  end

  it "should add an user to a group being group admin" do
    cli_action("oneuser create umin pepe")
    cli_action("oneuser addgroup umin gd")
    cli_action("oneuser addgroup ud ge")
    cli_action("onegroup addadmin ge ud")

    as_user("ud") do
      cli_action("oneuser addgroup umin ge", false)
    end
  end

  ############################################################################
  # Deladmin
  ############################################################################

  it "should revoke a Group admin" do
    cli_action "onegroup deladmin gd ud"
    group_does_not_contain_admin(@gd_id, @ud_id)
  end

  it "should try to revoke a Group admin from a Group he doesn't belong to "<<
  "and check the failure" do

    cli_action("onegroup deladmin gd ue", false)
  end

  it "should try to revoke a Group admin from a Group he is not admin to "<<
  "and check the failure" do

    cli_action("onegroup deladmin gd ud", false)
    group_does_not_contain_admin(@gd_id, @ud_id)
  end

  it "should try to revoke a Group admin as a regular User, and check the failure" do
    cli_action "oneuser chgrp uf ge"
    cli_action "onegroup addadmin ge uf"
    group_contains_admin(@ge_id, @uf_id)

    as_user("ue") do
      cli_action("onegroup deladmin ge uf", false)
    end

    group_contains_admin(@ge_id, @uf_id)
  end

  it "should try to revoke a Group admin as himself, and check the failure" do
    group_contains_admin(@ge_id, @uf_id)

    as_user("uf") do
      cli_action("onegroup deladmin ge uf", false)
    end

    group_contains_admin(@ge_id, @uf_id)
  end

  it "should add and remove the User from several groups and check the "<<
  "cross-reference consistency" do

    user_names = {
      :a => "user_a",
      :b => "user_b",
      :c => "user_c",
      :d => "user_d"
    }
    users = Hash.new

    group_names = {
      :a => "group_a",
      :b => "group_b",
      :c => "group_c",
      :d => "group_d"
    }
    groups = Hash.new

    # Create all users and groups. Add user_* to corresponding group_*
    user_names.each do |entry|

      uid = cli_create_user(entry[1], "pass")

      g_name = group_names[entry[0]]
      gid = cli_create("onegroup create #{g_name}")

      cli_action("oneuser addgroup #{uid} #{gid}")

      users[entry[0]] = uid
      groups[entry[0]] = gid
    end

    # Add all users to group_b
    # should fail for user_b, return code not checked
    users.each_value do |user|
      `oneuser addgroup #{user} group_b`
    end

    # Change user_c & _d main group
    cli_action("oneuser chgrp user_c group_d")
    cli_action("oneuser chgrp user_d group_c")

    # Check cross-references so far
    expect(user_has_gid?(users[:a], groups[:a])).to eql(true)
    expect(user_has_gid?(users[:a], groups[:b])).to eql(true)
    expect(user_has_gid?(users[:a], groups[:c])).to eql(false)
    expect(user_has_gid?(users[:a], groups[:d])).to eql(false)

    expect(user_has_gid?(users[:b], groups[:a])).to eql(false)
    expect(user_has_gid?(users[:b], groups[:b])).to eql(true)
    expect(user_has_gid?(users[:b], groups[:c])).to eql(false)
    expect(user_has_gid?(users[:b], groups[:d])).to eql(false)

    expect(user_has_gid?(users[:c], groups[:a])).to eql(false)
    expect(user_has_gid?(users[:c], groups[:b])).to eql(true)
    expect(user_has_gid?(users[:c], groups[:c])).to eql(true)
    expect(user_has_gid?(users[:c], groups[:d])).to eql(true)

    expect(user_has_gid?(users[:d], groups[:a])).to eql(false)
    expect(user_has_gid?(users[:d], groups[:b])).to eql(true)
    expect(user_has_gid?(users[:d], groups[:c])).to eql(true)
    expect(user_has_gid?(users[:d], groups[:d])).to eql(true)

    expect(group_has_uid?(groups[:a], users[:a])).to eql(true)
    expect(group_has_uid?(groups[:a], users[:b])).to eql(false)
    expect(group_has_uid?(groups[:a], users[:c])).to eql(false)
    expect(group_has_uid?(groups[:a], users[:d])).to eql(false)

    expect(group_has_uid?(groups[:b], users[:a])).to eql(true)
    expect(group_has_uid?(groups[:b], users[:b])).to eql(true)
    expect(group_has_uid?(groups[:b], users[:c])).to eql(true)
    expect(group_has_uid?(groups[:b], users[:d])).to eql(true)

    expect(group_has_uid?(groups[:c], users[:a])).to eql(false)
    expect(group_has_uid?(groups[:c], users[:b])).to eql(false)
    expect(group_has_uid?(groups[:c], users[:c])).to eql(true)
    expect(group_has_uid?(groups[:c], users[:d])).to eql(true)

    expect(group_has_uid?(groups[:d], users[:a])).to eql(false)
    expect(group_has_uid?(groups[:d], users[:b])).to eql(false)
    expect(group_has_uid?(groups[:d], users[:c])).to eql(true)
    expect(group_has_uid?(groups[:d], users[:d])).to eql(true)


    # Remove each user_* from its group_*
    users.each do |entry|
      cli_action("oneuser delgroup #{entry[1]} #{groups[entry[0]]}")
    end

    # Remove all users from group_b
    users.each_value do |user|
      `oneuser delgroup #{user} group_b`
    end

    # Add user_a to group_d, remove it, and then add it to group_b
    cli_action("oneuser addgroup user_a group_d")
    cli_action("oneuser delgroup user_a group_d")
    cli_action("oneuser addgroup user_a group_b")

    # Check consistency
    expect(user_has_gid?(users[:a], groups[:a])).to eql(false)
    expect(user_has_gid?(users[:a], groups[:b])).to eql(true)
    expect(user_has_gid?(users[:a], groups[:c])).to eql(false)
    expect(user_has_gid?(users[:a], groups[:d])).to eql(false)

    expect(user_has_gid?(users[:b], groups[:a])).to eql(false)
    expect(user_has_gid?(users[:b], groups[:b])).to eql(false)
    expect(user_has_gid?(users[:b], groups[:c])).to eql(false)
    expect(user_has_gid?(users[:b], groups[:d])).to eql(false)

    expect(user_has_gid?(users[:c], groups[:a])).to eql(false)
    expect(user_has_gid?(users[:c], groups[:b])).to eql(false)
    expect(user_has_gid?(users[:c], groups[:c])).to eql(false)
    expect(user_has_gid?(users[:c], groups[:d])).to eql(true)

    expect(user_has_gid?(users[:d], groups[:a])).to eql(false)
    expect(user_has_gid?(users[:d], groups[:b])).to eql(false)
    expect(user_has_gid?(users[:d], groups[:c])).to eql(true)
    expect(user_has_gid?(users[:d], groups[:d])).to eql(false)

    expect(group_has_uid?(groups[:a], users[:a])).to eql(false)
    expect(group_has_uid?(groups[:a], users[:b])).to eql(false)
    expect(group_has_uid?(groups[:a], users[:c])).to eql(false)
    expect(group_has_uid?(groups[:a], users[:d])).to eql(false)

    expect(group_has_uid?(groups[:b], users[:a])).to eql(true)
    expect(group_has_uid?(groups[:b], users[:b])).to eql(false)
    expect(group_has_uid?(groups[:b], users[:c])).to eql(false)
    expect(group_has_uid?(groups[:b], users[:d])).to eql(false)

    expect(group_has_uid?(groups[:c], users[:a])).to eql(false)
    expect(group_has_uid?(groups[:c], users[:b])).to eql(false)
    expect(group_has_uid?(groups[:c], users[:c])).to eql(false)
    expect(group_has_uid?(groups[:c], users[:d])).to eql(true)

    expect(group_has_uid?(groups[:d], users[:a])).to eql(false)
    expect(group_has_uid?(groups[:d], users[:b])).to eql(false)
    expect(group_has_uid?(groups[:d], users[:c])).to eql(true)
    expect(group_has_uid?(groups[:d], users[:d])).to eql(false)

  end
end