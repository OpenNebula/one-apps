require 'init_functionality'
require_relative '../fsck'

RSpec.describe 'Check VMs fsck' do
    it_behaves_like 'fsck', 'one.db.vm', 12, 2
end
