require 'init_functionality'
require_relative '../fsck'

RSpec.describe 'Check quotas fsck' do
    it_behaves_like 'fsck', 'one.db.quotas', 6, 0
end
