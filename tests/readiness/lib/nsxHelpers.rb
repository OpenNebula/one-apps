require 'nsx_driver'

module nsxHelpers
    def check_nsx_net(hostid, vnet)
        @nsx_client = NSXDriver::NSXClient.new_from_id(hostid)
    end

end