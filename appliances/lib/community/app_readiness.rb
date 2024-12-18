require 'yaml'
require 'fileutils'

rspec_command = [
    'rspec',
    '-f d',
    "-f h -o 'results/results.html'",
    "-f d -o 'results/results.txt'",
    "-f j -o 'results/results.json'"
]

app = ARGV[0] # 'example'
results_path = ARGV[1] || '/tmp/results' # /var/lib/one/results

tests_list_path = "../../#{app}/tests.yaml"
tests_path = "../../#{app}/tests"

FileUtils.mkdir_p(results_path) unless Dir.exist?(results_path)

if !File.exist? tests_list_path
    STDERR.puts "Missing test file #{tests_list_path}"
    exit(1)
end

tests_list = YAML.load_file tests_list_path

tests_list.each do |test|
    rspec_command << "#{tests_path}/#{test}"
end

system(rspec_command)

# Fail gracefully if exitstatus is nil (ie on OOM kill)
rc = !$?.exitstatus.nil? ? $?.exitstatus : -1

exit rc
