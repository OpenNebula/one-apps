require 'init_functionality'
require_relative '../fsck'

RSpec.describe 'Check history fsck' do
    it_behaves_like 'fsck', 'one.db.history', 3, 1
end
