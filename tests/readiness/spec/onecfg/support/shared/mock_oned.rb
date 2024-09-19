require 'open3'

RSpec.shared_examples_for 'mock oned' do |one_version, init = false|
    before(:all) do
        if File.exist?(OneCfg::CONFIG_CFG)
            File.delete(OneCfg::CONFIG_CFG)
        end

        # mock oned command
        @mock_dir = Dir.mktmpdir
        File.open("#{@mock_dir}/oned", 'w') do |file|
            file.chmod(0o755)

            if one_version
                file.write(<<-EOT)
#!/bin/sh
cat - <<EOF
Copyright 2002-2019, OpenNebula Project, OpenNebula Systems

OpenNebula #{one_version} (9128a58e) is distributed and licensed for use under the terms of the
Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0).
EOF
EOT
            else
                file.write(<<-EOT)
#!/bin/sh
exit 1
EOT
            end
        end

        # save and update PATH
        @old_path = ENV['PATH']
        ENV['PATH'] = "#{@mock_dir}:#{ENV['PATH']}"
    end

    after(:all) do
        if defined?(@mock_dir) && @mock_dir
            FileUtils.rm_r(@mock_dir)
        end

        if defined?(@old_path) && @old_path
            ENV['PATH'] = @old_path
        end
    end

    it 'is not initialized' do
        o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg status 2>&1")
        expect(s.success?).to eq(false)
        match_onecfg_status(o, one_version, nil)
    end

    if init
        it 'initializes' do
            o, s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg init 2>&1")
            expect(s.success?).to eq(true)

            o, _s = Open3.capture2("#{OneCfg::BIN_DIR}/onecfg status 2>&1")
            match_onecfg_status(o, one_version, one_version)
        end
    end
end
