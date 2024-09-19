require 'rspec'
require 'tempfile'

RSpec.describe 'Class OneCfg::Config::Type::Yaml::Strict' do
    it_behaves_like 'OneCfg::Config::Type::Base', 0..1, [:load, :diff, :breaks_format] do
        let(:obj) do
            fn = one_file_fixture('config/type/yaml/strict/upgrade/01-onehost.yaml-5.4')
            FileUtils.cp(fn, @tmp.path)
            OneCfg::Config::Type::Yaml::Strict.new(@tmp.path)
        end

        let(:obj2) do
            fn = one_file_fixture('config/type/yaml/strict/upgrade/01-onehost.yaml-5.8')
            FileUtils.cp(fn, @tmp.path)
            OneCfg::Config::Type::Yaml::Strict.new(@tmp.path)
        end
    end

    # Loads empty file, expects success and non-nil content
    it 'loads empty file' do
        fn = one_file_fixture('config/type/yaml/strict/empty')

        cfg = OneCfg::Config::Type::Yaml::Strict.new(fn)
        expect(cfg.exist?).to be true
        expect { cfg.load }.not_to raise_error(Exception)
        expect(cfg.content).not_to be_nil
    end

    # Tries to load invalid files (wrong syntax, ...)
    # and expects all of them to fail.
    context 'fails to load invalid files' do
        it_behaves_like 'invalid configs',
                        OneCfg::Config::Type::Yaml::Strict,
                        one_file_fixtures('config/type/yaml/strict/invalid/')
    end

    ##################################################################
    # Comparisons (same, similar)
    ##################################################################

    # Compares same && similar configuration files with top level Hash
    context 'compares as same and similar (set 01)' do
        it_behaves_like 'comparable configs',
                        OneCfg::Config::Type::Yaml::Strict,
                        Hash,
                        one_file_fixtures('config/type/yaml/strict/same/01'),
                        true,
                        true,
                        true # strict
    end

    # Compares same && similar configuration files with top level Array
    context 'compares as same and similar (set 02)' do
        it_behaves_like 'comparable configs',
                        OneCfg::Config::Type::Yaml::Strict,
                        Array,
                        one_file_fixtures('config/type/yaml/strict/same/02'),
                        true,
                        true,
                        true # strict
    end

    # context 'compares as not same, but similar' do
    #     it_behaves_like 'comparable configs',
    #         OneCfg::Config::Type::Yaml::Strict,
    #         Array,
    #         one_file_fixtures('config/type/yaml/strict/similar/01/'),
    #         false,
    #         true
    # end

    # Compares completely different files (NOT same, NOT similar)
    context 'compares as not same and not similar' do
        it_behaves_like 'comparable configs',
                        OneCfg::Config::Type::Yaml::Strict,
                        Hash,
                        one_file_fixtures('config/type/yaml/strict/not_similar'),
                        false,
                        false,
                        true # strict
    end

    ##################################################################
    # Automatic upgrading (diff / patch)
    ##################################################################

    context 'automatically upgrades onehost.yaml consecutive only' do
        it_behaves_like 'automatically upgradable configs',
                        OneCfg::Config::Type::Yaml::Strict,
                        Hash,
                        one_file_fixtures('config/type/yaml/strict/auto_diff_patch/onehost.yaml'),
                        false
    end

    context 'automatically upgrades sunstone-logos.yaml consecutive only' do
        it_behaves_like 'automatically upgradable configs',
                        OneCfg::Config::Type::Yaml::Strict,
                        Array, # !
                        one_file_fixtures('config/type/yaml/strict/auto_diff_patch/sunstone-logos.yaml', 2),
                        false
    end

    ##################################################################
    # Various patch modes (dummy, skip, force)
    ##################################################################

    context 'patch modes' do
        YAML_STRICT_PATCH_EXAMPLES = [{
            :name  => 'unspecified mode',
            :mode  => [],
            :fails => nil,
            :files => {
                :old      => 'config/type/yaml/strict/patch_modes/onehost.yaml-3.0',
                :new      => 'config/type/yaml/strict/patch_modes/onehost.yaml-5.8.0',
                :dist_old => 'config/type/yaml/strict/patch_modes/onehost.yaml-3.0',
                :dist_new => 'config/type/yaml/strict/patch_modes/onehost.yaml-5.8.0'
            }
        }, {
            :name  => 'mode :dummy',
            :mode  => [:dummy],
            :fails => nil,
            :files => {
                :old      => 'config/type/yaml/strict/patch_modes/onehost.yaml-3.0',
                :new      => 'config/type/yaml/strict/patch_modes/onehost.yaml-3.0',
                :dist_old => 'config/type/yaml/strict/patch_modes/onehost.yaml-3.0',
                :dist_new => 'config/type/yaml/strict/patch_modes/onehost.yaml-5.8.0'
            }
        }, {
            :name  => 'mode :skip (test 1)',
            :mode  => [:skip],
            :fails => OneCfg::Config::Exception::PatchPathNotFound,
            :files => {
                :old      => 'config/type/yaml/strict/patch_modes/skip1-onehost.yaml-3.0',
                :new      => 'config/type/yaml/strict/patch_modes/skip1-onehost.yaml-5.8.0',
                :dist_old => 'config/type/yaml/strict/patch_modes/onehost.yaml-3.0',
                :dist_new => 'config/type/yaml/strict/patch_modes/onehost.yaml-5.8.0'
            }
        }, {
            :name  => 'mode :skip (test 2)',
            :mode  => [:skip],
            :fails => OneCfg::Config::Exception::PatchValueNotFound,
            :files => {
                :old      => 'config/type/yaml/strict/patch_modes/skip2-onehost.yaml-3.0',
                :new      => 'config/type/yaml/strict/patch_modes/skip2-onehost.yaml-5.8.0',
                :dist_old => 'config/type/yaml/strict/patch_modes/onehost.yaml-3.0',
                :dist_new => 'config/type/yaml/strict/patch_modes/onehost.yaml-5.8.0'
            }
        }, {
            :name  => 'mode :skip (test 3)',
            :mode  => [:skip],
            :fails => OneCfg::Config::Exception::PatchUnexpectedData,
            :files => {
                :old      => 'config/type/yaml/strict/patch_modes/skip3-onehost.yaml-3.0',
                :new      => 'config/type/yaml/strict/patch_modes/skip3-onehost.yaml-5.8.0',
                :dist_old => 'config/type/yaml/strict/patch_modes/onehost.yaml-3.0',
                :dist_new => 'config/type/yaml/strict/patch_modes/onehost.yaml-5.8.0'
            }
        }, {
            :name  => 'mode :skip (test 4)',
            :mode  => [:skip],
            :fails => OneCfg::Config::Exception::PatchUnexpectedData,
            :files => {
                :old      => 'config/type/yaml/strict/patch_modes/skip4-onehost.yaml-3.0',
                :new      => 'config/type/yaml/strict/patch_modes/skip4-onehost.yaml-5.8.0',
                :dist_old => 'config/type/yaml/strict/patch_modes/onehost.yaml-3.0',
                :dist_new => 'config/type/yaml/strict/patch_modes/onehost.yaml-5.8.0'
            }
        }, {
            :name  => 'mode :skip (test 5)',
            :mode  => [:skip],
            :fails => OneCfg::Config::Exception::PatchValueNotFound,
            :files => {
                :old      => 'config/type/yaml/strict/patch_modes/skip5-onehost.yaml-3.0',
                :new      => 'config/type/yaml/strict/patch_modes/skip5-onehost.yaml-5.8.0',
                :dist_old => 'config/type/yaml/strict/patch_modes/onehost.yaml-3.0',
                :dist_new => 'config/type/yaml/strict/patch_modes/onehost.yaml-5.8.0'
            }
        }, {
            :name  => 'mode :skip (test 6)',
            :mode  => [:skip],
            :fails => OneCfg::Config::Exception::PatchUnexpectedData,
            :files => {
                :old      => 'config/type/yaml/strict/patch_modes/skip6-old',
                :new      => 'config/type/yaml/strict/patch_modes/skip6-new',
                :dist_old => 'config/type/yaml/strict/patch_modes/skip6-dist-old',
                :dist_new => 'config/type/yaml/strict/patch_modes/skip6-dist-new'
            }
        }, {
            :name  => 'mode :skip (test 7)',
            :mode  => [:skip],
            :fails => OneCfg::Config::Exception::PatchUnexpectedData,
            :files => {
                :old      => 'config/type/yaml/strict/patch_modes/skip7-old',
                :new      => 'config/type/yaml/strict/patch_modes/skip7-new',
                :dist_old => 'config/type/yaml/strict/patch_modes/skip7-dist-old',
                :dist_new => 'config/type/yaml/strict/patch_modes/skip7-dist-new'
            }
        }, {
            :name  => 'mode :force (test 1)',
            :mode  => [:force],
            :fails => OneCfg::Config::Exception::PatchValueNotFound,
            :files => {
                :old      => 'config/type/yaml/strict/patch_modes/force1-onehost.yaml-3.0',
                :new      => 'config/type/yaml/strict/patch_modes/force1-onehost.yaml-5.8.0',
                :dist_old => 'config/type/yaml/strict/patch_modes/onehost.yaml-3.0',
                :dist_new => 'config/type/yaml/strict/patch_modes/onehost.yaml-5.8.0'
            }
        }, {
            :name  => 'mode :force(test 2)',
            :mode  => [:force],
            :fails => OneCfg::Config::Exception::PatchValueNotFound,
            :files => {
                :old      => 'config/type/yaml/strict/patch_modes/force2-sunstone-logos.yaml-5.0',
                :new      => 'config/type/yaml/strict/patch_modes/force2-sunstone-logos.yaml-5.6.0',
                :dist_old => 'config/type/yaml/strict/patch_modes/sunstone-logos.yaml-5.0',
                :dist_new => 'config/type/yaml/strict/patch_modes/sunstone-logos.yaml-5.6.0'
            }
        }, {
            :name  => 'mode :force(test 3)',
            :mode  => [:force],
            :fails => OneCfg::Config::Exception::PatchValueNotFound,
            :files => {
                :old      => 'config/type/yaml/strict/patch_modes/force3-sunstone-logos.yaml-5.0',
                :new      => 'config/type/yaml/strict/patch_modes/force3-sunstone-logos.yaml-5.6.0',
                :dist_old => 'config/type/yaml/strict/patch_modes/sunstone-logos.yaml-5.0',
                :dist_new => 'config/type/yaml/strict/patch_modes/sunstone-logos.yaml-5.6.0'
            }
        }, {
            :name  => 'mode :force(test 4)',
            :mode  => [:force],
            :fails => OneCfg::Config::Exception::PatchValueNotFound,
            :files => {
                :old      => 'config/type/yaml/strict/patch_modes/force4-sunstone-logos.yaml-5.0',
                :new      => 'config/type/yaml/strict/patch_modes/force4-sunstone-logos.yaml-5.6.0',
                :dist_old => 'config/type/yaml/strict/patch_modes/sunstone-logos.yaml-5.0',
                :dist_new => 'config/type/yaml/strict/patch_modes/sunstone-logos.yaml-5.6.0'
            }
        }, {
            :name  => 'mode :skip and :force',
            :mode  => [:skip, :force],
            :fails => OneCfg::Config::Exception::PatchPathNotFound,
            :files => {
                :old      => 'config/type/yaml/strict/patch_modes/skip+force1-onehost.yaml-3.0',
                :new      => 'config/type/yaml/strict/patch_modes/skip+force1-onehost.yaml-5.8.0',
                :dist_old => 'config/type/yaml/strict/patch_modes/onehost.yaml-3.0',
                :dist_new => 'config/type/yaml/strict/patch_modes/onehost.yaml-5.8.0'
            },
        }, {
            :name  => 'mode :replace',
            :mode  => [:replace],
            :fails => nil,
            :files => {
                :old      => 'config/type/yaml/strict/patch_modes/replace1-onehost.yaml-3.0',
                :new      => 'config/type/yaml/strict/patch_modes/replace1-onehost.yaml-5.8.0',
                :dist_old => 'config/type/yaml/strict/patch_modes/onehost.yaml-3.0',
                :dist_new => 'config/type/yaml/strict/patch_modes/onehost.yaml-5.8.0'
            }
        }, {
            :name  => 'mode :replace and :skip',
            :mode  => [:replace, :skip],
            :fails => OneCfg::Config::Exception::PatchPathNotFound,
            :files => {
                :old      => 'config/type/yaml/strict/patch_modes/skip+replace1-onehost.yaml-3.0',
                :new      => 'config/type/yaml/strict/patch_modes/skip+replace1-onehost.yaml-5.8.0',
                :dist_old => 'config/type/yaml/strict/patch_modes/onehost.yaml-3.0',
                :dist_new => 'config/type/yaml/strict/patch_modes/onehost.yaml-5.8.0'
            }
        }, {
            :name  => 'mode :replace, :skip, :force',
            :mode  => [:replace, :skip, :force],
            :fails => OneCfg::Config::Exception::PatchPathNotFound,
            :files => {
                :old      => 'config/type/yaml/strict/patch_modes/skip+force+replace1-onehost.yaml-3.0',
                :new      => 'config/type/yaml/strict/patch_modes/skip+force+replace1-onehost.yaml-5.8.0',
                :dist_old => 'config/type/yaml/strict/patch_modes/onehost.yaml-3.0',
                :dist_new => 'config/type/yaml/strict/patch_modes/onehost.yaml-5.8.0'
            }

        ######
        # we are here just abusing this framework to test some files which
        # can't be
        }, {
            :name  => 'invalid files (test1)',
            :mode  => [],
            :fails => OneCfg::Config::Exception::PatchExpectedArray,
            :fatal => true,
            :files => {
                :old      => 'config/type/yaml/strict/patch_modes/fail1-sunstone-logos.yaml-5.0',
                :dist_old => 'config/type/yaml/strict/patch_modes/sunstone-logos.yaml-5.0',
                :dist_new => 'config/type/yaml/strict/patch_modes/sunstone-logos.yaml-5.6.0'
            }
        }]

        it_behaves_like 'patch modes',
                        OneCfg::Config::Type::Yaml::Strict,
                        YAML_STRICT_PATCH_EXAMPLES
    end

# TODO: how about those strict/upgrade/ files
#    ##################### REVIEW #########################
#
#     context 'check diff' do
#         block = lambda do |cfg|
#             cfg.content['NEW'] = {}
#             cfg.content[:default].insert(2, 'NEW')
#         end
#
#         it_behaves_like 'diff configs',
#                         OneCfg::Config::Type::Yaml::Strict,
#                         one_file_fixture('config/type/yaml/strict/not_similar/01'),
#                         one_file_fixture('config/type/yaml/strict/not_similar/01'),
#                         block
#     end
#
#     context 'check patch' do
#         block = lambda do |cfg|
#             return(false) if cfg.content[:default].include?(:CLUSTER)
#
#             return(false) unless cfg.content[:default_actions]
#
#             true
#         end
#
#         it_behaves_like 'patch configs',
#             OneCfg::Config::Type::Yaml::Strict,
#             one_file_fixture('config/type/yaml/strict/upgrade/01-onehost.yaml-5.4'),
#             one_file_fixture('config/type/yaml/strict/upgrade/01-onehost.yaml-custom-5.4'),
#             one_file_fixture('config/type/yaml/strict/upgrade/01-onehost.yaml-5.8'),
#             block
#     end
#
#     context 'patch modes **TO BE REFACTORED**' do
#         it_behaves_like 'old patch modes',
#             OneCfg::Config::Type::Yaml::Strict,
#             Hash,
#             one_file_fixture('config/type/yaml/strict/old_patch_modes/01'),
#             one_file_fixture('config/type/yaml/strict/old_patch_modes/02'),
#             one_file_fixtures('config/type/yaml/strict/old_patch_modes/different')
#     end
end
