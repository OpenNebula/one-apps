require 'rspec'
require 'json'

# Fix error: (invalid byte sequence in US-ASCII)
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

passed_tests = false
dir_tests = "./spec/fireedge"
nvm_location = "/var/lib/one/.nvm/nvm.sh"
node_version_alias = "node_cypress"
test_script = "./run_tests_apache"
cypress_result_file = './cypress/results/merge-results.json'

command = ". #{nvm_location} && nvm use #{node_version_alias} && #{test_script}"

max_time = 1 * 60 # Time in seconds
initial_time = Time.now
messages = {
  "not_found" => 'Skipped for not finding the results of cypress',
  "not_pass" => 'Skiped by mistake when running cypress'
}

def validate_json(json, key)
  result = json[key]
  if result.is_a?(Array) && !result.empty?
    return result
  end
end


def print_its(suite)
  tests = validate_json(suite, 'tests')
  if !tests.nil?
    tests.each do |test|
      it "#{test["fullTitle"]}" do
        pending "#{test["err"]["message"]}" if test["pending"]
        fail "#{test["err"]["message"]}" if test["fail"]
      end
    end
  end
end


RSpec.describe 'Apache FireEdge', :type => 'skip' do

  Dir.chdir(dir_tests) {
    out = `#{command}`
    passed_tests = out.include? "  (Run Finished)"

    while !File.exist?(cypress_result_file) && (Time.now - initial_time) < max_time
      sleep 1  # Pause execution for 1 second
    end

    if !passed_tests || !File.exist?(cypress_result_file)
      it "Frontend Tests" do
        pending(passed_tests ? messages["not_pass"] : messages["not_found"]) 
      end
      return
    end

    json_file = File.read(cypress_result_file)
    results_data = JSON.parse(json_file)

    results = validate_json(results_data,'results')
    if !results.nil?
      results.each do |result|
        suites = validate_json(result, 'suites')
        if !suites.nil?
          suites.each do |suite|
            print_its(suite)

            # This prints the content inside suites, this happens when there is more than one nested cypress test
            internal_suites = validate_json(suite, 'suites')
            if !internal_suites.nil?
              internal_suites.each do |internal_suite|
                if !internal_suite.nil?
                  print_its(internal_suite)
                end
              end
            end
          end
        end
      end
    end
  }
end
