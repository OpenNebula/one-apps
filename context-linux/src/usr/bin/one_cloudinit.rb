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

require 'psych'
require 'logger'
require 'open3'

##
# The CloudInit module implements cloud-init features for OpenNebula
# contextualization.
##
module CloudInit

    Logger = Logger.new(
        STDOUT,
        :level => Logger::INFO,
        :formatter => proc {|severity, datetime, _progname, msg|
            date_format = datetime.strftime('%Y-%m-%d %H:%M:%S')
            "[#{date_format} - #{severity}]: #{msg}\n"
        }
    )

    def self.print_exception(exception, prefix = 'Exception')
        Logger.error("#{prefix}: #{exception.message}\n#{exception.backtrace.join("\n")}")
    end

    def self.load_cloud_config_from_user_data
        user_data = ENV['USER_DATA']

        if user_data.nil?
            Logger.info('No USER_DATA found.')
            return
        end
        CloudConfig.from_yaml(user_data)
    end

    ##
    # The CloudConfig module contains the functionality for parsing and executing
    # cloud-config YAML files.
    ##
    class CloudConfig

        attr_accessor :write_files, :runcmd

        def initialize(write_files = [], runcmd = [])
            @write_files = write_files
            @runcmd = runcmd
        end

        def self.from_yaml(yaml_string)
            begin
                parsed_cloud_config = Psych.safe_load(yaml_string, :symbolize_names => true)
            rescue Psych::SyntaxError => e
                raise "YAML parsing failed: #{e.message}"
            end

            write_files = CloudConfigList.new(
                parsed_cloud_config[:write_files], WriteFile.method(:from_map)
            ) if parsed_cloud_config.key?(:write_files)

            runcmd = RunCmd.new(parsed_cloud_config[:runcmd]) if parsed_cloud_config.key?(:runcmd)

            return new(write_files, runcmd)
        end

        def exec
            # TODO: Define directives execution order
            instance_variables.each do |var|
                cloudconfig_directive = instance_variable_get(var)
                if !cloudconfig_directive.respond_to?(:exec)
                    # TODO: Raise a not implemented exception or just ignore?
                    next
                end

                cloudconfig_directive.exec
            end
        end

        ##
        # CloudConfigList class ,manages generic cloud-config directives lists
        ##
        class CloudConfigList

            attr_accessor :cloud_config_list

            def initialize(data_array, mapping_method)
                unless data_array.is_a?(Array)
                    raise 'CloudConfigList should be initialized with an Array'
                end

                @cloud_config_list = data_array.map do |element|
                    mapping_method.call(element)
                end
            end

            def exec
                @cloud_config_list.each do |element|
                    if !element.respond_to?(:exec)
                        # TODO: Raise a not implemented exception or just ignore?
                        next
                    end

                    element.exec
                end
            end

        end

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
                # TODO
                Logger.info("[writeFile] writing file [#{@permissions} #{@owner} #{@path}]")
            end

            def self.from_map(data_map)
                unless data_map.is_a?(Hash)
                    raise 'WriteFile.from_map must be called with a Hash as an argument'
                end

                WriteFile.new(**data_map)
            end

        end

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
                    Logger.info("[runCmd] executing '#{cmd}'")
                end
            end

        end

    end

end

# script start
begin
    cloud_config = CloudInit.load_cloud_config_from_user_data
rescue StandardError => e
    CloudInit.print_exception(e, 'could not parse USER_DATA')
    exit 1
end

if cloud_config.nil?
    exit 0
end

begin
    cloud_config.exec
rescue StandardError => e
    CloudInit.print_exception(e, 'error executing cloud-config')
    exit 1
end
