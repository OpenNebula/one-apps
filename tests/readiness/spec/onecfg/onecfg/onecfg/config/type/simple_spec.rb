require 'tmpdir'
require 'tempfile'
require 'fileutils'

RSpec.describe 'Class OneCfg::Config::Type::Simple' do

    it_behaves_like 'OneCfg::Config::Type::Base', 0..1, [:load, :diff] do
        let(:obj) do
            fn = one_file_fixture('config/type/simple/10-name.sh-5.6')
            FileUtils.cp(fn, @tmp.path)
            OneCfg::Config::Type::Simple.new(@tmp.path)
        end

        let(:obj2) do
            fn = one_file_fixture('config/type/simple/10-name.sh-5.8')
            FileUtils.cp(fn, @tmp.path)
            OneCfg::Config::Type::Simple.new(@tmp.path)
        end
    end

    # Loads empty file, expects success and non-nil content
    it 'loads empty file' do
        fn = one_file_fixture('config/type/simple/empty')

        cfg = OneCfg::Config::Type::Simple.new(fn)
        expect(cfg.exist?).to be true
        expect { cfg.load }.not_to raise_error(Exception)
        expect(cfg.content).not_to be_nil
    end

    ##################################################################
    # Comparisons (same, similar)
    ##################################################################

    # Compares same && similar configuration files with top level Hash
    context 'compares as same and similar' do
        it_behaves_like 'comparable configs',
                        OneCfg::Config::Type::Simple,
                        String,
                        one_file_fixtures('config/type/simple/same', 2),
                        true,  # same
                        true   # similar
    end

    # Compares completely different files (NOT same, NOT similar)
    context 'compares as not same and not similar' do
        it_behaves_like 'comparable configs',
                        OneCfg::Config::Type::Simple,
                        String,
                        one_file_fixtures('config/type/simple/not_similar'),
                        false,
                        false
    end

    ##################################################################
    # Automatic upgrading (diff / patch)
    ##################################################################

    # for automatic diff/patching, we reuse examples of oned.conf
    context 'automatically upgrades oned.conf all permutations' do
        it_behaves_like 'automatically upgradable configs',
                        OneCfg::Config::Type::Simple,
                        String,
                        one_file_fixtures('config/type/augeas/one/auto_diff_patch/oned.conf'),
                        true   # permutations
    end

    ##################################################################
    # Various patch modes (dummy, skip, force)
    ##################################################################

    context 'patch modes' do
        SIMPLE_PATCH_EXAMPLES = [{
            :name  => 'unspecified mode',
            :mode  => [],
            :fails => nil,
            :files => {
                :old      => 'config/type/simple/patch_modes/kvmrc-2.2',
                :new      => 'config/type/simple/patch_modes/kvmrc-5.8.0',
                :dist_old => 'config/type/simple/patch_modes/kvmrc-2.2',
                :dist_new => 'config/type/simple/patch_modes/kvmrc-5.8.0'
            }
        }, {
            :name  => 'mode :dummy',
            :mode  => [:dummy],
            :fails => nil,
            :files => {
                :old      => 'config/type/simple/patch_modes/kvmrc-2.2',
                :new      => 'config/type/simple/patch_modes/kvmrc-2.2',
                :dist_old => 'config/type/simple/patch_modes/kvmrc-2.2',
                :dist_new => 'config/type/simple/patch_modes/kvmrc-5.8.0'
            }
        }, {
            :name  => 'mode :skip',
            :mode  => [:skip],
            :fails => OneCfg::Config::Exception::PatchException,
            :files => {
                :old      => 'config/type/simple/patch_modes/skip1-kvmrc-2.2',
                :new      => 'config/type/simple/patch_modes/skip1-kvmrc-5.8.0',
                :dist_old => 'config/type/simple/patch_modes/kvmrc-2.2',
                :dist_new => 'config/type/simple/patch_modes/kvmrc-5.8.0'
            }
        }]

        it_behaves_like 'patch modes',
                        OneCfg::Config::Type::Simple,
                        SIMPLE_PATCH_EXAMPLES
    end

    ##################################################################
    # Manual upgrading
    ##################################################################

    SIMPLE_FILES = [{
        :diff   => '10-name.sh-diff',
        :fails  => false,
        :files  => {
            :old        => '10-name.sh-custom-5.6',
            :new        => '10-name.sh-custom-5.8',
            :dist_old   => '10-name.sh-5.6',
            :dist_new   => '10-name.sh-5.8'
        }
    }, {
        :diff   => '11-OpenNebulaNetwork.conf-diff',
        :fails  => false,
        :files  => {
            :old        => '11-OpenNebulaNetwork.conf-custom-5.0',
            :new        => '11-OpenNebulaNetwork.conf-custom-5.8',
            :dist_old   => '11-OpenNebulaNetwork.conf-5.0',
            :dist_new   => '11-OpenNebulaNetwork.conf-5.8'
        }
    }, {
        :diff   => '12-sunstone-server.rb-diff',
        :fails  => true,
        :files  => {
            :old        => '12-sunstone-server.rb-custom-5.0',
            :new        => '12-sunstone-server.rb-custom-5.8',
            :dist_old   => '12-sunstone-server.rb-5.0',
            :dist_new   => '12-sunstone-server.rb-5.8'
        }
    }]

    context 'patches files' do
        SIMPLE_FILES.each do |spec|
            context spec[:files][:old] do
                before(:all) do
                    spec[:data] = {}
                end

                it 'loads' do
                    spec[:files].each do |type, path|
                        fn = one_file_fixture("config/type/simple/#{path}")
                        cfg = OneCfg::Config::Type::Simple.new(fn)
                        spec[:files][type] = cfg

                        expect{ cfg.load }.not_to raise_error(Exception)
                        expect(cfg.content).not_to be_nil
                        expect(cfg.content).not_to be_empty
                    end
                end

                it 'checks files are not same' do
                    spec[:files].values.combination(2).to_a.each do |c|
                        expect(c[0].same?(c[1])).to be false
                    end
                end

                it 'generates diff' do
                    diff = spec[:files][:dist_old].diff(spec[:files][:old])
                    spec[:data][:diff] = diff
                    expect(diff).to be_a(Array)
                    expect(diff.length).to eq(1)

                    if spec.key?(:diff)
                        # read persisted diff
                        fn = one_file_fixture("config/type/simple/#{spec[:diff]}")
                        diff_spec = File.read(fn)

                        expect(diff[0]['value']).to eq(diff_spec)
                    end
                end

                if spec[:fails]
                    it 'fails to patch new stock' do
                        expect do
                            spec[:files][:dist_new].patch(spec[:data][:diff])
                        end.to raise_error(Exception)

                        same = spec[:files][:dist_new].same?(spec[:files][:new])
                        expect(same).to be false
                    end
                else
                    it 'patches new stock' do
                        expect do
                            spec[:files][:dist_new].patch(spec[:data][:diff])
                        end.not_to raise_error(Exception)

                        same = spec[:files][:dist_new].same?(spec[:files][:new])
                        expect(same).to be true
                    end

                    it 'saves and reloads new patched stock' do
                        Tempfile.open('rspec') do |tmp|
                            tmp.close

                            # saves and loads new patched stock
                            spec[:files][:dist_new].save(tmp.path)
                            cfg = OneCfg::Config::Type::Simple.new(tmp.path)
                            expect { cfg.load }.not_to raise_error(Exception)

                            # compares
                            same = spec[:files][:new].same?(cfg)
                            expect(same).to be true
                        end
                    end
                end

                it 'patches old stock' do
                    expect do
                        spec[:files][:dist_old].patch(spec[:data][:diff])
                    end.not_to raise_error(Exception)

                    same = spec[:files][:old].same?(spec[:files][:dist_old])
                    expect(same).to be true
                end

                it 'saves and reloads old patched stock' do
                    Tempfile.open('rspec') do |tmp|
                        tmp.close

                        # saves and loads new patched stock
                        spec[:files][:dist_old].save(tmp.path)
                        cfg = OneCfg::Config::Type::Simple.new(tmp.path)
                        expect { cfg.load }.not_to raise_error(Exception)

                        # compares
                        same = spec[:files][:old].same?(cfg)
                        expect(same).to be true
                    end
                end
            end
        end
    end
end
