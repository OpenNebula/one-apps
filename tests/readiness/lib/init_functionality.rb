#!/usr/bin/env ruby

ROOT_DIR = File.realpath(File.join(__FILE__,'../..')) #readiness path
LIB_DIR  = ROOT_DIR + '/lib'

MAIN_DEFAULTS_YAML = ENV['DEFAULTS'] || ROOT_DIR + '/defaults.yaml'
DEFAULTS_YAML = ROOT_DIR + '/spec/functionality/conf/defaults.yaml'

ONE_LOCATION = ENV['ONE_LOCATION'] if !defined?(ONE_LOCATION)

if !ONE_LOCATION
    ONE_LIB_LOCATION = '/usr/lib/one'
    ONE_VAR_LOCATION = '/var/lib/one'
    ONE_RUN_LOCATION = '/var/run/one'
    ONE_LOG_LOCATION = '/var/log/one'
    ONE_ETC_LOCATION = '/etc/one'
    ONE_DB_LOCATION  = ONE_VAR_LOCATION
    GEMS_LOCATION    = '/usr/share/one/gems' unless defined?(GEMS_LOCATION)
else
    ONE_LIB_LOCATION = ONE_LOCATION + '/lib'
    ONE_VAR_LOCATION = ONE_LOCATION + '/var'
    ONE_RUN_LOCATION = ONE_LOCATION + '/run'
    ONE_LOG_LOCATION = ONE_VAR_LOCATION
    ONE_ETC_LOCATION = ONE_LOCATION + '/etc'
    ONE_DB_LOCATION  = ONE_VAR_LOCATION
    GEMS_LOCATION    = ONE_LOCATION + '/share/gems' unless defined?(GEMS_LOCATION)
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
$LOAD_PATH << ONE_LIB_LOCATION + '/ruby'

require 'yaml'
require 'rspec'
require 'pp'
require 'fileutils'
require 'tempfile'

# Load pry if available (useful for debugging)
begin
    require 'pry'
rescue LoadError
end

require 'opennebula'

require 'CLITester'
require 'SafeExec'

require 'opennebula_test'

require 'VM'
require 'host'

include OpenNebula
include CLITester

#This configuration starts OpenNebula based on a defaults yaml file. See
#OpenNebulaTest class for the parameters supported to configure the class
#behavior

def is_distro?(distro_name)
    if system('command -v lsb_release')
        IO.popen("lsb_release -d") {|lsb_io|
            distro = lsb_io.read
            if distro.include? "#{distro_name}"
                return true
            end
        }
    elsif File.exist?('/etc/os-release')
        distro = File.readlines('/etc/os-release').select do |line|
            line =~ /PRETTY_NAME/
        end.first

        if distro.include? "#{distro_name}"
            return true
        end
    else
        puts "Can't detect distro"
        return nil
    end

    return false
end

RSpec.configure do |c|
    c.add_setting :main_defaults
    c.add_setting :defaults
    c.add_setting :one_test
    c.add_setting :client

    c.filter_run_excluding :type => 'skip' if is_distro? "Ubuntu 16.10"

    c.before(:all) do |e|
        main_defaults_yaml = @main_defaults_yaml || MAIN_DEFAULTS_YAML
        defaults_yaml = @defaults_yaml || DEFAULTS_YAML

        begin
            c.main_defaults = YAML.load_file(main_defaults_yaml)
            c.defaults = YAML.load_file(defaults_yaml)
            c.one_test = OpenNebulaTest.new(c.defaults)
            c.client   = OpenNebula::Client.new
        rescue Exception => e
            STDERR.puts "Can't load default files: #{e.message}"
            exit -1
        end

        @main_defaults = c.main_defaults
        @defaults = c.defaults
        @one_test = c.one_test
        @client   = c.client

        @one_test.stop_one(false)

        @one_test.clean_db
        @one_test.clean_var
        @one_test.set_conf

        expect(@one_test.start_one).to be_truthy

        STDOUT.puts "==> Testing..."
    end

    c.after(:all) do |e|
        @one_test.stop_one
    end
end
