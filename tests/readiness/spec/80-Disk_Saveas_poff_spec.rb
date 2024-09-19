require 'init'
require 'lib/DiskSaveas'

describe "Disk Saveas" do
    livesnap = false
    it_behaves_like "DiskSaveas", livesnap
end
