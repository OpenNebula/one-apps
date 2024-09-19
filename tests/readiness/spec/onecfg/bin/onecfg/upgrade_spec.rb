require 'open3'
require 'tmpdir'
require 'fileutils'

# TODO: this is a terrible part
RSpec.shared_examples_for 'onecfg upgrade' do |base_dir,
                                               options: '',
                                               read_from: false,
                                               enforce_versions: true,
                                               dummy: false,
                                               block: nil|
    # Get all versions
    @versions = Dir["#{base_dir}/**"].map do |f|
        Gem::Version.new(f.split('/')[-1])
    end

    @versions.sort!
    f = OneCfg::Config::Files.new

    @versions.combination(2).to_a.each do |v1, v2|

        it "upgrades combination from #{v1} to #{v2}" do

            Dir.mktmpdir do |tmpdir|
                # copy source version files into tmpdir, proceed with upgrade
                # and compare the result with files for target version
                v1_tree = "#{base_dir}/#{v1}"
                v2_tree = "#{base_dir}/#{v2}"

                cmd = "#{OneCfg::BIN_DIR}/onecfg upgrade " \
                      '--unprivileged ' \
                      '--debug ' \
                      "--prefix '#{tmpdir}' " \
                      "#{options} "

                if enforce_versions
                    cmd << "--from #{v1} "
                    cmd << "--to   #{v2} "
                end

                if read_from
                    # fake some structure, so that backups don't fail
                    FileUtils.mkdir_p("#{tmpdir}/etc/one")
                    FileUtils.mkdir_p("#{tmpdir}/var/lib/one/remotes")
                    cmd << " --read-from '#{v1_tree}'"
                else
                    FileUtils.cp_r("#{v1_tree}/.", tmpdir)
                end

                # upgrade
                o, s = Open3.capture2("#{cmd} 2>&1")

                expect(s.success?).to eq(true),
                                      "Failed upgrade from #{v1} to #{v2}. " \
                                      "Command output: #{o}"

                # validate version has changed
                o, _s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg status 2>&1")

                # read all known upgraded files and compare with v2 tree
                v1_files = f.scan(tmpdir, false)

                if dummy
                    # TODO: relies on external initialization
                    expect(o).to match(/Config:\s*unknown/i)

                    # In dummy mode, we processed temporary tree with
                    # original source files. They must be same...
                    v2_tree  = v1_tree
                    v2_files = f.scan(v1_tree, false)
                else
                    expect(o).to match(/Config:\s*#{v2}/i)
                    v2_files = f.scan(v2_tree, false)
                end

                (v1_files.keys + v2_files.keys).uniq.each do |name|
                    # !!! EXCEPTION: we don't compare files from
                    # /var/lib/one/remotes/ which are not
                    # under 'etc'. Those are legacy ones and
                    # upgrade logic doesn't copies changes into them !!!
                    next if name.start_with?('/var/lib/one/remotes/') &&
                            !name.start_with?('/var/lib/one/remotes/etc/')

                    expect(v1_files).to have_key(name)
                    expect(v2_files).to have_key(name)

                    v1_file = v1_files[name]['ruby_class'].new(
                        OneCfg::Config::Utils.prefixed(name, tmpdir)
                    )

                    v2_file = v2_files[name]['ruby_class'].new(
                        OneCfg::Config::Utils.prefixed(name, v2_tree)
                    )

                    v1_file.load
                    v2_file.load
                    diff = v1_file.diff(v2_file)

                    # check files for similarity
                    err_msg = "Failed upgrade from #{v1} to #{v2}. " \
                              "Compared files #{v1_file.name} and " \
                              "#{v2_file.name} (class " \
                              "#{v1_files[name]['class']}) are not similar. " \
                              "Diff: #{diff}"

                    expect(v1_file.similar?(v2_file)).to eq(true), err_msg
                end

                if block
                    ret = block.call(tmpdir, v1, v2)
                    expect(ret).to eq(true), ret.to_s
                end
            end
        end
    end
end

RSpec.describe 'Tool onecfg - upgrade' do
    context 'initialize' do
        include_examples 'mock oned', '5.4.0', true
    end

    context 'with stock files' do
        include_examples 'onecfg upgrade',
                         one_file_fixture('upgrade/stock_files', 'bin/onecfg')
    end

    context 'with stock files via read-from' do
        include_examples 'onecfg upgrade',
                         one_file_fixture('upgrade/stock_files', 'bin/onecfg'),
                         read_from: true
    end

    context 'with modified files' do
        block = lambda do |dir, v1, v2|
            return true if v1 >= Gem::Version.new('5.10')

            %w[fake-hook-group fake-hook-host fake-hook-image fake-hook-user
               fake-hook-vm fake-hook-vnet fake-hook-vrouter
               refresh_dns_create-0 refresh_dns_create-1
               refresh_dns_done].each do |name|
                fn = "#{dir}/etc/one/migration-5.10.0-hooks/#{name}"
                return "Hook #{fn} not found" unless File.exist?(fn)
            end

            true
        end

        include_examples 'onecfg upgrade',
                         one_file_fixture('upgrade/modified1', 'bin/onecfg'),
                         block: block
    end

    context 'no-operation mode' do
        include_examples 'mock oned', nil

        include_examples 'onecfg upgrade',
                         one_file_fixture('upgrade/modified1', 'bin/onecfg'),
                         options: '--noop',
                         dummy: true
    end

    context 'patch modes' do
        context 'none' do
            include_examples 'onecfg upgrade',
                             one_file_fixture('upgrade/patch_modes-base', 'bin/onecfg')
        end

        context 'global defaults' do
            include_examples 'onecfg upgrade',
                             one_file_fixture('upgrade/patch_modes1', 'bin/onecfg'),
                             options: \
                                 '--patch-modes skip ' \
                                 '--patch-modes replace ' \
                                 '--patch-modes force'
        end

        context 'global defaults (single param)' do
            include_examples 'onecfg upgrade',
                             one_file_fixture('upgrade/patch_modes1', 'bin/onecfg'),
                             options: '--patch-modes skip,replace,force'
        end

        context 'per file modes' do
            include_examples 'onecfg upgrade',
                            one_file_fixture('upgrade/patch_modes1', 'bin/onecfg'),
                            options: \
                                '--patch-modes skip:/etc/one/oned.conf ' \
                                '--patch-modes skip,replace:/etc/one/oned.conf:5.10.0 ' \
                                '--patch-modes force:/etc/one/sunstone-logos.yaml:5.6.0 ' \
                                '--patch-modes replace:/etc/one/sunstone-server.conf ' \
                                '--patch-modes skip:/etc/one/sunstone-views/admin.yaml:5.4.1 ' \
                                '--patch-modes skip:/etc/one/sunstone-views/admin.yaml:5.4.2 ' \
                                '--patch-modes skip:/etc/one/sunstone-views/kvm/admin.yaml'
        end

        context 'per file modes (single param)' do
            include_examples 'onecfg upgrade',
                            one_file_fixture('upgrade/patch_modes1', 'bin/onecfg'),
                            options: \
                                '--patch-modes \'skip:/etc/one/oned.conf;' \
                                'skip,replace:/etc/one/oned.conf:5.10.0;' \
                                'force:/etc/one/sunstone-logos.yaml:5.6.0;' \
                                'replace:/etc/one/sunstone-server.conf;' \
                                'skip:/etc/one/sunstone-views/admin.yaml:5.4.1;' \
                                'skip:/etc/one/sunstone-views/admin.yaml:5.4.2;' \
                                'skip:/etc/one/sunstone-views/kvm/admin.yaml\''
        end

        context 'patch safe mode' do
            include_examples 'onecfg upgrade',
                            one_file_fixture('upgrade/patch_modes2', 'bin/onecfg'),
                            options: \
                                '--patch-safe'
        end
    end

    context 'automatically by new OpenNebula version' do
        AUTO_UPGRADE_FROM = '5.4.0'
        AUTO_UPGRADE_TO   = '5.12.0'
        AUTO_UPGRADE_ONE  = '5.12.1'

        include_examples 'mock oned', AUTO_UPGRADE_ONE

        it 'initializes' do
            o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg init --to #{AUTO_UPGRADE_FROM} 2>&1")
            expect(s.success?).to eq(true), o
        end

        it 'shows status' do
            o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg status 2>&1")
            expect(s.exitstatus).to eq(1), o
            match_onecfg_status(o, AUTO_UPGRADE_ONE, AUTO_UPGRADE_FROM)
            expect(o).to match(/New config:\s*#{AUTO_UPGRADE_TO}/i)
            expect(o).to match(/^- from #{AUTO_UPGRADE_FROM}/i)
            expect(o).to match(/to #{AUTO_UPGRADE_TO}/i)
        end

        include_examples 'onecfg upgrade',
                         one_file_fixture('upgrade/modified1-auto', 'bin/onecfg'),
                         enforce_versions: false

        it 'shows status' do
            o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg status 2>&1")
            expect(s.exitstatus).to eq(0), o
            match_onecfg_status(o, AUTO_UPGRADE_ONE, AUTO_UPGRADE_TO)
            expect(o).to match(/No updates available/i)
            expect(o).not_to match(/^- from /i)
        end
    end
end
