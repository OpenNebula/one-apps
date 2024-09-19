#!/usr/bin/env ruby

ROOT_DIR = File.dirname(__FILE__)

ONE_LOCATION = ENV['ONE_LOCATION'] unless defined?(ONE_LOCATION)

if !ONE_LOCATION
    GEMS_LOCATION     = '/usr/share/one/gems'
    GEMS_BIN_LOCATION = '/usr/share/one/gems/bin'
else
    GEMS_LOCATION     = ONE_LOCATION + '/share/gems'
    GEMS_BIN_LOCATION = ONE_LOCATION + '/share/gems/bin'
end

if File.directory?(GEMS_LOCATION)
    real_gems_path = File.realpath(GEMS_LOCATION)
    if !defined?(Gem) || Gem.path != [real_gems_path]
        $LOAD_PATH.reject! {|l| l =~ /vendor_ruby/ }
        require 'rubygems'
        Gem.use_paths(real_gems_path)
    end

    # external rspec command must know where to
    # look for custom gems path
    ENV['GEM_PATH'] = GEMS_LOCATION
    ENV['GEM_HOME'] = GEMS_LOCATION
end

if File.directory?(GEMS_BIN_LOCATION)
    ENV['PATH'] = "#{ENV['PATH']}:#{GEMS_BIN_LOCATION}"
end

require 'getoptlong'
require 'yaml'

USAGE = <<~EOF
    Usage: #{$0} --microenv <microenv> [--format <format>] [--output <output>] [--defaults <defaults>]

    Options:

        --microenv    Yaml file with a array of tests (or globs) to be tested.
        --format      Choose a formatter. Defaults to h[tml].
        --output      Write output to a file. Defaults to 'results.html'
        --defaults    Defaults file for the readiness tests.

EOF

opts = GetoptLong.new(
    ['--microenv', GetoptLong::REQUIRED_ARGUMENT],
    ['--format',    GetoptLong::REQUIRED_ARGUMENT],
    ['--output',    GetoptLong::REQUIRED_ARGUMENT],
    ['--fail-fast', GetoptLong::NO_ARGUMENT],
    ['--defaults',  GetoptLong::REQUIRED_ARGUMENT]
)

microenv_file = '../tests.yaml'
defaults      = '/var/lib/one/defaults.yaml'
format        = 'h'
output        = 'results.html'
fail_fast     = nil

opts.each do |opt, arg|
    case opt
    when '--microenv'
        microenv_file = arg
    when '--defaults'
        defaults = arg
    when '--output'
        if output.is_a? Array
            output << arg
        else
            output = [arg]
        end
    when '--fail-fast'
        fail_fast = '--fail-fast'
    when '--format'
        if format.is_a? Array
            format << arg
        else
            format = [arg]
        end
    end
end

microenv = YAML.load_file microenv_file

if !microenv.instance_of?(Array)
    STDERR.puts 'Error: Incorrect format of the microenv yaml file. It should be an array.'
    exit 1
end

tests = []
exclude_tests = []
microenv.each do |t|
    if t.match(/^exclude: (.*)/)
        ex_ts = Dir[File.join(ROOT_DIR, 'spec', Regexp.last_match(1))].sort
        exclude_tests += ex_ts
    else
        ts = Dir[File.join(ROOT_DIR, 'spec', t.to_s)].sort
        tests += ts
    end
end

tests -= exclude_tests

if tests.empty?
    STDERR.puts 'Error: no tests found'
    exit 1
end

env = {}
env['DEFAULTS'] = defaults if defaults

# check if number of formats and outputs equal
formats = [format].flatten
outputs = [output].flatten
if formats.size != outputs.size
    STDERR.puts 'Error: Number of formats and outputs is not same'
    exit 1
end

# build command
cmd = "rspec #{fail_fast}"
formats.zip(outputs).each do |f, o|
    cmd << " -f #{f} -o '#{o}'"
end
cmd << " #{tests.join(' ')} -f d"

system(env, cmd)

# Fail gracefully if exitstatus is nil (ie on OOM kill)
rc = !$?.exitstatus.nil? ? $?.exitstatus : -1

exit rc
