RSpec.describe 'Tool onecfg - generate' do
    context 'without Ruby migrator' do
        it_behaves_like 'onecfg generate',
                        'https://github.com/OpenNebula/one.git',
                        'release-5.4.0',
                        'release-5.4.1',
                        "#{OneCfg::MIGR_DIR}/5.4.0_to_5.4.1.yaml"
    end

    context 'with Ruby migrator' do
        it_behaves_like 'onecfg generate',
                        'https://github.com/OpenNebula/one.git',
                        'release-5.4.6',
                        'release-5.6.0',
                        "#{OneCfg::MIGR_DIR}/5.4.6_to_5.6.0.yaml",
                        "#{OneCfg::MIGR_DIR}/5.4.6_to_5.6.0.rb"
    end
end
