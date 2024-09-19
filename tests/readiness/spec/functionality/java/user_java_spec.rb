#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "User java test" do

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------
    it "User" do
        unless File.exist?('/usr/share/java/xmlrpc-client.jar')
            skip 'Java libraries not installed'
        end

        Dir.chdir("./spec/functionality/java/src") {
            out = `./test.sh UserTest`
            if out.include? "FAILURES!!!"
                fail out
            end
            puts out
        }
    end
end
