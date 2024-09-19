#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
require 'fileutils'
require 'tempfile'

#-------------------------------------------------------------------------------
# This is older testset for basic LDAP auth functions. It uses local LDAP server
# running on 389 prot which the  `memberOf` plugin enabled which better mimics
# AcitveDirectory. This setup thus requires the option:
#
# rfc2370bis: true
#
# Then group assignment is done in user entry, e.g.:
#
#     # userX, people, orga
#     dn: uid=userX,ou=people,dc=orga
#     objectClass: top
#     objectClass: posixAccount
#     objectClass: nsMemberOf
#     uid: userX
#     cn: userX
#     uidNumber: 10001
#     gidNumber: 10001
#     homeDirectory: /var/empty
#     loginShell: /bin/false
#     memberOf: cn=groupX,ou=groups,dc=orga   <-- group reference
#     memberOf: cn=cloud,ou=groups,dc=orga    <-- group reference
#
#-------------------------------------------------------------------------------

def set_auth(user, password, &block)
    previous_auth = ENV["ONE_AUTH"]

    tmpfile = Tempfile.new("one_auth")
    tmpfile.puts("#{user}:#{password}")
    tmpfile.close

    ENV["ONE_AUTH"] = tmpfile.path

    block.call

    ENV["ONE_AUTH"] = previous_auth
    tmpfile.unlink
end

RSpec.describe "LDAP Authentication tests" do
    before(:all) do
        # bug https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=870032
        # breaks 389-ds install on debian9
        skip if `hostname`.match('debian9')

        # bug https://bugzilla.redhat.com/show_bug.cgi?id=1886024
        # breaks 389-ds install on RH7
        skip if `hostname`.match('rhel7')

        conf_file = File.join(File.dirname(__FILE__), 'ldap_auth.conf')
        auth_dir = "#{ONE_ETC_LOCATION}/auth"

        FileUtils.cp(conf_file, auth_dir)

        @groupX = cli_create("onegroup create groupX")
        cli_update("onegroup update groupX", <<-EOT, false)
            GROUP_DN="cn=groupX,ou=groups,dc=orga"
        EOT

        @groupY = cli_create("onegroup create groupY")
        cli_update("onegroup update groupY", <<-EOT, false)
            GROUP_DN="cn=groupY,ou=groups,dc=orga"
        EOT

        @info = {}
    end

    after(:all) do
        ENV['ONE_AUTH'] = nil
    end

    it "should authenticate user in groupX" do
        set_auth("userX", "opennebula") do
            xml = cli_action_xml("oneuser show -x")
            # ldap auth driver always return downcase to prevent
            # multiple users to be created using single ldap entry
            expect(xml["NAME"]).to eq("userx")
            expect(xml["GNAME"]).to eq("groupX")
        end
    end

    it "should not authenticate user in groupX as group admin" do
        set_auth("userx", "opennebula") do
            xml = cli_action_xml("oneuser show -x")
            @info[:userX_id] = xml["ID"]
            xml = cli_action_xml("onegroup show -x groupX")
            expect(xml["ADMINS/ID"]).to be(nil)
        end
    end

    it "should not authenticate user in groupX with bad password" do
        set_auth("userx", "userX_bad") do
            xml = cli_action("oneuser show", false)
        end
    end

    it "should authenticate user in groupY despite different case in template" do
        set_auth("userY", "opennebula") do
            xml = cli_action_xml("oneuser show -x")
            expect(xml["NAME"]).to eq("usery")
            expect(xml["GNAME"]).to eq("groupY")
        end
    end

    it "should authenticate user in groupY as admin" do
        set_auth("usery", "opennebula") do
            xml = cli_action_xml("oneuser show -x")
            expect(xml["NAME"]).to eq("usery")
            expect(xml["GNAME"]).to eq("groupY")
            user_id = xml["ID"]

            xml = cli_action_xml("onegroup show -x groupY")
            expect(xml["ADMINS/ID"]).to eq(user_id)
        end
    end

    it "should authenticate user in two groups" do
        set_auth("userXY", "opennebula") do
            xml = cli_action_xml("oneuser show -x")
            @info[:userXY_id] = xml["ID"]
            hash = xml.to_hash
            expect(hash["USER"]["GROUPS"]["ID"].class).to be Array
            expect(hash["USER"]["GROUPS"]["ID"].length).to be 2
        end
    end

    it "should authenticate user in two groups, not as admin" do
        set_auth("userxy", "opennebula") do

            # groupX has no admins
            hash = cli_action_xml("onegroup show -x groupX").to_hash
            expect(hash['GROUP']['ADMINS']['ID']).to be(nil)

            # groupY has only one admin (userY) but not userXY
            hash = cli_action_xml("onegroup show -x groupY").to_hash
            expect(hash['GROUP']['ADMINS']['ID']).not_to include(@info[:userXY_id])
        end
    end

    it "should not authenticate user that doesn't belong to cloud group" do
        set_auth("user_nocloud", "opennebula") do
            xml = cli_action("oneuser show", false)
        end
    end
end
