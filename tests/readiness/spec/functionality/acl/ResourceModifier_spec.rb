#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "ACL Resource modifier test" do
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

    # Create some templates, each one in its group
    template_keys = [ :e, :f, :g, :h ]

    @templates = Hash.new

    template_keys.each do |key|
      tid = cli_create("onetemplate create", "NAME = template_#{key}")

      cli_action("onetemplate chgrp #{tid} #{@groups[key]}")

      @templates[key] = tid
    end

    # Create some images
    image_keys = [ :i, :j, :k, :l ]

    @images = Hash.new

    cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)

    wait_loop() {
        xml = cli_action_xml("onedatastore show -x default")
        xml['FREE_MB'].to_i > 0
    }

    image_keys.each do |key|
      id = cli_create("oneimage create --name image_#{key} " <<
                      "--size 100 --type datablock -d default")

      @images[key] = id
    end

    cli_action("oneimage chgrp #{@images[:j]} #{@groups[:f]}")
  end

  it "should try to perform unauthorized operations and"<<
      " check the failure" do

    as_user("a"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:e]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:f]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:g]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:h]}", false) }

    as_user("a"){ cli_action("oneimage show #{@images[:i]}", false) }
    as_user("b"){ cli_action("oneimage show #{@images[:i]}", false) }
    as_user("c"){ cli_action("oneimage show #{@images[:i]}", false) }
    as_user("d"){ cli_action("oneimage show #{@images[:i]}", false) }

    as_user("a"){ cli_action("oneimage show #{@images[:j]}", false) }
    as_user("b"){ cli_action("oneimage show #{@images[:j]}", false) }
    as_user("c"){ cli_action("oneimage show #{@images[:j]}", false) }
    as_user("d"){ cli_action("oneimage show #{@images[:j]}", false) }

    as_user("a"){ cli_action("oneimage show #{@images[:k]}", false) }
    as_user("b"){ cli_action("oneimage show #{@images[:k]}", false) }
    as_user("c"){ cli_action("oneimage show #{@images[:k]}", false) }
    as_user("d"){ cli_action("oneimage show #{@images[:k]}", false) }

    as_user("a"){ cli_action("oneimage show #{@images[:l]}", false) }
    as_user("b"){ cli_action("oneimage show #{@images[:l]}", false) }
    as_user("c"){ cli_action("oneimage show #{@images[:l]}", false) }
    as_user("d"){ cli_action("oneimage show #{@images[:l]}", false) }
  end

  it "should create a rule  from # to TEMPLATE/# and check the user can"<<
      " perform the operation" do

    cli_action("oneacl create '##{@users[:a]} TEMPLATE/##{@templates[:e]} USE'")

    as_user("a"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:e]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:f]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:g]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:h]}", false) }

    as_user("a"){ cli_action("oneimage show #{@images[:i]}", false) }
    as_user("b"){ cli_action("oneimage show #{@images[:i]}", false) }
    as_user("c"){ cli_action("oneimage show #{@images[:i]}", false) }
    as_user("d"){ cli_action("oneimage show #{@images[:i]}", false) }

    as_user("a"){ cli_action("oneimage show #{@images[:j]}", false) }
    as_user("b"){ cli_action("oneimage show #{@images[:j]}", false) }
    as_user("c"){ cli_action("oneimage show #{@images[:j]}", false) }
    as_user("d"){ cli_action("oneimage show #{@images[:j]}", false) }

    as_user("a"){ cli_action("oneimage show #{@images[:k]}", false) }
    as_user("b"){ cli_action("oneimage show #{@images[:k]}", false) }
    as_user("c"){ cli_action("oneimage show #{@images[:k]}", false) }
    as_user("d"){ cli_action("oneimage show #{@images[:k]}", false) }

    as_user("a"){ cli_action("oneimage show #{@images[:l]}", false) }
    as_user("b"){ cli_action("oneimage show #{@images[:l]}", false) }
    as_user("c"){ cli_action("oneimage show #{@images[:l]}", false) }
    as_user("d"){ cli_action("oneimage show #{@images[:l]}", false) }
  end

  it "should create a rule  from # to IMAGE/# and check the user can"<<
      " perform the operation" do

    cli_action("oneacl create '##{@users[:b]} IMAGE/##{@images[:i]} USE'")

    as_user("a"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:e]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:f]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:g]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:h]}", false) }

    as_user("a"){ cli_action("oneimage show #{@images[:i]}", false) }
    as_user("b"){ cli_action("oneimage show #{@images[:i]}", true) }
    as_user("c"){ cli_action("oneimage show #{@images[:i]}", false) }
    as_user("d"){ cli_action("oneimage show #{@images[:i]}", false) }

    as_user("a"){ cli_action("oneimage show #{@images[:j]}", false) }
    as_user("b"){ cli_action("oneimage show #{@images[:j]}", false) }
    as_user("c"){ cli_action("oneimage show #{@images[:j]}", false) }
    as_user("d"){ cli_action("oneimage show #{@images[:j]}", false) }

    as_user("a"){ cli_action("oneimage show #{@images[:k]}", false) }
    as_user("b"){ cli_action("oneimage show #{@images[:k]}", false) }
    as_user("c"){ cli_action("oneimage show #{@images[:k]}", false) }
    as_user("d"){ cli_action("oneimage show #{@images[:k]}", false) }

    as_user("a"){ cli_action("oneimage show #{@images[:l]}", false) }
    as_user("b"){ cli_action("oneimage show #{@images[:l]}", false) }
    as_user("c"){ cli_action("oneimage show #{@images[:l]}", false) }
    as_user("d"){ cli_action("oneimage show #{@images[:l]}", false) }
  end

  it "should create a rule  from @ to TEMPLATE+IMAGE/@ and check the user can"<<
      " perform the operation" do

    cli_action("oneacl create '@#{@groups[:c]} IMAGE+TEMPLATE/@#{@groups[:f]} USE'")

    as_user("a"){ cli_action("onetemplate show #{@templates[:e]}", true) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:e]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:e]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:f]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:f]}", true) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:f]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:g]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:g]}", false) }

    as_user("a"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("b"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("c"){ cli_action("onetemplate show #{@templates[:h]}", false) }
    as_user("d"){ cli_action("onetemplate show #{@templates[:h]}", false) }

    as_user("a"){ cli_action("oneimage show #{@images[:i]}", false) }
    as_user("b"){ cli_action("oneimage show #{@images[:i]}", true) }
    as_user("c"){ cli_action("oneimage show #{@images[:i]}", false) }
    as_user("d"){ cli_action("oneimage show #{@images[:i]}", false) }

    as_user("a"){ cli_action("oneimage show #{@images[:j]}", false) }
    as_user("b"){ cli_action("oneimage show #{@images[:j]}", false) }
    as_user("c"){ cli_action("oneimage show #{@images[:j]}", true) }
    as_user("d"){ cli_action("oneimage show #{@images[:j]}", false) }

    as_user("a"){ cli_action("oneimage show #{@images[:k]}", false) }
    as_user("b"){ cli_action("oneimage show #{@images[:k]}", false) }
    as_user("c"){ cli_action("oneimage show #{@images[:k]}", false) }
    as_user("d"){ cli_action("oneimage show #{@images[:k]}", false) }

    as_user("a"){ cli_action("oneimage show #{@images[:l]}", false) }
    as_user("b"){ cli_action("oneimage show #{@images[:l]}", false) }
    as_user("c"){ cli_action("oneimage show #{@images[:l]}", false) }
    as_user("d"){ cli_action("oneimage show #{@images[:l]}", false) }
  end
end