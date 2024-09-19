require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Compatibility between datastores" do

  before(:all) do

    cli_update("onedatastore update system", "TM_MAD=dummy\nDS_MAD=dummy", false)
    cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)

    #Create a system ds
    ds_tmpl = <<-EOF
                NAME="system-test"
                CLUSTERS="0"
                TYPE="SYSTEM_DS"
                ALLOW_ORPHANS="NO"
                DISK_TYPE="FILE"
                DS_MIGRATE="YES"
                RESTRICTED_DIRS="/"
                SAFE_DIRS="/var/tmp"
                SHARED="NO"
                TM_MAD="ssh"
                TYPE="SYSTEM_DS"
                EOF

    @ds_sys_id = cli_create("onedatastore create", ds_tmpl)

    #Create an image ds
    ds_tmpl = <<-EOF
                NAME="image-test"
                CLUSTERS="0"
                TYPE="IMAGE"
                DISK_TYPE="FILE"
                DS_MIGRATE="YES"
                RESTRICTED_DIRS="/"
                SAFE_DIRS="/var/tmp"
                SHARED="NO"
                TYPE="SYSTEM_DS"
                DS_MAD="dummy"
                TM_MAD="dummy"
                EOF

    @ds_img_id = cli_create("onedatastore create", ds_tmpl)

    #create images in both image datastores

    @img1_id = cli_create("oneimage create --name img1 --type os --size 1 --no_check_capacity -d 1")
    @img2_id = cli_create("oneimage create --name img2 --type os --size 1 --no_check_capacity -d #{@ds_img_id}")

  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "shouldn't have any datastore as requirement" do
    id = cli_create("onevm create --name f1 --cpu 1 --memory 128 --disk #{@img1_id}")

    xml = cli_action_xml("onevm show -x #{id}")
    expect(xml["TEMPLATE/AUTOMATIC_DS_REQUIREMENTS"]).to eql("(\"CLUSTERS/ID\" @> 0)")
  end

  it "should have the created datastore as requirement" do
    cli_update("onedatastore update default", "COMPATIBLE_SYS_DS=\"#{@ds_sys_id}\"", false)

    id = cli_create("onevm create --name f1 --cpu 1 --memory 128 --disk #{@img1_id}")

    xml = cli_action_xml("onevm show -x #{id}")
    expect(xml["TEMPLATE/AUTOMATIC_DS_REQUIREMENTS"]).to eql("(\"CLUSTERS/ID\" @> 0) & (\"ID\" @> #{@ds_sys_id})")
  end

  it "should not have any compatible datastore" do
    cli_update("onedatastore update #{@ds_img_id}", "COMPATIBLE_SYS_DS=\"0\"", false)

    id = cli_action("onevm create --name f1 --cpu 1 --memory 128 --disk #{@img1_id},#{@img2_id}", false)
  end

  it "should not have any compatible datastore" do
    cli_update("onedatastore update #{@ds_img_id}", "COMPATIBLE_SYS_DS=\"1,#{@ds_sys_id}\"", false)
    cli_update("onedatastore update default ", "COMPATIBLE_SYS_DS=\"1,#{@ds_sys_id}\"", false)

    id = cli_create("onevm create --name f1 --cpu 1 --memory 128 --disk #{@img1_id},#{@img2_id}")

    xml = cli_action_xml("onevm show -x #{id}")
    expect(xml["TEMPLATE/AUTOMATIC_DS_REQUIREMENTS"]).to eql("(\"CLUSTERS/ID\" @> 0) & (\"ID\" @> 1 | \"ID\" @> #{@ds_sys_id})")
  end

end