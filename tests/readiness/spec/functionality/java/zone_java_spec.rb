#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Zone java test" do

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------
    it "Zone" do
        unless File.exist?('/usr/share/java/xmlrpc-client.jar')
            skip 'Java libraries not installed'
        end

        Dir.chdir("./spec/functionality/java/src") {
            out = `./test.sh ZoneTest`
            if out.include? "FAILURES!!!"
                fail out
            end
            puts out
        }
    end
end
