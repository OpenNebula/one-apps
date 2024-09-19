RSpec.describe 'Tool onecfg' do
    it 'is available' do
        cmd = "#{OneCfg::BIN_DIR}/onecfg"
        expect(File.file?(cmd)).to eq(true)
    end

    it 'runs' do
        o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg 2>&1")
        expect(s.success?).to eq(true)
        expect(o).to include('## COMMANDS')
    end

    it 'has subcommands' do
        %w[generate init upgrade status validate upgrade diff patch].each do |subc|
            _o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg " \
                                   "#{subc} --help 2>&1")

            expect(s.success?).to eq(true), "Missing subcommand #{subc}"
        end
    end
end
