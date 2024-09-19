#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
require "xmlrpc/server"

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "API tests" do
  before(:all) do
      $s = XMLRPC::Server.new(8080)

      $s.add_handler("one.vm.info") do |s,i,j|
          sleep(10)
          "<ERROR/>"
      end

      $thr = Thread.new {
          $s.serve
      }
  end

  after(:all) do
      ENV.delete('ONE_XMLRPC_TIMEOUT')
      ENV.delete('ONE_XMLRPC')

      $s.shutdown
      Thread.kill($thr)
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------
  it "should set a custome timeout to xmlrpc api calls" do
      ENV["ONE_XMLRPC_TIMEOUT"] = "5"
      ENV["ONE_XMLRPC"] = "http://127.0.0.1:8080/RPC2"

      t_start = Time.now
      cli_action("onevm show 0", false)
      t_end = Time.now - t_start

      expect(t_end).to be > 4
      expect(t_end).to be < 6
  end
end
