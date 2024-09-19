require 'open3'

RSpec.describe 'Tool onecfg init' do
    context 'with OpenNebula' do
        context 'automatic' do
            include_examples 'mock oned', '5.6.80', true
        end

        context 'with version override' do
            include_examples 'mock oned', '5.10.0'

            it 'initializes' do
                o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg init --to 5.6.80 2>&1")
                expect(s.success?).to eq(true)

                o, _s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg status 2>&1")
                match_onecfg_status(o, '5.10.0', '5.6.80')
            end

            it "doesn't reinitialize" do
                o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg init --to 5.6.90 2>&1")
                expect(s.success?).to eq(true)

                o, _s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg status 2>&1")
                match_onecfg_status(o, '5.10.0', '5.6.80')
            end

            it 'initializes forcibly' do
                o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg init --to 5.6.90 --force 2>&1")
                expect(s.success?).to eq(true)

                o, _s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg status 2>&1")
                match_onecfg_status(o, '5.10.0', '5.6.90')
            end

            it "doesn't reinitialize (without version)" do
                o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg init 2>&1")
                expect(s.success?).to eq(true)

                o, _s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg status 2>&1")
                match_onecfg_status(o, '5.10.0', '5.6.90')
            end

            it 'initializes forcibly (without version)' do
                o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg init --force 2>&1")
                expect(s.success?).to eq(true)

                o, _s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg status 2>&1")
                match_onecfg_status(o, '5.10.0', '5.10.0')
            end
        end
    end

    context 'without OpenNebula' do
        context 'automatic' do
            include_examples 'mock oned'

            it 'fails to initialize' do
                o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg init 2>&1")
                expect(s.success?).to eq(false)
            end
        end

        context 'with version override' do
            include_examples 'mock oned'

            it 'initializes' do
                o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg init --to 5.6.80 2>&1")
                expect(s.success?).to eq(true)

                o, _s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg status 2>&1")
                match_onecfg_status(o, nil, '5.6.80')
            end
        end
    end
end
