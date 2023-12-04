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

# Class to load plugins and trigger their actions
class Appliance

    attr_reader :logger, :config_file, :config, :plugins, :plugins_dir

    def initialize(config_file, action = :run)
        @config_file = config_file
        @plugins_dir = '/opt/one-appliance/lib/one-vnf/lib/appliance/plugin'
        @logger      = Syslog::Logger.new(File.basename($PROGRAM_NAME))
        @plugins     = []

        load_config
        load_plugins if action == :run
    end

    def load_config
        @logger.debug "Loading configuration from #{@config_file}"

        f = File.read(@config_file)
        @config = JSON.parse(f)
    rescue StandardError => e
        @logger.fatal e.to_s
        raise
    end

    def save_config
        @logger.debug "Saving configuration to #{@config_file}"

        File.open(@config_file, "w") do |f|
            f.puts JSON.pretty_generate(@config)
        end
    rescue StandardError => e
        @logger.fatal e.to_s
        raise
    end

    def get_plugin(name)
        if @config.key?(name)
            return @config[name]['enabled']
        end
        return false
    end

    def set_plugin(name, state)
        if @config.key?(name)
            @config[name]['enabled'] = state
            return true
        end
        return false
    end

    def run
        @logger.info('Entering plugins execution loop')

        while sleep 1
            @plugins.each do |plugin|
                next unless plugin.ready?

                begin
                    plugin.run
                rescue StandardError => e
                    msg = "Plugin #{plugin.name} run error - #{e.message}"
                    @logger.error msg
                    STDERR.puts msg
                    e.backtrace.each do |line|
                        @logger.error line
                        STDERR.puts line
                    end
                end
            end
        end
    end

    def reconfigure
        @logger.info('Reconfiguring plugins')

        load_config

        @plugins.each do |plugin|
            was_enabled = plugin.enabled

            # reconfigure and cleanup if disabled
            plugin.configure(@config)
            plugin.cleanup if was_enabled && !plugin.enabled
        end
    end

    def cleanup
        @logger.info('Cleaning up plugins')

        @plugins.each do |plugin|
            next unless plugin.enabled

            plugin.cleanup
        end
    end

    private

    def load_plugins
        # check state before loading plugins
        base_constants = Object.constants

        Dir["#{@plugins_dir}/*.rb"].sort.each do |f|
            @logger.debug("Loading code from #{f}")
            require f
        end

        # shamelessly copied from:
        # https://joshrendek.com/2013/07/a-simple-ruby-plugin-system/
        # Iterate over each symbol in the object space
        Object.constants.each do |klass|
            next if base_constants.include?(klass)

            # Get the constant from the Kernel using the symbol
            const = Kernel.const_get(klass)
            if const.respond_to?(:superclass) && (const.superclass == Appliance::Plugin)
                # @class_plugins << const
                @plugins << const.new(@config, @logger)
            end
        end

        raise StandardError, 'No plugins loaded' if @plugins.empty?

        @logger.info("Available plugins - #{plugins.map {|i| i.class }.join(', ')}")
    rescue StandardError => e
        msg = "Plugins load error - #{e.message}"
        @logger.fatal msg
        STDERR.puts msg
        e.backtrace.each do |line|
            @logger.fatal line
            STDERR.puts line
        end
        raise
    end

end
