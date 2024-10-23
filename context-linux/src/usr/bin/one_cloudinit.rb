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
require 'singleton'

##
# 
##
module CloudInit

  Logger = Logger.new(
    STDOUT, 
    level: Logger::INFO,
    formatter: proc {|severity, datetime, progname, msg|
      date_format = datetime.strftime("%Y-%m-%d %H:%M:%S")
      "[#{date_format} - #{severity}]: #{msg}\n"
  })

  def self.load_cloud_config_from_user_data()
    user_data = ENV['USER_DATA']

    if user_data.nil?
      Logger.info("No USER_DATA found.")
      return nil
    end
    CloudConfig.from_yaml(user_data)
  end

  ##
  # The CloudInit module contains the functionality for parsing and executing
  # cloud-config YAML files.
  ##
  class CloudConfig
    attr_accessor :write_files, :runcmd

    def initialize(write_files: [], runcmd: [])
      @write_files = write_files
      @runcmd = runcmd
    end

    def self.from_yaml(yaml_string)
      begin
        parsed_cloud_config = Psych.safe_load(yaml_string)
      rescue Psych::SyntaxError => err
        raise "YAML parsing failed: #{err.message}"
      end

      write_files = CloudConfigList.new(data_map: parsed_cloud_config['write_files'], mapping_method: WriteFile.method(:from_map))
      runcmd = CloudConfigList.new(data_map: parsed_cloud_config['runcmd'], mapping_method: RunCmd.method(:from_map))

      return new(write_files: write_files, runcmd: runcmd)
    end

    def exec
      instance_variables.each do |var|
        cloudconfig_directive = instance_variable_get(var)
        if !cloudconfig_directive.respond_to?(:exec)
          #TODO: Not implemented exception?
          return
        end
        cloudconfig_directive.exec
      end
    end

    class CloudConfig::CloudConfigList
        attr_accessor :cloud_config_list

        def initialize(data_map:, mapping_method:)
          @cloud_config_list = data_map.map do |element|
            #TODO: validate
            mapping_method.call(element)
          end
        end

        def validate
          # TODO
        end

        def exec
            @cloud_config_list.each do |element|
              if !element.respond_to?(:exec)
                #TODO: Not implemented exception?
                return
              end
              element.exec
            end
        end
    end

    class CloudConfig::WriteFile
      attr_accessor :path, :owner, :permissions, :content
  
      def initialize(path:, owner:, permissions:, content:)
        @path = path
        @owner = owner
        @permissions = permissions
        @content = content
      end
  
      def validate
        #TODO
      end

      def exec
        #TODO
        Logger.info("[writeFile] writing file #{@owner}-#{@permissions}@#{@path}:")
      end

      def self.from_map(data_map)
        #TODO: Validate
        WriteFile.new(
              path: data_map['path'],
              owner: data_map['owner'],
              permissions: data_map['permissions'],
              content: data_map['content']
            )
      end
    end

    class CloudConfig::RunCmd
      attr_accessor :cmd
  
      def initialize(cmd)
        @cmd = cmd
      end
  
      def validate
        #TODO
      end

      def exec
        #TODO
        Logger.info("[runCmd] executing #{@cmd}")
      end

      def self.from_map(data_map)
        #TODO: Validate
        RunCmd.new(data_map)
      end
      
    end

  end
end

# script start
begin
cloud_config = CloudInit.load_cloud_config_from_user_data()
rescue Exception => e
  CloudInit::Logger.fatal("could not parse USER_DATA: #{e.message}")
  exit 1
end

if cloud_config.nil?
  exit 0
end

begin
  cloud_config.exec()
rescue Exception => e
  CloudInit::Logger.fatal("error executing cloud-config: #{e.message}")
  exit 1
end