require 'init'
require 'lib_lxd/DiskSaveas'

describe "Disk Saveas" do
    livesnap = false
    it_behaves_like "DiskSaveas", livesnap
end
