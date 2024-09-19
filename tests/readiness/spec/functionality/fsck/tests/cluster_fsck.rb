require 'init_functionality'
require_relative '../fsck'

RSpec.describe 'Check cluster fsck' do
    it_behaves_like 'fsck', 'one.db.cluster', 8, 0
end
