#!/usr/bin/env ruby

ROOT_DIR ||= File.realpath(File.join(__FILE__,'../..'))
LIB_DIR  ||= ROOT_DIR + '/lib'

DEFAULTS_YAML ||= ENV['DEFAULTS'] || ROOT_DIR + '/defaults.yaml'

ONE_LOCATION = ENV['ONE_LOCATION'] if !defined?(ONE_LOCATION)

if !ONE_LOCATION
    ONE_LIB_LOCATION ||= '/usr/lib/one'
    ONE_LOG_LOCATION ||= '/var/log/one'
    GEMS_LOCATION    ||= '/usr/share/one/gems' unless defined?(GEMS_LOCATION)
else
    ONE_LIB_LOCATION ||= ONE_LOCATION + '/lib'
    ONE_LOG_LOCATION ||= ONE_LOCATION + '/var'
    GEMS_LOCATION    ||= ONE_LOCATION + '/share/gems' unless defined?(GEMS_LOCATION)
end

if File.directory?(GEMS_LOCATION)
    real_gems_path = File.realpath(GEMS_LOCATION)
    if !defined?(Gem) || Gem.path != [real_gems_path]
        $LOAD_PATH.reject! {|l| l =~ /vendor_ruby/ }
        require 'rubygems'
        Gem.use_paths(real_gems_path)
    end
end

$LOAD_PATH << LIB_DIR
$LOAD_PATH << ONE_LIB_LOCATION + "/ruby"

require 'yaml'
require 'rspec'
require 'pp'
require 'rexml/document'
require 'tempfile'
require 'fileutils'

# Load pry if available (useful for debugging)
begin
    require 'pry'
rescue LoadError
end

require 'opennebula'

require 'CLITester'
require 'SafeExec'
require 'VM'
require 'zone'
require 'DSDriver'
require 'TemplateParser'
require 'TempTemplate'
require 'OneFlowService'
require 'host'

require 'fileutils'

include OpenNebula
include CLITester

def save_log_files(name)
    dir = File.join(Dir.pwd, "results")
    FileUtils.mkdir_p(dir)

    sanitized_name = name.gsub(/[\s\/'"]/, "_")
    tar_file = File.join(dir, "#{sanitized_name}.tar.bz2")

    cmd = "tar --ignore-failed-read -cjf '#{tar_file}' #{ONE_LOG_LOCATION} 2>/dev/null"
    system(cmd)
end

RSpec.configure do |c|
    c.add_setting :defaults
    c.add_setting :main_defaults
        begin
            # For vcenter-sunstone tests c.defaults is the same as c.main_defaults
            c.defaults = YAML.load_file(DEFAULTS_YAML)
            c.main_defaults = YAML.load_file(DEFAULTS_YAML)
        rescue
            STDERR.puts "Can't load defaults.yaml file. Make sure it exists."
            exit -1
        end
    c.before do |e|
        @defaults = c.defaults
        @main_defaults = c.main_defaults

        # Keep this if in the future I need specific configuration for tests
        # fp        = e.file_path.match(/\.\/spec\/(.*)\.rb/)[1]
        # test_conf = DEF[:tests].select{|t| t[:name] == fp}.first rescue nil
        # @conf.merge!(test_conf) if test_conf
    end

end
