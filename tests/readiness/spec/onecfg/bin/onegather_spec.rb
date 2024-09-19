require 'init'

RSpec.describe 'Tool onegather' do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        if @defaults && @defaults[:build_components]
            @ee = @defaults[:build_components].include?('enterprise')
        else
            @ee = false
        end

        skip 'only for EE' unless @ee
    end

    it 'is available' do
        cmd = "#{OneCfg::BIN_DIR}/onegather"
        expect(File.file?(cmd)).to eq(true)
    end

    it 'runs (simple)' do
        o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onegather --help 2>&1")
        expect(s.success?).to eq(true)
    end
end
