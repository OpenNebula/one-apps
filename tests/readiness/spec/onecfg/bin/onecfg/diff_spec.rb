require 'open3'
require 'yaml'

ONECFG_DIFF_FORMATS = [nil, 'text', 'line', 'yaml']

def check_diff(cfg_version, one_version, empty, format = nil)
    # initialize
    _o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg init " \
                            "--to #{cfg_version} " \
                            '--force >> /tmp/debug 2>&1')

    expect(s.success?).to eq(true)

    # diff
    diff_cmd = "#{OneCfg::BIN_DIR}/onecfg diff --prefix " +
               one_file_fixture("upgrade/stock_files/#{one_version}",
                                'bin/onecfg')

    diff_cmd << " --format #{format}" if format

    o, _e, s = Open3.capture3(diff_cmd)
    expect(s.success?).to eq(true)
    expect(o.strip.empty?).to eq(empty)

    o
end

RSpec.describe 'Tool onecfg - diff' do
    ONECFG_DIFF_FORMATS.each do |format|
        context "format #{format.nil? ? 'unspecified' : format}" do
            it 'compares same trees' do
                out = check_diff('5.10.0', '5.10.0', format != 'yaml', format)

                if format == 'yaml'
                    parsed = nil

                    expect { parsed = YAML.safe_load(out) }.not_to raise_error
                    expect(parsed.empty?).to eq(false)
                    expect(parsed['patches']).to eq({})
                end
            end

            it 'compares different trees' do
                out = check_diff('5.6.0', '5.8.0', false, format)

                if format == 'yaml'
                    parsed = nil

                    if Psych::VERSION > '4.0'
                        expect { parsed = YAML.load(out, :aliases => true) }.not_to raise_error
                    else
                        expect { parsed = YAML.load(out) }.not_to raise_error
                    end
                    expect(parsed.empty?).to eq(false)
                    expect(parsed['patches']).not_to eq({})

                    # simple YAML structure validation
                    parsed['patches'].each do |key, value|
                        expect(key).to start_with('/')
                        expect(value['change'].is_a?(Array)).to eq(true)
                        expect(value['change'].size).to be > 0
                    end
                end
            end
        end
    end
end
