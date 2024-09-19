require 'init'
require 'lib/vm_basics'

# Tests basic VM Operations

RSpec.describe "Basic VM Tasks" do

    include_examples "basic_vm_tasks", false
end

RSpec.describe "Basic VM Tasks (persistent image)" do

    @defaults = RSpec.configuration.defaults
    if @defaults[:basic_vm_task_peristent]
        include_examples "basic_vm_tasks", true
    end
end
