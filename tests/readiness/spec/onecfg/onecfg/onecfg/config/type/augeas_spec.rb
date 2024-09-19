require 'rspec'
require 'tempfile'

RSpec.describe 'Class OneCfg::Config::Type::Augeas' do
    it_behaves_like 'OneCfg::Config::Type::Base', 2..3, [:load], ['Shellvars.lns'] do
        let(:obj) do
            fn = one_file_fixture('config/type/augeas/shell/upgrade/01-kvmrc-5.0')
            FileUtils.cp(fn, @tmp.path)
            OneCfg::Config::Type::Augeas.new(@tmp.path, 'Shellvars.lns')
        end

        let(:obj2) do
            fn = one_file_fixture('config/type/augeas/shell/upgrade/01-kvmrc-5.8')
            FileUtils.cp(fn, @tmp.path)
            OneCfg::Config::Type::Augeas.new(@tmp.path, 'Shellvars.lns')
        end
    end
end
