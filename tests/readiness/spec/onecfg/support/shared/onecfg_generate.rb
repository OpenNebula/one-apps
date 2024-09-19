require 'git'
require 'tempfile'
require 'hashdiff'

RSpec.shared_examples_for 'onecfg generate' do |git_url,
                                                source,
                                                target,
                                                ref_desc,
                                                migrator = nil|

    before(:all) do
        # clone git, retry to handle timeouts in parallel runs
        5.times do |i|
            @git_dir = Dir.mktmpdir
            begin
                Git.clone(git_url,
                          File.basename(@git_dir),
                          :path => File.dirname(@git_dir))
            rescue Git::FailedError
                fail "Could not clone git" if i == 5

                puts "Git clone failed, retrying (#{i})"
                sleep 10
            end
        end

        # new descriptor
        @new_desc = Tempfile.new('onescape-rspec-')
        @new_desc.close
    end

    after(:all) do
        if defined?(@git_dir) && @git_dir
            FileUtils.rm_r(@git_dir)
        end

        if defined?(@new_desc) && @new_desc
            @new_desc.unlink
        end
    end

    it 'generates YAML descriptor' do
        cmd = "#{OneCfg::BIN_DIR}/onecfg generate " \
              "#{@git_dir} #{source} #{target} #{migrator} " \
              "--descriptor-name #{@new_desc.path} " \
              '--debug '

        _o, s = Open3.capture2("#{cmd} 2>&1")

        expect(s.success?).to eq(true),
                              'Failed to generate descriptor between ' \
                              "#{source} and #{target}"
    end

    it 'compares with stock' do
        if Psych::VERSION > '4.0'
            desc1 = YAML.load_file(@new_desc.path, :aliases => true)
            desc2 = YAML.load_file(ref_desc, :aliases => true)
        else
            desc1 = YAML.load_file(@new_desc.path)
            desc2 = YAML.load_file(ref_desc)
        end

        expect(desc1).not_to be_empty
        expect(desc2).not_to be_empty

        # compare descriptors
        hash_diff = Hashdiff.best_diff(desc1, desc2)
        expect(hash_diff).to be_empty
    end
end
