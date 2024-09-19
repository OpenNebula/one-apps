require 'init'
require 'lib/vm_lxc_basics'

# Tests lxc basic VM Operations

RSpec.describe "Basic VM LXC Tasks" do
    include_examples "basic_vm_lxc_tasks"
end
