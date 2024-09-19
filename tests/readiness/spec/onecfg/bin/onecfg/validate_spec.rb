require 'open3'

RSpec.describe 'Tool onecfg - validate' do
    it 'validates' do
        Dir["#{RSPEC_ROOT}/bin/upgrade/stock_files/*"].each do |prefix|
            o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg validate " \
                                  "--prefix #{prefix} " \
                                  '--verbose 2>&1')

            expect(o.lines.size).to be > 15, 'Expected at least 15 files'
            expect(s.success?).to eq(true), "Failed on #{prefix}: #{o}"
        end
    end
end
