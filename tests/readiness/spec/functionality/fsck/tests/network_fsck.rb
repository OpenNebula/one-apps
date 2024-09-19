require 'init_functionality'
require_relative '../fsck'

RSpec.describe 'Check network fsck' do
    it_behaves_like 'fsck', 'one.db.network', 5, 1
end
