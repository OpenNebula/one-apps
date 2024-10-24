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

require 'etc'

module CloudInit

    ##
    # WriteFile class implements the write_file cloud-config directive.
    ##
    class WriteFile

        attr_accessor :path, :content, :source, :owner, :permissions, :encoding, :append, :defer

        def initialize(path:, content: '', source: [], owner: 'root:root',
                       permissions: '0644', encoding: 'text/plain', append: false,
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
            begin
                CloudInit::Logger.info(
                    "[writeFile] writing file [#{@permissions} #{@owner} #{@path}]"
                )

                unless valid_octal?
                    CloudInit::Logger.error(
                        "[writeFile] Invalid permission [#{@permissions} #{@owner} #{@path}]"
                    )
                    raise ArgumentError
                end

                uid, gid = uid_and_guid_by_owner
                File.open(@path, 'w') do |file|
                    file.write(@content)
                    file.chmod(@permissions.to_i(8))
                    file.chown(uid, gid)
                end
            rescue Errno::EACCES
                CloudInit::Logger.error(
                    "[writeFile] Insufficient permissions [#{@permissions} #{@owner} #{@path}]"
                )
            rescue Errno::ENOENT
                CloudInit::Logger.error(
                    "[writeFile] Parent directory missing [#{@permissions} #{@owner} #{@path}]"
                )
            rescue StandardError => e
                CloudInit::Logger.error(
                    "[writeFile] Unexpected error: #{e.message}\n#{e.backtrace.join("\n")}"
                )
            end
        end

        def self.from_map(data_map)
            unless data_map.is_a?(Hash)
                raise 'WriteFile.from_map must be called with a Hash as an argument'
            end

            WriteFile.new(**data_map)
        end

        def valid_octal?
            @permissions.match?(/\A0[0-7]{1,3}\z/)
        end

        def uid_and_guid_by_owner
            user, group = @owner.split(':')

            begin
                return Etc.getpwnam(user).uid, Etc.getgrnam(group).gid
            rescue ArgumentError
                CloudInit::Logger.error(
                    "[writeFile] Owner does not exist [#{@permissions} #{@owner} #{@path}]"
                )
            end
        end

    end

end
