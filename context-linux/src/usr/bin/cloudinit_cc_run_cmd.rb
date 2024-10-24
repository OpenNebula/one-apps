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

require 'fileutils'

module CloudInit

    ##
    # RunCmd class implements the runcmd cloud-config directive.
    ##
    class RunCmd

        TMP_DIR_PATH = '/var/lib/one-context/tmp/runcmd'

        attr_accessor :cmd_list

        def initialize(cmd_list)
            unless cmd_list.is_a?(Array)
                raise 'RunCmd must be instantiated with a command list as an argument'
            end

            @cmd_list = cmd_list
        end

        def exec
            if @cmd_list.empty?
                CloudInit::Logger.debug('[runCmd] empty cmdlist, ignoring...')
                return
            end
            CloudInit::Logger.debug("[runCmd] processing commands'")

            FileUtils.mkdir_p(TMP_DIR_PATH)
            begin
                file_content = create_shell_file_content
            rescue StandardError => e
                raise "could not generate runcmd script file content: #{e.message}"
            end

            temp_file_path = File.join(TMP_DIR_PATH, 'runcmd_script')
            File.open(temp_file_path, 'w', 0o700) do |file|
                file.write(file_content)
            end

            CloudInit::Logger.debug("[runCmd] runcmd script successfully created in '#{temp_file_path}'")
        end

        def create_shell_file_content
            content = "#!/bin/sh\n"
            @cmd_list.each do |cmd|
                if cmd.is_a?(Array)
                    escaped = []
                    cmd.each do |token|
                        # escape single quotes inside single quoted shell command
                        modified_string = token.gsub("'") {|x| "'\\#{x}'" }
                        escaped << "\'#{modified_string}\'"
                    end
                    content << "#{escaped.join(' ')}\n"
                elsif cmd.is_a?(String)
                    content << "#{cmd}\n"
                else
                    raise 'incompatible command specification, must be array or string'
                end
            end
            return content
        end

    end

end
