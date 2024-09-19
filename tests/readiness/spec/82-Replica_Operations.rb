require 'init'
require 'lib/ReplicaOps'

RSpec.describe "Replica Operations (non persistent image)" do
    include_examples "replica_ops", false
end

RSpec.describe "Replica Operations (persistent image)" do
    include_examples "replica_ops", true
end
