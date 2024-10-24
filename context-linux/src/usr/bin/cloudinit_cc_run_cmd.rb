#!/usr/bin/env ruby

# -------------------------------------------------------------------------- #
# Copyright 2002-2024, OpenNebula Project, OpenNebula Systems                #
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

module CloudInit

    ##
    # RunCmd class implements the runcmd cloud-config directive.
    ##
    class RunCmd

        attr_accessor :cmd_list

        def initialize(cmd_list)
            unless cmd_list.is_a?(Array)
                raise 'RunCmd must be instantiated with a command list as an argument'
            end

            @cmd_list = cmd_list
        end

        def exec
            @cmd_list.each do |cmd|
                # TODO: implement logic
                puts "[runCmd] executing '#{cmd}'"
            end
        end

    end

end
