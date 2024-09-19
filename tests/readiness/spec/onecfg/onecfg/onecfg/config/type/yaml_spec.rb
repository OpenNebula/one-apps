require 'rspec'
require 'tempfile'

RSpec.describe 'Class OneCfg::Config::Type::Yaml' do
    it_behaves_like 'OneCfg::Config::Type::Base', 0..1, [:load, :diff, :breaks_format] do
        let(:obj) do
            fn = one_file_fixture('config/type/yaml/simple/upgrade/01-admin.yaml-5.4')
            FileUtils.cp(fn, @tmp.path)
            OneCfg::Config::Type::Yaml.new(@tmp.path)
        end

        let(:obj2) do
            fn = one_file_fixture('config/type/yaml/simple/upgrade/01-admin.yaml-5.8')
            FileUtils.cp(fn, @tmp.path)
            OneCfg::Config::Type::Yaml.new(@tmp.path)
        end
    end

    # Loads empty file, expects success and non-nil content
    it 'loads empty file' do
        fn = one_file_fixture('config/type/yaml/simple/empty')

        cfg = OneCfg::Config::Type::Yaml.new(fn)
        expect(cfg.exist?).to be true
        expect { cfg.load }.not_to raise_error(Exception)
        expect(cfg.content).not_to be_nil
    end

    # Tries to load invalid files (wrong syntax, ...)
    # and expects all of them to fail.
    context 'fails to load invalid files' do
        it_behaves_like 'invalid configs',
                        OneCfg::Config::Type::Yaml,
                        one_file_fixtures('config/type/yaml/simple/invalid/')
    end

    ##################################################################
    # Comparisons (same, similar)
    ##################################################################

    # Compares same && similar configuration files with top level Hash
    context 'compares as same and similar' do
        it_behaves_like 'comparable configs',
                        OneCfg::Config::Type::Yaml,
                        Hash,
                        one_file_fixtures('config/type/yaml/simple/same'),
                        true,  # same
                        true   # similar
    end

    # Compares as not-same, but similar
    context 'compares as not same, but similar (set 01)' do
        it_behaves_like 'comparable configs',
                        OneCfg::Config::Type::Yaml,
                        Hash,
                        one_file_fixtures('config/type/yaml/simple/similar/01/'),
                        false, # same
                        true   # similar
    end

#    #TODO: make this in a way that it can read several sets without
#    # repating the code
#    context 'compares as not same, but similar 02' do
#        it_behaves_like 'comparable configs',
#            OneCfg::Config::Yaml,
#            Array,  #!
#            one_file_fixtures('config/yaml/simple/similar/02/'),
#            false,
#            true
#    end

    # Compares completely different files (NOT same, NOT similar)
    context 'compares as not same and not similar' do
        it_behaves_like 'comparable configs',
                        OneCfg::Config::Type::Yaml,
                        Hash,
                        one_file_fixtures('config/type/yaml/simple/not_similar'),
                        false,
                        false
    end

    ##################################################################
    # Automatic upgrading (diff / patch)
    ##################################################################

    context 'automatically upgrades all permutations' do
        ['kvm-admin.yaml', 'sunstone-views.yaml', 'random'].each do |f|
            context f do
                it_behaves_like 'automatically upgradable configs',
                                OneCfg::Config::Type::Yaml,
                                Hash,
                                one_file_fixtures("config/type/yaml/simple/auto_diff_patch/#{f}"),
                                true
            end
        end
    end

    ##################################################################
    # Various patch modes (dummy, skip, force)
    ##################################################################

    context 'patch modes' do
        # Notes:
        # - force mode can't be tested as it's effective only for
        #   strictly ordered configs. (Yaml::Strict), where value
        #   is forced to place to some suitable place instead of
        #   proposed index
        # - also force+skip doesn't make sense
        YAML_PATCH_EXAMPLES = [{
            :name  => 'unspecified mode',
            :mode  => [],
            :fails => nil,
            :files => {
                :old      => 'config/type/yaml/simple/patch_modes/sunstone-views.yaml-4.0',
                :new      => 'config/type/yaml/simple/patch_modes/sunstone-views.yaml-5.4.0',
                :dist_old => 'config/type/yaml/simple/patch_modes/sunstone-views.yaml-4.0',
                :dist_new => 'config/type/yaml/simple/patch_modes/sunstone-views.yaml-5.4.0'
            }
        }, {
            :name  => 'mode :dummy',
            :mode  => [:dummy],
            :fails => nil,
            :files => {
                :old      => 'config/type/yaml/simple/patch_modes/sunstone-views.yaml-4.0',
                :new      => 'config/type/yaml/simple/patch_modes/sunstone-views.yaml-4.0',
                :dist_old => 'config/type/yaml/simple/patch_modes/sunstone-views.yaml-4.0',
                :dist_new => 'config/type/yaml/simple/patch_modes/sunstone-views.yaml-5.4.0'
            }
        }, {
            :name  => 'mode :skip (test 1)',
            :mode  => [:skip],
            :fails => OneCfg::Config::Exception::PatchPathNotFound,
            :files => {
                :old      => 'config/type/yaml/simple/patch_modes/skip1-sunstone-views.yaml-4.0',
                :new      => 'config/type/yaml/simple/patch_modes/skip1-sunstone-views.yaml-5.4.0',
                :dist_old => 'config/type/yaml/simple/patch_modes/sunstone-views.yaml-4.0',
                :dist_new => 'config/type/yaml/simple/patch_modes/sunstone-views.yaml-5.4.0'
            }
        }, {
            :name  => 'mode :skip (test 2)',
            :mode  => [:skip],
            :fails => OneCfg::Config::Exception::PatchUnexpectedData,
            :files => {
                :old      => 'config/type/yaml/simple/patch_modes/skip2-sunstone-views.yaml-4.0',
                :new      => 'config/type/yaml/simple/patch_modes/skip2-sunstone-views.yaml-5.4.0',
                :dist_old => 'config/type/yaml/simple/patch_modes/sunstone-views.yaml-4.0',
                :dist_new => 'config/type/yaml/simple/patch_modes/sunstone-views.yaml-5.4.0'
            }
        }, {
            :name  => 'mode :skip (test 3)',
            :mode  => [:skip],
            :fails => OneCfg::Config::Exception::PatchValueNotFound,
            :files => {
                :old      => 'config/type/yaml/simple/patch_modes/skip3-sunstone-views.yaml-4.0',
                :new      => 'config/type/yaml/simple/patch_modes/skip3-sunstone-views.yaml-5.4.0',
                :dist_old => 'config/type/yaml/simple/patch_modes/sunstone-views.yaml-4.0',
                :dist_new => 'config/type/yaml/simple/patch_modes/sunstone-views.yaml-5.4.0'
            }
        }, {
            :name  => 'mode :skip (test 4)',
            :mode  => [:skip],
            :fails => OneCfg::Config::Exception::PatchExpectedHash,
            :files => {
                :old      => 'config/type/yaml/simple/patch_modes/skip4-sunstone-views.yaml-4.0',
                :new      => 'config/type/yaml/simple/patch_modes/skip4-sunstone-views.yaml-5.4.0',
                :dist_old => 'config/type/yaml/simple/patch_modes/sunstone-views.yaml-4.0',
                :dist_new => 'config/type/yaml/simple/patch_modes/sunstone-views.yaml-5.4.0'
            }
        }, {
            :name  => 'mode :replace',
            :mode  => [:replace],
            :fails => nil,
            :files => {
                :old      => 'config/type/yaml/simple/patch_modes/replace1-sunstone-views.yaml-4.0',
                :new      => 'config/type/yaml/simple/patch_modes/replace1-sunstone-views.yaml-5.4.0',
                :dist_old => 'config/type/yaml/simple/patch_modes/sunstone-views.yaml-4.0',
                :dist_new => 'config/type/yaml/simple/patch_modes/sunstone-views.yaml-5.4.0'
            }
        }, {
            :name  => 'mode :replace, :skip',
            :mode  => [:replace, :skip],
            :fails => OneCfg::Config::Exception::PatchPathNotFound,
            :files => {
                :old      => 'config/type/yaml/simple/patch_modes/skip+replace1-sunstone-views.yaml-4.0',
                :new      => 'config/type/yaml/simple/patch_modes/skip+replace1-sunstone-views.yaml-5.4.0',
                :dist_old => 'config/type/yaml/simple/patch_modes/sunstone-views.yaml-4.0',
                :dist_new => 'config/type/yaml/simple/patch_modes/sunstone-views.yaml-5.4.0'
            }
        }]

        it_behaves_like 'patch modes',
                        OneCfg::Config::Type::Yaml,
                        YAML_PATCH_EXAMPLES
    end

#     ##################### REVIEW #########################
#
#     context 'check diff' do
#         block = lambda do |cfg|
#             cfg.content['NEW'] = {}
#             cfg.content['do_count_animation'] = false
#         end
#
#         it_behaves_like 'diff configs',
#             OneCfg::Config::Yaml,
#             one_file_fixture('config/type/yaml/simple/similar/01/01'),
#             one_file_fixture('config/type/yaml/simple/similar/01/02'),
#             block
#     end
#
#     context 'check patch' do
#         block = lambda do |cfg|
#             return(false) if cfg.content['enabled_tabs'].include?('dashboard-tab')
#
#             return(false) unless cfg.content['do_count_animation']
#
#             true
#         end
#
#         it_behaves_like 'patch configs',
#             OneCfg::Config::Yaml,
#             one_file_fixture('config/type/yaml/simple/upgrade/01-admin.yaml-5.4'),
#             one_file_fixture('config/type/yaml/simple/upgrade/01-admin.yaml-custom-5.4'),
#             one_file_fixture('config/type/yaml/simple/upgrade/01-admin.yaml-5.8'),
#             block
#     end
#
#     context 'patch modes' do
#         it_behaves_like 'old patch modes',
#             OneCfg::Config::Yaml,
#             Hash,
#             one_file_fixture('config/type/yaml/simple/OLD_patch_modes/01'),
#             one_file_fixture('config/type/yaml/simple/OLD_patch_modes/02'),
#             one_file_fixtures('config/type/yaml/simple/OLD_patch_modes/different')
#     end
#
#     context 'preserve changes' do
#         preserve = [ { :path => [], :key => 'provision_logo', :value => 'images/opennebula-5.0.jpg'},
#                      { :path => ['tabs', 'dashboard-tab', 'actions'], :key => 'Dashboard.refresh', :value => true },
#                      { :path => [], :key => 'link_logo', :value => 'my_link_logo' },
#                      { :path => ['features'], :key => 'showback', :value => false } ]
#
#         block = lambda do |cfg, value|
#             hash = cfg.content
#
#             value[:path].each do |path|
#                 hash = hash[path]
#             end
#
#             return(false) if hash[value[:key]] != value[:value]
#
#             true
#         end
#
#         it_behaves_like 'preserve changes',
#             OneCfg::Config::Yaml,
#             Hash,
#             one_file_fixtures('config/type/yaml/simple/OLD_preserve_changes/custom'),
#             one_file_fixtures('config/type/yaml/simple/OLD_preserve_changes/stock'),
#             one_file_fixtures('config/type/yaml/simple/OLD_preserve_changes/target'),
#             preserve,
#             block
#     end
#
#     context 'terminate here' do
#         it 'terminates here' do
#             abort
#         end
#     end
end
