require 'init_functionality'
require_relative '../fsck'

RSpec.describe 'Check host fsck' do
    it_behaves_like 'fsck', 'one.db.host', 6, 0
end
