require 'init_functionality'
require_relative '../fsck'

RSpec.describe 'Check users fsck' do
    it_behaves_like 'fsck', 'one.db.users', 6, 0
end
