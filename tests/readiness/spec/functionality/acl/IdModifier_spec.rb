#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "ACL Id modifier test" do
  #---------------------------------------------------------------------------
  # OpenNebula bootstraping:
  #   - Define infrastructure: hosts, datastore, users, networks,...
  #   - Common instance variables: templates,...
  #---------------------------------------------------------------------------
  before(:all) do
    user_names = {
      :a => "a",
      :b => "b",
      :c => "c",
      :d => "d"
    }

    @users = Hash.new

    group_names = {
      :a => "group_a",
      :b => "group_b",
      :c => "group_c",
      :d => "group_d",
      :e => "group_e",
      :f => "group_f",
      :g => "group_g",
      :h => "group_h"
    }

    @groups = Hash.new

    # Create all @groups
    group_names.each do |entry|
      gid = cli_create("onegroup create #{entry[1]}")

      @groups[entry[0]] = gid

      cli_action("onevdc delgroup 0 #{gid}")
    end

    user_names.each do |entry|
      uid = cli_create_user(entry[1], "p")
      cli_action("oneuser chgrp #{uid} #{@groups[entry[0]]}")

      @users[entry[0]] = uid
    end

    id = cli_create_user("z", "password_z")
    cli_action("oneuser chgrp #{id} #{@groups[:c]}")
    cli_action("oneuser addgroup #{id} #{@groups[:a]}")

    @users[:z] = id

    # Create some @templates, each one in its group
    template_keys = [ :e, :f, :g, :h ]

    @templates = Hash.new

    template_keys.each do |key|
      tid = cli_create("onetemplate create", "NAME = template_#{key}")

      cli_action("onetemplate chgrp #{tid} #{@groups[key]}")

      @templates[key] = tid
    end

    @cid1 = cli_create("onecluster create cluster1")
    @cid2 = cli_create("onecluster create cluster2")

    @host0 = cli_create("onehost create host0 --im dummy --vm dummy")
    @host1 = cli_create("onehost create host1 -c cluster1 --im dummy --vm dummy")
    @host2 = cli_create("onehost create host2 -c cluster2 --im dummy --vm dummy")

    @ds0 = cli_create("onedatastore create", "NAME = ds0\nTM_MAD=dummy\nDS_MAD=dummy")
    @ds1 = cli_create("onedatastore create -c cluster1", "NAME = ds1\nTM_MAD=dummy\nDS_MAD=dummy")
    @ds2 = cli_create("onedatastore create -c cluster2", "NAME = ds2\nTM_MAD=dummy\nDS_MAD=dummy")

    @net0 = cli_create("onevnet create", "NAME = net0\nVN_MAD=dummy\nBRIDGE=vbr0")
    @net1 = cli_create("onevnet create -c cluster1", "NAME = net1\nVN_MAD=dummy\nBRIDGE=vbr0")
    @net2 = cli_create("onevnet create -c cluster2", "NAME = net2\nVN_MAD=dummy\nBRIDGE=vbr0")
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "should try to perform unauthorized operations and"<<
      " check the failure" do
      as_user("a"){ cli_action("onetemplate show #{@templates[:e]}", false) }
      as_user("b"){ cli_action("onetemplate show #{@templates[:e]}", false) }
      as_user("c"){ cli_action("onetemplate show #{@templates[:e]}", false) }
      as_user("d"){ cli_action("onetemplate show #{@templates[:e]}", false) }
      as_user("z"){ cli_action("onetemplate show #{@templates[:e]}", false) }

      as_user("a"){ cli_action("onetemplate show #{@templates[:f]}", false) }
      as_user("b"){ cli_action("onetemplate show #{@templates[:f]}", false) }
      as_user("c"){ cli_action("onetemplate show #{@templates[:f]}", false) }
      as_user("d"){ cli_action("onetemplate show #{@templates[:f]}", false) }
      as_user("z"){ cli_action("onetemplate show #{@templates[:f]}", false) }

      as_user("a"){ cli_action("onetemplate show #{@templates[:g]}", false) }
      as_user("b"){ cli_action("onetemplate show #{@templates[:g]}", false) }
      as_user("c"){ cli_action("onetemplate show #{@templates[:g]}", false) }
      as_user("d"){ cli_action("onetemplate show #{@templates[:g]}", false) }
      as_user("z"){ cli_action("onetemplate show #{@templates[:g]}", false) }

      as_user("a"){ cli_action("onetemplate show #{@templates[:h]}", false) }
      as_user("b"){ cli_action("onetemplate show #{@templates[:h]}", false) }
      as_user("c"){ cli_action("onetemplate show #{@templates[:h]}", false) }
      as_user("d"){ cli_action("onetemplate show #{@templates[:h]}", false) }
      as_user("z"){ cli_action("onetemplate show #{@templates[:h]}", false) }
  end

  it "should create a rule from # to TEMPLATE/# and check the user can"<<
      " perform the operation" do

    cli_action("oneacl create '##{@users[:a]} TEMPLATE/##{@templates[:e]} USE'")

    as_user("a"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:e]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:f]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:g]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:h]}", false) }
  end

  it "should create a rule from # to TEMPLATE/@ and check the user can"<<
      " perform the operation" do

    cli_action("oneacl create '##{@users[:b]} TEMPLATE/@#{@groups[:f]} USE'")

    as_user("a"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:e]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:f]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:g]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:h]}", false) }
  end

  it "should create a rule from # to TEMPLATE/* and check the user can"<<
      " perform the operation" do

    cli_action("oneacl create '##{@users[:c]} TEMPLATE/* USE'")

    as_user("a"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:e]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:f]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:g]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:g]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:h]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:h]}", false) }
  end

  it "should create a rule from @ to TEMPLATE/# and check the user can"<<
      " perform the operation" do

    cli_action("oneacl create '@#{@groups[:a]} TEMPLATE/##{@templates[:f]} USE'")

    as_user("a"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:e]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:f]}", true) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:g]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:g]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:h]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:h]}", false) }
  end

  it "should create a rule from @ to TEMPLATE/@ and check the user can"<<
      " perform the operation" do

    cli_action("oneacl create '@#{@groups[:a]} TEMPLATE/@#{@groups[:g]} USE'")

    as_user("a"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:e]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:f]}", true) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:g]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:g]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:g]}", true) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:h]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:h]}", false) }
  end

  it "should create a rule from @ to TEMPLATE/* and check the user can"<<
      " perform the operation" do

    cli_action("oneacl create '@#{@groups[:a]} TEMPLATE/* USE'")

    as_user("a"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:e]}", true) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:f]}", true) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:g]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:g]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:g]}", true) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:h]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:h]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:h]}", true) }
  end

  it "should create a rule from * to TEMPLATE/# and check the user can"<<
      " perform the operation" do

    cli_action("oneacl create '* TEMPLATE/##{@templates[:e]} USE'")

    as_user("a"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:e]}", true) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:f]}", true) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:g]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:g]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:g]}", true) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:h]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:h]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:h]}", true) }
  end

  it "should create a rule from * to TEMPLATE/@ and check the user can"<<
      " perform the operation" do

    cli_action("oneacl create '* TEMPLATE/@#{@groups[:g]} USE'")

    as_user("a"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:e]}", true) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:f]}", true) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:g]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:g]}", true) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:g]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:g]}", true) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:g]}", true) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:h]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:h]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:h]}", true) }
  end

  it "should create a rule from * to TEMPLATE/* and check the user can"<<
      " perform the operation" do

    cli_action("oneacl create '* TEMPLATE/* USE'")

    as_user("a"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:e]}", true) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:f]}", true) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:g]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:g]}", true) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:g]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:g]}", true) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:g]}", true) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:h]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:h]}", true) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:h]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:h]}", true) }
    as_user("z"){ cli_action("onetemplate show #{@templates[:h]}", true) }
  end

  it "should create a rule from # to % and check the user can perform the operation" do

    cli_action("oneacl create '##{@users[:a]} HOST+DATASTORE+NET/%#{@cid1} USE'")

    # Cluster none
    as_user("a") { cli_action("onehost show #{@host0}", false) }
    as_user("b") { cli_action("onehost show #{@host0}", false) }

    as_user("a") { cli_action("onedatastore show #{@ds0}", false) }
    as_user("b") { cli_action("onedatastore show #{@ds0}", false) }

    as_user("a") { cli_action("onevnet show #{@net0}", false) }
    as_user("b") { cli_action("onevnet show #{@net0}", false) }

    # Cluster 1
    as_user("a") { cli_action("onehost show #{@host1}") }
    as_user("b") { cli_action("onehost show #{@host1}", false) }

    as_user("a") { cli_action("onedatastore show #{@ds1}") }
    as_user("b") { cli_action("onedatastore show #{@ds1}", false) }

    as_user("a") { cli_action("onevnet show #{@net1}") }
    as_user("b") { cli_action("onevnet show #{@net1}", false) }

    # Cluster 2
    as_user("a") { cli_action("onehost show #{@host2}", false) }
    as_user("b") { cli_action("onehost show #{@host2}", false) }

    as_user("a") { cli_action("onedatastore show #{@ds2}", false) }
    as_user("b") { cli_action("onedatastore show #{@ds2}", false) }

    as_user("a") { cli_action("onevnet show #{@net2}", false) }
    as_user("b") { cli_action("onevnet show #{@net2}", false) }
  end

  it "should create a rule from @ to % and check the group can perform the operation" do

    cli_action("oneacl create '@#{@groups[:b]} HOST+DATASTORE+NET/%#{@cid2} USE'")

    # Cluster none
    as_user("a") { cli_action("onehost show #{@host0}", false) }
    as_user("b") { cli_action("onehost show #{@host0}", false) }

    as_user("a") { cli_action("onedatastore show #{@ds0}", false) }
    as_user("b") { cli_action("onedatastore show #{@ds0}", false) }

    as_user("a") { cli_action("onevnet show #{@net0}", false) }
    as_user("b") { cli_action("onevnet show #{@net0}", false) }

    # Cluster 1
    as_user("a") { cli_action("onehost show #{@host1}") }
    as_user("b") { cli_action("onehost show #{@host1}", false) }

    as_user("a") { cli_action("onedatastore show #{@ds1}") }
    as_user("b") { cli_action("onedatastore show #{@ds1}", false) }

    as_user("a") { cli_action("onevnet show #{@net1}") }
    as_user("b") { cli_action("onevnet show #{@net1}", false) }

    # Cluster 2
    as_user("a") { cli_action("onehost show #{@host2}", false) }
    as_user("b") { cli_action("onehost show #{@host2}") }

    as_user("a") { cli_action("onedatastore show #{@ds2}", false) }
    as_user("b") { cli_action("onedatastore show #{@ds2}") }

    as_user("a") { cli_action("onevnet show #{@net2}", false) }
    as_user("b") { cli_action("onevnet show #{@net2}") }
  end

  it "should create a rule from * to % and check the users can perform the operation" do

    cli_action("oneacl create '* HOST+DATASTORE+NET/%#{@cid2} USE'")

    # Cluster none
    as_user("a") { cli_action("onehost show #{@host0}", false) }
    as_user("b") { cli_action("onehost show #{@host0}", false) }

    as_user("a") { cli_action("onedatastore show #{@ds0}", false) }
    as_user("b") { cli_action("onedatastore show #{@ds0}", false) }

    as_user("a") { cli_action("onevnet show #{@net0}", false) }
    as_user("b") { cli_action("onevnet show #{@net0}", false) }

    # Cluster 1
    as_user("a") { cli_action("onehost show #{@host1}") }
    as_user("b") { cli_action("onehost show #{@host1}", false) }

    as_user("a") { cli_action("onedatastore show #{@ds1}") }
    as_user("b") { cli_action("onedatastore show #{@ds1}", false) }

    as_user("a") { cli_action("onevnet show #{@net1}") }
    as_user("b") { cli_action("onevnet show #{@net1}", false) }

    # Cluster 2
    as_user("a") { cli_action("onehost show #{@host2}") }
    as_user("b") { cli_action("onehost show #{@host2}") }

    as_user("a") { cli_action("onedatastore show #{@ds2}") }
    as_user("b") { cli_action("onedatastore show #{@ds2}") }

    as_user("a") { cli_action("onevnet show #{@net2}") }
    as_user("b") { cli_action("onevnet show #{@net2}") }
  end
end