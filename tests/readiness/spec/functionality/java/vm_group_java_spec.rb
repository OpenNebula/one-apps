#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Virtual Machine Group java test" do

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------
    it "VMGroup" do
        unless File.exist?('/usr/share/java/xmlrpc-client.jar')
            skip 'Java libraries not installed'
        end

        Dir.chdir("./spec/functionality/java/src") {
            out = `./test.sh VMGroupTest`
            if out.include? "FAILURES!!!"
                fail out
            end
            puts out
        }
    end
end
