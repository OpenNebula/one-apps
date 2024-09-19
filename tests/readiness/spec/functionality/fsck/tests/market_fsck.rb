require 'init_functionality'
require_relative '../fsck'

RSpec.describe 'Check Marketplace fsck' do
    it_behaves_like 'fsck', 'one.db.market', 8, 1
end
