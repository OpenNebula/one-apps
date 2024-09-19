require 'init'
require 'lib/DiskSnapshots'

describe "Disk Snapshots" do
    livesnap = true
    it_behaves_like "DiskSnapshots", livesnap
end
