#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Build the java test programs" do

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------
    it "should build the tests" do
        Dir.chdir("./spec/functionality/java/") {
            cmd = SafeExec.run('./build.sh')

            puts cmd.stdout

            fail cmd.stderr if cmd.fail?
        }
    end
end