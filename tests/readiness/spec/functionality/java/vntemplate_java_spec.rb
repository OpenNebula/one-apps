#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "VNTemplate java test" do

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------
    it "VNTemplate" do
        unless File.exist?('/usr/share/java/xmlrpc-client.jar')
            skip 'Java libraries not installed'
        end

        Dir.chdir("./spec/functionality/java/src") {
            out = `./test.sh VNTemplateTest`
            if out.include? "FAILURES!!!"
                fail out
            end
            puts out
        }
    end
end
