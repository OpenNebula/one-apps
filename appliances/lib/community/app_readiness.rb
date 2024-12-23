#!/usr/bin/env ruby

ENV['RUBYOPT'] = "-W0"

require 'yaml'
require 'fileutils'

if ARGV.empty?
    STDERR.puts 'Usage: ./app_readiness.rb <app_name>'
    exit(1)
end

app = ARGV[0] # 'example'

tests_list_path = "../../#{app}/tests.yaml"
tests_path = "../../#{app}/tests"

if !File.exist? tests_list_path
    STDERR.puts "Missing test file #{tests_list_path}"
    exit(1)
end

tests_list = YAML.load_file tests_list_path

rspec_command = [
    'rspec',
    '-f d',
    "-f h -o 'results/results.html'",
    "-f d -o 'results/results.txt'",
    "-f j -o 'results/results.json'"
]

tests_list.each do |test|
    rspec_command << "#{tests_path}/#{test}"
end

system(rspec_command.join(' '))

# Fail gracefully if exitstatus is nil (ie on OOM kill)
rc = !$?.exitstatus.nil? ? $?.exitstatus : -1

exit rc
