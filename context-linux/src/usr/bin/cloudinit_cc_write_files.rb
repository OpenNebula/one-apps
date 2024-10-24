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
    # WriteFile class implements the write_file cloud-config directive.
    ##
    class WriteFile

        attr_accessor :path, :content, :source, :owner, :permissions, :encoding, :append, :defer

        def initialize(path:, content: '', source: [], owner: 'root:root',
                       permissions: '0o644', encoding: 'text/plain', append: false,
                       defer: false)
            @path = path
            @content = content
            @source = source
            @owner = owner
            @permissions = permissions
            @encoding = encoding
            @append = append
            @defer = defer
        end

        def exec
            # TODO: implement logic
            puts '[writeFile] writing file'
        end

        def self.from_map(data_map)
            unless data_map.is_a?(Hash)
                raise 'WriteFile.from_map must be called with a Hash as an argument'
            end

            WriteFile.new(**data_map)
        end

    end

end
