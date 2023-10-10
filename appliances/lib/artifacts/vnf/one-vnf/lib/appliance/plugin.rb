# -------------------------------------------------------------------------- #
# Copyright 2002-2020, OpenNebula Project, OpenNebula Systems                #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

# Generic plugin interface
class Appliance::Plugin

    attr_reader :name, :enabled, :logger

    def initialize(name, app_config, logger)
        @name   = name
        @logger = logger
        @timer  = 0

        configure(app_config)
    end

    def configure(app_config)
        # store only configuration for plugin
        @config = app_config[@name]
        @config ||= {}

        @enabled = @config['enabled']
        @enabled ||= false

        @refresh_rate = 60
        @refresh_rate = Integer(@config['refresh-rate']) if @config.key?('refresh-rate')
    end

    def run; end

    def cleanup; end

    def ready?
        return false unless @enabled

        @timer += 1

        if @timer >= @refresh_rate
            @timer = 0
            return true
        end

        false
    end

end
