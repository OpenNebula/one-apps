#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
require 'fileutils'
require 'tempfile'

#-------------------------------------------------------------------------------
# This is newer testset for advanced LDAP auth functions. It uses 2 LDAP servers
# 1. instance running on 389, service: dirsrv@orgA
# 2. instance running on 1389, serivce: dirsrv@orgB
# (389 LDAP is also used for the old test set)
#
# In the ldap_auth.conf the server is choosen by matching the user with regex:
#     ---
#     :match_user_regex:
#        "^.*@orgA$": serverA
#        "^.*@orgB$": serverB
#
#     serverA:
#      ...
#     serverB:
#      ...
#
# While the first instance (389) uses memberOf plugin (:rfc2307bis: true)
# the other does not.
#
# In the other the group assignment is done in group entry
#
#     # cloudB, groups, orgb
#     dn: cn=cloudB,ou=groups,dc=orgb
#     objectClass: top
#     objectClass: groupOfNames
#     objectClass: posixGroup
#     cn: groupB
#     cn: cloudB
#     gidNumber: 20105
#     member: uid=userB1@orgB,ou=people,dc=orgB   <-- user reference
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

RSpec.describe "LDAP Authentication tests 2" do
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do
        # bug https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=870032
        # breaks 389-ds install on debian9
        skip if `hostname`.match('debian9')

        # bug https://bugzilla.redhat.com/show_bug.cgi?id=1886024
        # breaks 389-ds install on RH7
        skip if `hostname`.match('rhel7')

        conf_file = File.join(File.dirname(__FILE__), 'ldap_auth2.conf')
        auth_file = "#{ONE_ETC_LOCATION}/auth/ldap_auth.conf"

        FileUtils.cp(conf_file, auth_file)

        @groupA = cli_create("onegroup create groupA")
        cli_update("onegroup update groupA", <<-EOT, false)
            GROUP_DN="cn=groupA,ou=groups,dc=orga"
        EOT

        @groupB = cli_create("onegroup create groupB")
        cli_update("onegroup update groupB", <<-EOT, false)
            GROUP_DN="cn=groupB,ou=groups,dc=orgb"
        EOT

        @info = {}
    end

    after(:all) do
        ENV['ONE_AUTH'] = nil
    end

    it "should authenticate user userA1@orgA in groupA" do
        set_auth("userA1@orgA", "opennebula") do
            xml = cli_action_xml("oneuser show -x")
            # ldap auth driver always return downcase to prevent
            # multiple users to be created using single ldap entry
            expect(xml["NAME"]).to eq("usera1@orga")
            expect(xml["GNAME"]).to eq("groupA")
        end
    end

    it "should authenticate user userB1@orgB in groupB" do
        set_auth("userB1@orgB", "opennebula") do
            xml = cli_action_xml("oneuser show -x")
            # ldap auth driver always return downcase to prevent
            # multiple users to be created using single ldap entry
            expect(xml["NAME"]).to eq("userb1@orgb")
            expect(xml["GNAME"]).to eq("groupB")
        end
    end

    it "should not authenticate user in groupA with bad password" do
        set_auth("userA1@orgA", "bad") do
            cli_action("oneuser show", false)
        end
    end

    it "should not authenticate user that doesn't belong to cloud group" do
        set_auth("userA3@orgA", "opennebula") do
            cli_action("oneuser show", false)
        end
    end
end
