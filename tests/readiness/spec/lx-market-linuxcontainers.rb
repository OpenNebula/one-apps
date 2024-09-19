require 'lib_lxd/market'

marketplace_mad = 'linuxcontainers'
marketplace_name = 'Linux Containers'
marketplace_suffix = ' - LXC'
timeout = 2000 # some images like OpenSuse can be big and remain locked for a while

describe "#{marketplace_name} marketplace" do
    before(:all) do
        @info = {}

        cli_action("onemarket enable \'#{marketplace_name}\'")
    end

    @defaults = RSpec.configuration.defaults
    @defaults[:apps].each do |market, apps|
        next unless market == marketplace_mad.to_sym

        apps.each do |app|
            context "test appliance #{app}" do
                it_should_behave_like 'container marketplaces', app,
                                      marketplace_suffix, marketplace_name, timeout
            end
        end
    end
end
