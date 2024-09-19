RSpec.describe 'Class OneCfg::Config::Type::Base' do
    it_behaves_like 'OneCfg::Config::Type::Base', 0..1 do
        let(:obj) do
            fn = one_file_fixture('config/type/simple/10-name.sh-5.6')
            FileUtils.cp(fn, @tmp.path)
            cfg = OneCfg::Config::Type::Base.new(@tmp.path)

            # mock content to support comparison operations
            #TODO: do we want this now?
            cfg.content = 'dummy1'
            cfg
        end

        let(:obj2) do
            fn = one_file_fixture('config/type/simple/10-name.sh-5.8')
            FileUtils.cp(fn, @tmp.path)
            cfg = OneCfg::Config::Type::Base.new(@tmp.path)

            # mock content to support comparison operations
            #TODO: do we want this now?
            cfg.content = 'dummy2'
            cfg
        end
    end
end
