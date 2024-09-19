require 'open3'
require 'securerandom'

RSpec.describe 'Tool onecfg status' do
    context 'has unknown config' do
        include_examples 'mock oned', '5.6.0'

        it 'shows status and fails' do
            o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg status 2>&1")
            expect(s.success?).to eq(false)
            expect(s.exitstatus).to eq(255)
            match_onecfg_status(o, '5.6.0', nil)
        end
    end

    context 'has unsupported config' do
        include_examples 'mock oned', '5.6.0'

        it 'initializes' do
            o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg init --to 1.0.0 2>&1")
            expect(s.success?).to eq(true)
        end

        it 'shows status and fails' do
            o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg status 2>&1")
            expect(s.success?).to eq(false)
            expect(s.exitstatus).to eq(255)
            match_onecfg_status(o, '5.6.0', '1.0.0')
            expect(o).to match(/Unsupported config/i)
        end
    end

    context 'has unknown oned' do
        include_examples 'mock oned', nil

        it 'initializes' do
            o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg init --to 5.6.0 2>&1")
            expect(s.success?).to eq(true)
        end

        it 'shows status and fails' do
            o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg status 2>&1")
            expect(s.success?).to eq(false)
            expect(s.exitstatus).to eq(255)
            match_onecfg_status(o, nil, '5.6.0')
        end
    end

    context 'has unsupported oned' do
        include_examples 'mock oned', '1.0.0'

        it 'initializes' do
            o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg init --to 5.6.0 2>&1")
            expect(s.success?).to eq(true)
        end

        it 'shows status and fails' do
            o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg status 2>&1")
            expect(s.success?).to eq(false)
            expect(s.exitstatus).to eq(255)
            match_onecfg_status(o, '1.0.0', '5.6.0')
            expect(o).to match(/Unsupported OpenNebula/i)
        end
    end

    context 'has unknown oned and config' do
        include_examples 'mock oned', nil

        it 'shows status and fails' do
            o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg status 2>&1")
            expect(s.success?).to eq(false)
            expect(s.exitstatus).to eq(255)
            match_onecfg_status(o, nil, nil)
        end
    end

    STATUS_MIGR = OneCfg::EE::Config::Versions.new.migrators

    # We test various versions from the past, lock OpenNebula and
    # configuration on this version and expect the tool will not
    # offer any upgrades
    context 'shows no upgrade' do
        # Note - list.last.from version is a test case when we
        # added migrator for FROM version from the end of migrators
        # array, and ended processing. Thus, for 5.8.4 -> 5.8.5
        # migration returned 5.8.0->5.8.10 migrator.
        ['5.4.0', '5.4.4', '5.4.10', '5.6.0',
         '5.6.2', '5.8.0', '5.8.5', '5.10.0',
         STATUS_MIGR.list.first.from.to_s,
         STATUS_MIGR.list.last.from.to_s].uniq.each do |vers|
            context "versions #{vers}" do
                include_examples 'mock oned', vers, true

                it 'shows status without upgrades' do
                    o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg status 2>&1")
                    expect(s.exitstatus).to eq(0), o
                    match_onecfg_status(o, vers, vers)
                    expect(o).to match(/No updates available/i)
                    expect(o).not_to match(/^- from /i)
                end
            end
        end
    end

    # We test few OpenNebula and configuration version combinations to
    # check tool proposes some updates for them
    context 'shows upgrade' do
        [['5.4.0', '5.6.0'], ['5.4.0', '5.8.5'], ['5.4.0', '5.10.1'],
         ['5.6.0', '5.8.0'], ['5.6.1', '5.8.5'], ['5.6.2', '5.10.0'],
         ['5.8.0', '5.10.0'], ['5.8.5', '5.10.1'],
         [STATUS_MIGR.all_from.to_s, STATUS_MIGR.all_to.to_s]].each do |cfg_vers, one_vers|
            context "version #{cfg_vers} to #{one_vers}" do
                include_examples 'mock oned', one_vers

                it 'initializes' do
                    _o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg init --to #{cfg_vers} 2>&1")
                    expect(s.success?).to eq(true)
                end

                it 'shows status with upgrades' do
                    o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg status 2>&1")
                    expect(s.exitstatus).to eq(1), o
                    match_onecfg_status(o, one_vers, cfg_vers)

                    # test upgrade path only by major releases X.Y (not X.Y.Z)
                    one_vers_main = one_vers.split('.')[0..1].join('.')
                    cfg_vers_main = cfg_vers.split('.')[0..1].join('.')
                    expect(o).to match(/New config:\s*#{one_vers_main}/i)
                    expect(o).to match(/^- from #{cfg_vers_main}\./i)
                    expect(o).to match(/to #{one_vers_main}\./i)
                end
            end
        end
    end

    context 'shows outdated' do
        include_examples 'mock oned', '5.10.1'

        it 'initializes' do
            _o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg init --to 5.10.1 2>&1")
            expect(s.success?).to eq(true)

            if File.exist?(OneCfg::CONFIG_CFG)
                open(OneCfg::CONFIG_CFG, 'a') do |f|
                    f.puts('outdated: true')
                end
            end
        end

        it 'shows status and fails' do
            o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg status 2>&1")
            expect(s.exitstatus).to eq(255), o
            expect(o).to match(/ERROR.*outdated/i)
        end
    end

    context 'shows one-shot backup' do
        include_examples 'mock oned', '5.10.1'

        it 'initializes' do
            _o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg init --to 5.10.1 2>&1")
            expect(s.success?).to eq(true)

            @backup = "/tmp/onescape-#{SecureRandom.hex}"

            if File.exist?(OneCfg::CONFIG_CFG)
                open(OneCfg::CONFIG_CFG, 'a') do |f|
                    f.puts("backup: '#{@backup}'")
                end
            end
        end

        it 'shows status and fails' do
            o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg status 2>&1")
            expect(s.exitstatus).to eq(1), o
            expect(o).to match(/Backup to Process/i)
            expect(o).to match(/#{@backup}/)
            expect(o).to match(/No updates available, but update/i)
        end
    end
end
