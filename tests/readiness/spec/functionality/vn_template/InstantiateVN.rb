#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Permissions test" do

    prepend_before(:all) do
        @defaults = YAML::load(File.read("spec/functionality/vn_template/defaults.yaml"))
        @defaults_yaml=File.realpath(File.join(File.dirname(__FILE__),'defaults.yaml'))
    end

    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        template = <<-EOF
            NAME   = test_vntemplate
            VN_MAD = bridge
            ATT1   = "VAL1"
            ATT2   = "VAL2"
        EOF


        @template_id = cli_create("onevntemplate create", template)
    
        @id_user = cli_create("oneuser create uA uA")
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should allocate a new VirtualMachine that uses an existing Template" do
        id = cli_create("onevntemplate instantiate #{@template_id}")

        cli_action("onevnet delete #{id}")
    end

    it "should allocate a new VirtualMachine that uses an existing Template "<<
        "replacing the instance name" do

        id = cli_create("onevntemplate instantiate --name other"\
                        " #{@template_id}")

        xml = cli_action_xml("onevnet show -x #{id}")

        expect(xml['NAME']).to eq("other")

        cli_action("onevnet delete #{id}")
    end

    it "should instantiate and merge from a Template" do
        template = <<-EOF
            ATT3 = 0.1
            ATT4 = 128
            EXTRA = abc
        EOF

        id = cli_create("onevntemplate instantiate #{@template_id}", template)

        xml = cli_action_xml("onevnet show -x #{id}")

        expect(xml['TEMPLATE/ATT3']).to eq("0.1")
        expect(xml['TEMPLATE/ATT4']).to eq("128")
        expect(xml['TEMPLATE/EXTRA']).to eq("abc")

        cli_action("onevnet delete #{id}")
    end

    it "should instantiate a template with a different owner" do

        template = <<-EOF
            NAME   = vntemplate_uid
            VN_MAD = bridge
            AS_UID = #{@id_user}
        EOF

        template_id = cli_create("onevntemplate create", template)
        id = cli_create("onevntemplate instantiate #{template_id}")

        xml = cli_action_xml("onevnet show -x #{id}")

        expect(xml['UNAME']).to eq("uA")
        expect(xml['GNAME']).to eq("oneadmin")

        cli_action("onevnet delete #{id}")
    end

    it "should instantiate a template with a different group" do

        template = <<-EOF
            NAME   = vntemplate_gid
            VN_MAD = bridge
        EOF

        template_id = cli_create("onevntemplate create", template)
        id = cli_create("onevntemplate instantiate #{template_id} --as_gid 1")

        xml = cli_action_xml("onevnet show -x #{id}")

        expect(xml['UNAME']).to eq("oneadmin")
        expect(xml['GNAME']).to eq("users")

        cli_action("onevnet delete #{id}")
    end

    it "should instantiate a template with a different group and owner" do

        @ga_id = cli_create("onegroup create ga")
        @user_admin = cli_create("oneuser create uadmin uadmin")
        @user = cli_create("oneuser create user user")

        cli_action("oneuser addgroup uadmin ga")
        cli_action("oneuser addgroup user ga")

        cli_action("onegroup addadmin ga uadmin")

        template = <<-EOF
            NAME   = template_uid_gid
            VN_MAD = bridge
        EOF

        template_id = cli_create("onevntemplate create", template)

        cli_action( "onevntemplate chown #{template_id} #{@user_admin}")
        cli_action( "onevntemplate chgrp #{template_id} #{@ga_id}")
        cli_action( "onevntemplate chmod #{template_id} 640")

        as_user("uadmin") do
            id = cli_create("onevntemplate instantiate #{template_id} --as_uid #{@user} --as_gid #{@ga_id}")

            xml = cli_action_xml("onevnet show -x #{id}")

            expect(xml['UNAME']).to eq("user")
            expect(xml['GNAME']).to eq("ga")

            cli_action("onevnet delete #{id}")
        end
    end

    it "should instantiate a template and add the VNET to the specified clusters" do

        cluster_id = cli_create("onecluster create cluster_test")

        template = <<-EOF
            NAME   = template_cluster1
            VN_MAD = bridge
            CLUSTER_IDS = "2,#{cluster_id}"
        EOF

        template_id = cli_create("onevntemplate create", template)
        id = cli_create("onevntemplate instantiate #{template_id}")

        xml_vn = cli_action_xml("onevnet show -x #{id}")
        xml_cl = cli_action_xml("onecluster show -x #{cluster_id}")

        expect(xml_vn.to_hash["VNET"]["CLUSTERS"]["ID"]).to eq(cluster_id.to_s)
        expect(xml_cl.to_hash["CLUSTER"]["VNETS"]["ID"]).to eq(id.to_s)

        cli_action("onevnet delete #{id}")

    end

    it "should instantiate a template and add the VNET to the default clusters" do

        template = <<-EOF
            NAME   = template_cluster_default
            VN_MAD = bridge
        EOF

        template_id = cli_create("onevntemplate create", template)
        id = cli_create("onevntemplate instantiate #{template_id}")

        xml_vn = cli_action_xml("onevnet show -x #{id}")
        xml_cl = cli_action_xml("onecluster show -x 0")

        expect(xml_vn.to_hash["VNET"]["CLUSTERS"]["ID"]).to eq("0")
        expect(xml_cl.to_hash["CLUSTER"]["VNETS"]["ID"]).to eq(id.to_s)

        cli_action("onevnet delete #{id}")

    end

    it "should fails when instantiate a template modifiying a restricted attributes" do

        template = <<-EOF
            NAME   = template_ra
            VN_MAD = bridge
        EOF

        extra_template = <<-EOF
            CLUSTER_IDS="0,2"
        EOF

        template_id = cli_create("onevntemplate create", template)
        cli_action("onevntemplate chmod #{template_id} 644")

        cli_create("onevntemplate instantiate #{template_id} --user uA --password uA", extra_template, false)

    end

end