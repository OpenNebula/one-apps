# frozen_string_literal: true

# Loads every spec so the stock appliances/VRouter/tests.sh (rspec tests.rb) runs them all.
Dir[File.join(__dir__, 'spec', '*_spec.rb')].sort.each { |path| require path }
