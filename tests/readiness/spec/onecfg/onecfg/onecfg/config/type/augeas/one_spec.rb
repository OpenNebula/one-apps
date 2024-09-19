require 'rspec'
require 'tempfile'

RSpec.describe 'Class OneCfg::Config::Type::Augeas::ONE' do
    it_behaves_like 'OneCfg::Config::Type::Base', 0..1, [:load, :diff] do
        let(:obj) do
            fn = one_file_fixture('config/type/augeas/one/upgrade/01-oned.conf-5.4')
            FileUtils.cp(fn, @tmp.path)
            OneCfg::Config::Type::Augeas::ONE.new(@tmp.path)
        end

        let(:obj2) do
            fn = one_file_fixture('config/type/augeas/one/upgrade/01-oned.conf-5.8')
            FileUtils.cp(fn, @tmp.path)
            OneCfg::Config::Type::Augeas::ONE.new(@tmp.path)
        end
    end

    # Loads empty file, expects success and non-nil content
    it 'loads empty file' do
        fn = one_file_fixture('config/type/augeas/one/empty')

        cfg = OneCfg::Config::Type::Augeas::ONE.new(fn)
        expect(cfg.exist?).to be true
        expect { cfg.load }.not_to raise_error(Exception)
        expect(cfg.content).not_to be_nil
    end

    # Tries to load invalid files (wrong syntax, ...)
    # and expects all of them to fail.
    context 'loads invalid files' do
        it_behaves_like 'invalid configs',
                        OneCfg::Config::Type::Augeas::ONE,
                        one_file_fixtures('config/type/augeas/one/invalid/')
    end

    ##################################################################
    # Comparisons (same, similar)
    ##################################################################

    # Compares same && similar configuration files with top level Augeas
    context 'compares as not same, but similar' do
        it_behaves_like 'comparable configs',
                        OneCfg::Config::Type::Augeas::ONE,
                        Augeas,
                        one_file_fixtures('config/type/augeas/one/similar'),
                        false, # same
                        true   # similar
    end

    context 'compares as not same and not similar' do
        it_behaves_like 'comparable configs',
                        OneCfg::Config::Type::Augeas::ONE,
                        Augeas,
                        one_file_fixtures('config/type/augeas/one/not_similar'),
                        false, # same
                        false  # similar
    end

    ##################################################################
    # Automatic upgrading (diff / patch)
    ##################################################################

    # TODO: leave only slow tests below
    context 'automatically upgrades oned.conf consecutive only' do
        it_behaves_like 'automatically upgradable configs',
                        OneCfg::Config::Type::Augeas::ONE,
                        Augeas,
                        one_file_fixtures('config/type/augeas/one/auto_diff_patch/oned.conf'),
                        false  # permutations
    end

    context 'automatically upgrades oned.conf all permutations (slow)', :slow do
        it_behaves_like 'automatically upgradable configs',
                        OneCfg::Config::Type::Augeas::ONE,
                        Augeas,
                        one_file_fixtures('config/type/augeas/one/auto_diff_patch/oned.conf'),
                        true   # permutations
    end

    context 'automatically upgrades all permutations' do
        ['sched.conf', 'vmm_exec_kvm.conf'].each do |f|
            context f do
                it_behaves_like 'automatically upgradable configs',
                                OneCfg::Config::Type::Augeas::ONE,
                                Augeas,
                                one_file_fixtures("config/type/augeas/one/auto_diff_patch/#{f}"),
                                true # permutations
            end
        end
    end

    ##################################################################
    # Various patch modes (dummy, skip, force)
    ##################################################################

    context 'patch modes' do
        AUGEAS_ONE_PATCH_EXAMPLES = [{
            :name  => 'unspecified mode (test 1)',
            :mode  => [],
            :fails => nil,
            :files => {
                :old      => 'config/type/augeas/one/patch_modes/oned.conf-5.0',
                :new      => 'config/type/augeas/one/patch_modes/oned.conf-5.8.0',
                :dist_old => 'config/type/augeas/one/patch_modes/oned.conf-5.0',
                :dist_new => 'config/type/augeas/one/patch_modes/oned.conf-5.8.0'
            }
        }, {
            :name  => 'unspecified mode (test 2)',
            :mode  => [],
            :fails => nil,
            :files => {
                :old      => 'config/type/augeas/one/patch_modes/nil1-oned.conf-5.0',
                :new      => 'config/type/augeas/one/patch_modes/nil1-oned.conf-5.8.0',
                :dist_old => 'config/type/augeas/one/patch_modes/oned.conf-5.0',
                :dist_new => 'config/type/augeas/one/patch_modes/oned.conf-5.8.0'
            }
        }, {
            :name  => 'mode :dummy',
            :mode  => [:dummy],
            :fails => nil,
            :files => {
                :old      => 'config/type/augeas/one/patch_modes/oned.conf-5.0',
                :new      => 'config/type/augeas/one/patch_modes/oned.conf-5.0',
                :dist_old => 'config/type/augeas/one/patch_modes/oned.conf-5.0',
                :dist_new => 'config/type/augeas/one/patch_modes/oned.conf-5.8.0'
            }
        }, {
            :name  => 'mode :skip (test 1)',
            :mode  => [:skip],
            :fails => OneCfg::Config::Exception::PatchPathNotFound,
            :files => {
                :old      => 'config/type/augeas/one/patch_modes/skip1-oned.conf-5.0',
                :new      => 'config/type/augeas/one/patch_modes/skip1-oned.conf-5.8.0',
                :dist_old => 'config/type/augeas/one/patch_modes/oned.conf-5.0',
                :dist_new => 'config/type/augeas/one/patch_modes/oned.conf-5.8.0'
            }
        }, {
            :name  => 'mode :skip (test 2)',
            :mode  => [:skip],
            :fails => OneCfg::Config::Exception::PatchInvalidMultiple,
            :files => {
                :old      => 'config/type/augeas/one/patch_modes/skip2-oned.conf-5.0',
                :new      => 'config/type/augeas/one/patch_modes/skip2-oned.conf-5.8.0',
                :dist_old => 'config/type/augeas/one/patch_modes/oned.conf-5.0',
                :dist_new => 'config/type/augeas/one/patch_modes/oned.conf-5.8.0'
            }
        }, {
            :name  => 'mode :replace',
            :mode  => [:replace],
            :fails => nil,
            :files => {
                :old      => 'config/type/augeas/one/patch_modes/replace1-oned.conf-5.0',
                :new      => 'config/type/augeas/one/patch_modes/replace1-oned.conf-5.8.0',
                :dist_old => 'config/type/augeas/one/patch_modes/oned.conf-5.0',
                :dist_new => 'config/type/augeas/one/patch_modes/oned.conf-5.8.0'
            }
        }, {
            :name  => 'mode :replace, :skip',
            :mode  => [:replace, :skip],
            :fails => OneCfg::Config::Exception::PatchPathNotFound,
            :files => {
                :old      => 'config/type/augeas/one/patch_modes/skip+replace1-oned.conf-5.0',
                :new      => 'config/type/augeas/one/patch_modes/skip+replace1-oned.conf-5.8.0',
                :dist_old => 'config/type/augeas/one/patch_modes/oned.conf-5.0',
                :dist_new => 'config/type/augeas/one/patch_modes/oned.conf-5.8.0'
            }
        }]

        it_behaves_like 'patch modes',
                        OneCfg::Config::Type::Augeas::ONE,
                        AUGEAS_ONE_PATCH_EXAMPLES
    end

# VH    it 'update oned.conf from 1.2 to 5.8 version' do
# VH        name  = 'config/augeas/oned_confs'
# VH        files = Dir["#{RSPEC_ROOT}/fixtures/files/onescape/#{name}/*"]
# VH
# VH        files.sort!
# VH
# VH        file_1 = files.shift
# VH        file_1 = OneCfg::Config::Augeas::ONE.new(file_1)
# VH        file_1.load
# VH
# VH        files.each do |file|
# VH            file = OneCfg::Config::Augeas::ONE.new(file)
# VH            file.load
# VH
# VH            diff = file_1.diff(file)
# VH            file_1.patch(diff)
# VH
# VH            expect(file_1.similar?(file)).to eq true
# VH        end
# VH    end


#     ##################### REVIEW #########################

#     context 'check diff' do
#         block = lambda do |cfg|
#             cfg.content.set('NEW', 'NEW')
#
#             cfg.content.set('MONITORING_INTERVAL_HOST', '90')
#         end
#
#         it_behaves_like 'diff configs',
#             OneCfg::Config::Type::Augeas::ONE,
#             one_file_fixture('config/type/augeas/one/similar/01'),
#             one_file_fixture('config/type/augeas/one/similar/02'),
#             block
#     end
#
#     context 'check patch' do
#         block = lambda do |cfg|
#             return false if cfg.content.get('LOG/DEBUG_LEVEL') != '2'
#
#             return false if cfg.content.get('MONITORING_INTERVAL')
#
#             return true
#         end
#
#         it_behaves_like 'patch configs',
#             OneCfg::Config::Type::Augeas::ONE,
#             one_file_fixture('config/type/augeas/one/upgrade/01-oned.conf-5.4'),
#             one_file_fixture('config/type/augeas/one/upgrade/01-oned.conf-custom-5.4'),
#             one_file_fixture('config/type/augeas/one/upgrade/01-oned.conf-5.8'),
#             block
#     end

#     context 'patch modes ***TODO***' do
#         it_behaves_like 'old patch modes',
#             OneCfg::Config::Type::Augeas::ONE,
#             Augeas,
#             one_file_fixture('config/type/augeas/one/patch_modes/01'),
#             one_file_fixture('config/type/augeas/one/patch_modes/02'),
#             one_file_fixtures('config/type/augeas/one/patch_modes/different')
#     end
#
#     context 'preserve changes' do
#         preserve = [ { :key => 'LOG/DEBUG_LEVEL', :value => '5'},
#                      { :key => 'PORT', :value => '2733' },
#                      { :key => 'VNC_PORTS/START', :value => '6000' },
#                      { :key => 'MONITORING_INTERVAL_HOST', :value => '300' } ]
#
#         block = lambda do |cfg, value|
#             return(false) if cfg.content.get(value[:key]) != value[:value]
#
#             true
#         end
#
#         it_behaves_like 'preserve changes',
#             OneCfg::Config::Type::Augeas::ONE,
#             Augeas,
#             one_file_fixtures('config/type/augeas/one/preserve_changes/custom'),
#             one_file_fixtures('config/type/augeas/one/preserve_changes/stock'),
#             one_file_fixtures('config/type/augeas/one/preserve_changes/target'),
#             preserve,
#             block
#     end

end
