# frozen_string_literal: true

require_relative '../../../vrouter.rb'

# Specs provoke warnings and errors on purpose; keep the appliance loggers quiet
# so the test output stays readable. Specs that assert on logging stub `msg`.
[LOGGER_STDOUT, LOGGER_STDERR].each { |logger| logger.level = Logger::UNKNOWN + 1 }
