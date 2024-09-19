require 'rspec'
require 'tempfile'

RSpec.describe 'Class OneCfg::Config::Type::Augeas::Shell' do
    it_behaves_like 'OneCfg::Config::Type::Base', 0..1, [:load, :diff] do
        let(:obj) do
            fn = one_file_fixture('config/type/augeas/shell/upgrade/01-kvmrc-5.0')
            FileUtils.cp(fn, @tmp.path)
            OneCfg::Config::Type::Augeas::Shell.new(@tmp.path)
        end

        let(:obj2) do
            fn = one_file_fixture('config/type/augeas/shell/upgrade/01-kvmrc-5.8')
            FileUtils.cp(fn, @tmp.path)
            OneCfg::Config::Type::Augeas::Shell.new(@tmp.path)
        end
    end

    # Loads empty file, expects success and non-nil content
    it 'loads empty file' do
        fn = one_file_fixture('config/type/augeas/shell/empty')

        cfg = OneCfg::Config::Type::Augeas::Shell.new(fn)
        expect(cfg.exist?).to be true
        expect{cfg.load}.not_to raise_error(Exception)
        expect(cfg.content).not_to be_nil
    end

    # Tries to load invalid files (wrong syntax, ...)
    # and expects all of them to fail.
    context 'loads invalid files' do
        it_behaves_like 'invalid configs',
                        OneCfg::Config::Type::Augeas::Shell,
                        one_file_fixtures('config/type/augeas/shell/invalid/')
    end

    # Manually upgrades file
    context 'updates file kvmrc 5.0 to 5.8' do
        block = lambda do |cfg|
            cfg.content.insert('QEMU_PROTOCOL', 'LIBVIRT_MD_KEY', false)
            cfg.content.set('LIBVIRT_MD_KEY', 'one')
            cfg.content.set('LIBVIRT_MD_KEY/export', nil)

            cfg.content.insert('QEMU_PROTOCOL', 'LIBVIRT_MD_URI', false)
            cfg.content.set('LIBVIRT_MD_URI', 'http://opennebula.org/xmlns/libvirt/1.0')
            cfg.content.set('LIBVIRT_MD_URI/export', nil)
        end

        include_examples 'upgradable configs',
                         OneCfg::Config::Type::Augeas::Shell,
                         one_file_fixture('config/type/augeas/shell/upgrade/01-kvmrc-5.0'),
                         one_file_fixture('config/type/augeas/shell/upgrade/01-kvmrc-5.8'),
                         block
    end

    ##################################################################
    # Comparisons (same, similar)
    ##################################################################

    # Compares same && similar configuration files with top level Augeas
    context 'compares as not same, but similar' do
        it_behaves_like 'comparable configs',
                        OneCfg::Config::Type::Augeas::Shell,
                        Augeas,
                        one_file_fixtures('config/type/augeas/shell/similar'),
                        false, # same
                        true   # similar
    end

    context 'compares as not same and not similar' do
        it_behaves_like 'comparable configs',
                        OneCfg::Config::Type::Augeas::Shell,
                        Augeas,
                        one_file_fixtures('config/type/augeas/shell/not_similar'),
                        false, # same
                        false  # similar
    end

    context 'automatically upgrades all permutations' do
        ['kvmrc', 'random'].each do |f|
            context f do
                it_behaves_like 'automatically upgradable configs',
                                OneCfg::Config::Type::Augeas::Shell,
                                Augeas,
                                one_file_fixtures("config/type/augeas/shell/auto_diff_patch/#{f}"),
                                true # permutations
            end
        end
    end

    ##################################################################
    # Various patch modes (dummy, skip, force)
    ##################################################################

    context 'patch modes' do
        AUGEAS_SHELL_PATCH_EXAMPLES = [{
            :name  => 'unspecified mode (test 1)',
            :mode  => [],
            :fails => nil,
            :files => {
                :old      => 'config/type/augeas/shell/patch_modes/kvmrc-2.2',
                :new      => 'config/type/augeas/shell/patch_modes/kvmrc-5.8.0',
                :dist_old => 'config/type/augeas/shell/patch_modes/kvmrc-2.2',
                :dist_new => 'config/type/augeas/shell/patch_modes/kvmrc-5.8.0'
            }
        }, {
            :name  => 'mode :dummy',
            :mode  => [:dummy],
            :fails => nil,
            :files => {
                :old      => 'config/type/augeas/shell/patch_modes/kvmrc-2.2',
                :new      => 'config/type/augeas/shell/patch_modes/kvmrc-2.2',
                :dist_old => 'config/type/augeas/shell/patch_modes/kvmrc-2.2',
                :dist_new => 'config/type/augeas/shell/patch_modes/kvmrc-5.8.0'
            }
        }, {
            :name  => 'mode :replace (test 1)',
            :mode  => [:replace],
            :fails => nil,
            :files => {
                :old      => 'config/type/augeas/shell/patch_modes/replace1-kvmrc-2.2',
                :new      => 'config/type/augeas/shell/patch_modes/replace1-kvmrc-5.8.0',
                :dist_old => 'config/type/augeas/shell/patch_modes/kvmrc-2.2',
                :dist_new => 'config/type/augeas/shell/patch_modes/kvmrc-5.8.0'
            }
        }, {
            :name  => 'mode :replace (test 2)',
            :mode  => [:replace],
            :fails => nil,
            :files => {
                :old      => 'config/type/augeas/shell/patch_modes/replace2-kvmrc-2.2',
                :new      => 'config/type/augeas/shell/patch_modes/replace2-kvmrc-5.8.0',
                :dist_old => 'config/type/augeas/shell/patch_modes/kvmrc-2.2',
                :dist_new => 'config/type/augeas/shell/patch_modes/kvmrc-5.8.0'
            }
        }, {
            :name  => 'mode :replace (test 3)',
            :mode  => [:replace],
            :fails => nil,
            :files => {
                :old      => 'config/type/augeas/shell/patch_modes/replace3-kvmrc-2.2',
                :new      => 'config/type/augeas/shell/patch_modes/replace3-kvmrc-5.8.0',
                :dist_old => 'config/type/augeas/shell/patch_modes/kvmrc-2.2',
                :dist_new => 'config/type/augeas/shell/patch_modes/kvmrc-5.8.0'
            }
        }]

        it_behaves_like 'patch modes',
                        OneCfg::Config::Type::Augeas::Shell,
                        AUGEAS_SHELL_PATCH_EXAMPLES
    end

#     ##################### REVIEW #########################

#     context 'check diff' do
#         block = lambda do |cfg|
#             cfg.content.set("NEW", "NEW")
#
#             cfg.content.set("LANG", "D")
#
#             cfg.content.set("EXPORT", "EXPORT")
#             cfg.content.set("EXPORT/export", nil)
#
#         end
#
#         it_behaves_like 'diff configs',
#             OneCfg::Config::Type::Augeas::Shell,
#             one_file_fixture('config/type/augeas/shell/similar/01'),
#             one_file_fixture('config/type/augeas/shell/similar/02'),
#             block
#     end
#
#     context 'check patch' do
#         block = lambda do |cfg|
#             return false if cfg.content.get('QEMU_PROTOCOL') != 'qemu+tcp'
#             return false if cfg.content.get('SHUTDOWN_TIMEOUT') != '60'
#
#             return true
#         end
#
#         it_behaves_like 'patch configs',
#             OneCfg::Config::Type::Augeas::Shell,
#             one_file_fixture('config/type/augeas/shell/upgrade/01-kvmrc-5.0'),
#             one_file_fixture('config/type/augeas/shell/upgrade/01-kvmrc-custom-5.0'),
#             one_file_fixture('config/type/augeas/shell/upgrade/01-kvmrc-5.8'),
#             block
#     end
#
#     it 'forced patch' do
#         c1 = one_file_fixture('config/type/augeas/shell/patch_mode/01')
#         c1 = OneCfg::Config::Type::Augeas::Shell.new(c1)
#         c2 = one_file_fixture('config/type/augeas/shell/patch_mode/02')
#         c2 = OneCfg::Config::Type::Augeas::Shell.new(c2)
#
#         c1.load
#         c2.load
#
#         diff = c1.diff(c2)
#
#         expect(diff).not_to be_nil
#
#         c1.patch(diff)
#
#         expect(c1.similar?(c2)).to eq(false)
#     end
#
#     context 'preserve changes' do
#         preserve = [ { :key => 'QEMU_PROTOCOL', :value => 'qemu+tcp'},
#                      { :key => 'LANG', :value => 'D' },
#                      { :key => 'QEMU_PROTOCOL', :value => 'qemu+ssh+tcp' },
#                      { :key => 'SHUTDOWN_TIMEOUT', :value => '600' } ]
#
#         block = lambda do |cfg, value|
#             return(false) if cfg.content.get(value[:key]) != value[:value]
#
#             true
#         end
#
#         it_behaves_like 'preserve changes',
#             OneCfg::Config::Type::Augeas::Shell,
#             Augeas,
#             one_file_fixtures('config/type/augeas/shell/preserve_changes/custom'),
#             one_file_fixtures('config/type/augeas/shell/preserve_changes/stock'),
#             one_file_fixtures('config/type/augeas/shell/preserve_changes/target'),
#             preserve,
#             block
#     end
end
