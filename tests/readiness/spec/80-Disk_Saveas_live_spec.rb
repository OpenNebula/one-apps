require 'init'
require 'lib/DiskSaveas'

describe "Disk Saveas live" do
    livesnap = true
    it_behaves_like "DiskSaveas", livesnap
end
