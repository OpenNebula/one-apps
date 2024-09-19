require 'open3'

ONECFG_PATCH_FORMATS = ['line', 'yaml']

RSpec.shared_examples_for 'onecfg patch status' do |dir, changed, args, rc, patch|
    before(:all) do
        @params = {}
        @params[:tmpdir] = Dir.mktmpdir
        FileUtils.cp_r("#{dir}/.", @params[:tmpdir])
    end

    it "exits with #{rc}" do
        patch_cmd = "#{OneCfg::BIN_DIR}/onecfg patch" \
                    " #{args}" \
                    ' --ddebug' \
                    " --prefix #{@params[:tmpdir]}"

        _o, e, s = Open3.capture3(patch_cmd, :stdin_data => patch)
        expect(s.exitstatus).to eq(rc), "Status:#{s.exitstatus}\nOutput:\n#{e}"
    end

    it "#{changed ? '' : 'did not '}change filesystem" do
        diff_cmd = "#{OneCfg::BIN_DIR}/onecfg diff" \
                   ' --format line' \
                   " --prefix #{@params[:tmpdir]}"

        o, e, s = Open3.capture3(diff_cmd)
        expect(s.success?).to eq(true), "Output: #{e}"
        expect(o.strip.empty?).not_to eq(changed)
    end

    after(:all) do
        if !@params[:tmpdir].nil? && File.directory?(@params[:tmpdir])
            FileUtils.rm_rf(@params[:tmpdir])
        end
    end
end

RSpec.shared_examples_for 'onecfg diff/patch' do |dir1, dir2, format, stdin = true|
    before(:all) do
        @params = {}
        @params[:tmpdir] = Dir.mktmpdir
        FileUtils.cp_r("#{dir1}/.", @params[:tmpdir])
    end

    after(:all) do
        if !@params[:tmpdir].nil? && File.directory?(@params[:tmpdir])
            FileUtils.rm_rf(@params[:tmpdir])
        end
    end

    it 'creates diff' do
        diff_cmd = "#{OneCfg::BIN_DIR}/onecfg diff" \
                   " --format #{format}" \
                   " --prefix #{dir2}"

        @params[:diff], e, s = Open3.capture3(diff_cmd)
        expect(s.success?).to eq(true), "Output: #{e}"
        expect(@params[:diff].strip.empty?).to eq(false)

        #STDERR.puts @params[:diff]
    end

    it 'patches from diff' do
        patch_cmd = "#{OneCfg::BIN_DIR}/onecfg patch" \
                    ' --ddebug' \
                    " --format #{format}" \
                    " --prefix #{@params[:tmpdir]}"

        stdin_data = nil

        if stdin
            stdin_data = @params[:diff]
        else
            temp_file = Tempfile.new('rspec')
            temp_file.write(@params[:diff])
            temp_file.close

            patch_cmd << " #{temp_file.path}"
        end

        _o, e, s = Open3.capture3(patch_cmd, :stdin_data => stdin_data)
        expect(s.success?).to eq(true), "Output:\n#{e}\nDiff:\n#{@params[:diff]}"
    end

    it 'finds no differences on patched tree' do
        diff_cmd = "#{OneCfg::BIN_DIR}/onecfg diff" \
                   " --format #{format}" \
                   " --prefix #{@params[:tmpdir]}"

        o, e, s = Open3.capture3(diff_cmd)

        # we do once-again diff, but now on tmpdir tree and it must provide
        # exactly same patch as diff on dir2 previously
        expect(s.success?).to eq(true), "Output: #{e}"
        expect(o.strip.empty?).to eq(false)
        expect(o).to eq(@params[:diff])
    end
end

RSpec.describe 'Tool onecfg - patch' do
    # patch - from file / from standard input / from simple / from yaml
    PATCH_VERSION = '5.10.0'
    FIXS_BASE = one_file_fixture("patch/base/#{PATCH_VERSION}", 'bin/onecfg')
    FIXS_MOD1 = one_file_fixture("patch/modified1/#{PATCH_VERSION}", 'bin/onecfg')

    context 'initialize' do
        include_examples 'mock oned', PATCH_VERSION, true
    end

    # line format
    context 'manual with line format and' do
        context 'empty' do
            include_examples 'onecfg patch status',
                             FIXS_BASE,
                             false,
                             '--format line',
                             255,
                             nil
        end

        context 'nothing to apply' do
            include_examples 'onecfg patch status',
                             FIXS_BASE,
                             false,
                             '--format line',
                             255,
                             '/etc/one/oned.conf rm UNKNOWN'
        end

        context 'all to apply' do
            include_examples 'onecfg patch status',
                             FIXS_BASE,
                             true,
                             '--format line',
                             0,
                             <<-'PATCH'
                                /etc/one/oned.conf ins NEW_VALUE1 "\"something\""
                                /etc/one/oned.conf ins NEW_VALUE2 "\"something\""
                             PATCH
        end

        context 'all to apply but --noop' do
            include_examples 'onecfg patch status',
                             FIXS_BASE,
                             false,
                             '--format line --noop',
                             0,
                             <<-'PATCH'
                                /etc/one/oned.conf ins NEW_VALUE1 "\"something\""
                                /etc/one/oned.conf ins NEW_VALUE2 "\"something\""
                             PATCH
        end

        context 'all to apply with comment' do
            include_examples 'onecfg patch status',
                             FIXS_BASE,
                             true,
                             '--format line',
                             0,
                             <<-'PATCH'
                                /etc/one/oned.conf ins NEW_VALUE1 "\"something\""
                                # /etc/one/oned.conf rm  NEW_VALUE2
                             PATCH
        end

        context 'some to apply' do
            include_examples 'onecfg patch status',
                             FIXS_BASE,
                             true,
                             '--format line',
                             1,
                             <<-'PATCH'
                                /etc/one/oned.conf ins NEW_VALUE1 "\"something\""
                                /etc/one/oned.conf rm  NEW_VALUE2
                             PATCH
        end

        context 'some to apply but --noop' do
            include_examples 'onecfg patch status',
                             FIXS_BASE,
                             false,
                             '--format line --noop',
                             1,
                             <<-'PATCH'
                                /etc/one/oned.conf ins NEW_VALUE1 "\"something\""
                                /etc/one/oned.conf rm  NEW_VALUE2
                             PATCH
        end

        context 'some to apply but --all' do
            include_examples 'onecfg patch status',
                             FIXS_BASE,
                             false,
                             '--format line --all',
                             255,
                             <<-'PATCH'
                                /etc/one/oned.conf ins NEW_VALUE "\"something\""
                                /etc/one/oned.conf rm  NEW_VALUE
                                /etc/one/oned.conf rm  NEW_VALUE
                             PATCH
        end

        context 'invalid/missing file' do
            include_examples 'onecfg patch status',
                             FIXS_BASE,
                             false,
                             '--format line',
                             255,
                             <<-'PATCH'
                                /etc/one/oned.conf ins NEW_VALUE "\"something\""
                                /etc/one/fireedge-server.conf rm NEW_VALUE
                             PATCH
        end
    end

    # YAML format
    context 'manual with YAML format and' do
        context 'empty' do
            include_examples 'onecfg patch status',
                             FIXS_BASE,
                             false,
                             '--format yaml',
                             255,
                             nil
        end

        context 'nothing to apply' do
            include_examples 'onecfg patch status',
                             FIXS_BASE,
                             false,
                             '--format yaml',
                             255,
                             <<-'PATCH'
---
patches: []
                             PATCH
        end

        context 'all to apply' do
            include_examples 'onecfg patch status',
                             FIXS_BASE,
                             true,
                             '--format yaml',
                             0,
                             <<-'PATCH'
---
patches:
  /etc/one/oned.conf:
    class: Augeas::ONE
    change:
    - path: []
      key: NEW_VALUE1
      value: '"something"'
      state: ins
      extra: {}
    - path: []
      key: NEW_VALUE2
      value: '"something"'
      state: ins
      extra: {}
                             PATCH
        end

        context 'all to apply' do
            include_examples 'onecfg patch status',
                             FIXS_BASE,
                             false,
                             '--format yaml --noop',
                             0,
                             <<-'PATCH'
---
patches:
  /etc/one/oned.conf:
    class: Augeas::ONE
    change:
    - path: []
      key: NEW_VALUE1
      value: '"something"'
      state: ins
      extra: {}
    - path: []
      key: NEW_VALUE2
      value: '"something"'
      state: ins
      extra: {}
                             PATCH
        end

        context 'some to apply' do
            include_examples 'onecfg patch status',
                             FIXS_BASE,
                             true,
                             '--format yaml',
                             1,
                             <<-'PATCH'
---
patches:
  /etc/one/oned.conf:
    class: Augeas::ONE
    change:
    - path: []
      key: NEW_VALUE1
      value: '"something"'
      state: ins
      extra: {}
    - path: []
      key: NEW_VALUE2
      old: '"something"'
      state: rm
      extra: {}
                             PATCH
        end

        context 'some to apply but --noop' do
            include_examples 'onecfg patch status',
                             FIXS_BASE,
                             false,
                             '--format yaml --noop',
                             1,
                             <<-'PATCH'
---
patches:
  /etc/one/oned.conf:
    class: Augeas::ONE
    change:
    - path: []
      key: NEW_VALUE1
      value: '"something"'
      state: ins
      extra: {}
    - path: []
      key: NEW_VALUE2
      old: '"something"'
      state: rm
      extra: {}
                             PATCH
        end

        context 'some to apply but --all' do
            include_examples 'onecfg patch status',
                             FIXS_BASE,
                             false,
                             '--format yaml --all',
                             255,
                             <<-'PATCH'
---
patches:
  /etc/one/oned.conf:
    class: Augeas::ONE
    change:
    - path: []
      key: NEW_VALUE
      value: '"something"'
      state: ins
      extra: {}
    - path: []
      key: NEW_VALUE
      old: '"something"'
      state: rm
      extra: {}
    - path: []
      key: NEW_VALUE
      old: '"something"'
      state: rm
      extra: {}
                             PATCH
        end

        context 'invalid/missing file' do
            include_examples 'onecfg patch status',
                             FIXS_BASE,
                             false,
                             '--format yaml',
                             255,
                             <<-'PATCH'
---
patches:
  /etc/one/oned.conf:
    class: Augeas::ONE
    change:
    - path: []
      key: NEW_VALUE
      value: '"something"'
      state: ins
      extra: {}
  /etc/one/fireedge-server.conf:
    class: Yaml
    change:
    - path: []
      key: NEW_VALUE
      old: '"something"'
      state: rm
      extra: {}
                             PATCH
        end
    end

    # automatic diff/patch application
    context 'automatic' do
        ONECFG_PATCH_FORMATS.each do |format|
            [true, false].each do |stdin|
                context "with #{format} format from #{stdin ? 'stdin' : 'file'}" do
                    include_examples 'onecfg diff/patch',
                                     FIXS_BASE,
                                     FIXS_MOD1,
                                     format,
                                     stdin
                end
            end
        end
    end
end
