#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
require 'socket'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

# Configure credentials and xmlrpc endpoint
ENV['PYONE_SESSION'] = File.read("/var/lib/one/.one/one_auth").strip
ENV['PYONE_ENDPOINT'] = "http://#{Socket.gethostname}:2633/RPC2"
ENV['PYTHONHTTPSVERIFY'] = '1'

RSpec.describe "Python tests (python3)" do
    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "Unit tests (python3)" do
        Dir.chdir("./spec/functionality/python") {
            out = `python3 -m unittest discover -v -s tests/ci 2>&1`
            if out.include? "FAIL"
                fail out
            end
            puts out
        }
    end

    it "Integration tests (python3)" do
        Dir.chdir("./spec/functionality/python") {
            out = `python3 -m unittest discover -v -s tests/integration 2>&1`
            if out.include? "FAIL"
                fail out
            end
            puts out
        }
    end
end
