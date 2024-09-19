require 'init'
require 'lib/DiskSnapshots'

describe "Disk Snapshots" do
    livesnap = false
    it_behaves_like "DiskSnapshots", livesnap
end
