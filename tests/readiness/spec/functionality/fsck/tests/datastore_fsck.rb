require 'init_functionality'
require_relative '../fsck'

RSpec.describe 'Check datastore fsck' do
    it_behaves_like 'fsck', 'one.db.datastore', 7, 1
end
