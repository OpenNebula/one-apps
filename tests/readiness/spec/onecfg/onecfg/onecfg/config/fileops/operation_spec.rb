require 'tmpdir'

RSpec.shared_examples_for 'config file operation' do |manage|
    before(:all) do
        @dir_name  = "/tmp/#{rand(36**8).to_s(36)}"
        @file_name = "/tmp/#{rand(36**8).to_s(36)}"
        @new_file  = '/tmp/new_file'

        if manage.prefix == '/'
            FileUtils.touch(@file_name)
        else
            FileUtils.mkdir("#{manage.prefix}/tmp")
            FileUtils.touch("#{manage.prefix}/#{@file_name}")
        end
    end

    it 'respond to #new with 0,1,2 arguments' do
        expect(manage.class).to respond_to(:new).with(0..2).arguments
    end

    it 'respond to #mkdir with 1 arguments' do
        expect(manage).to respond_to(:mkdir).with(1).arguments
    end

    it 'respond to #exist? with 1 arguments' do
        expect(manage).to respond_to(:exist?).with(1).arguments
    end

    it 'creates a directory' do
        manage.mkdir(@dir_name)
        expect(File.exist?("#{manage.prefix}/#{@dir_name}")).to eq(true)
    end

    it 'respond to #chown with 2,3 arguments' do
        expect(manage).to respond_to(:chown).with(2..3).arguments
    end

    it 'checks chown' do
        groups = `groups`.split(' ').reject {|g| g ==`whoami`.strip }
        group  = groups.sample
        gid    = `getent group #{group} | cut -d ':' -f 3`

        manage.chown(@file_name, `whoami`.strip, group)
        expect(::File.stat("#{manage.prefix}/#{@file_name}").gid).to eq(gid.to_i)
    end

    it 'respond to #chmod with 2 arguments' do
        expect(manage).to respond_to(:chmod).with(2).arguments
    end

    it 'checks chmod' do
        expect(::File.executable?("#{manage.prefix}/#{@file_name}")).to eq(false)
        manage.chmod(@file_name, 'u+x')
        expect(::File.executable?("#{manage.prefix}/#{@file_name}")).to eq(true)
    end

    it 'respond to #move with 2 arguments' do
        expect(manage).to respond_to(:move).with(2).arguments
    end

    it 'checks move' do
        manage.move(@file_name, @new_file)
        expect(File.exist?("#{manage.prefix}/#{@file_name}")).to eq(false)
        expect(File.exist?("#{manage.prefix}/#{@new_file}")).to eq(true)

        manage.move(@new_file, @file_name)
    end

    it 'respond to #directory? with 1 arguments' do
        expect(manage).to respond_to(:directory?).with(1).arguments
    end

    it 'checks directory?' do
        expect(manage.directory?(@dir_name)).to eq(true)
        expect(manage.directory?(@file_name)).to eq(false)
    end

    it 'respond to #file? with 1 arguments' do
        expect(manage).to respond_to(:file?).with(1).arguments
    end

    it 'checks file?' do
        expect(manage.file?(@file_name)).to eq(true)
        expect(manage.file?(@dir_name)).to eq(false)
    end

    it 'respond to #glob with 1,2 arguments' do
        expect(manage).to respond_to(:glob).with(1..2).arguments
    end

    it 'checks glob' do
        FileUtils.touch("#{manage.prefix}/#{@dir_name}/a")
        # TODO: glob result doesn't contain prefix
        expect(manage.glob(@dir_name).empty?).to eq(false)
    end

    it 'respond to #file_read with 1 arguments' do
        expect(manage).to respond_to(:file_read).with(1).arguments
    end

    it 'respond to #file_write with 2,3 arguments' do
        expect(manage).to respond_to(:file_write).with(2..3).arguments
    end

    it 'checks file_read/write' do
        expect(manage.file_read(@file_name)).to eq('')
        expect(File.read("#{manage.prefix}/#{@file_name}")).to eq('')

        manage.file_write(@file_name, 'test')
        expect(manage.file_read(@file_name)).to eq('test')
        expect(File.read("#{manage.prefix}/#{@file_name}")).to eq('test')

        manage.file_write(@file_name, 'test', true)
        expect(manage.file_read(@file_name)).to eq('testtest')
        expect(File.read("#{manage.prefix}/#{@file_name}")).to eq('testtest')
    end

    it 'should fail to change permissions and ownership or non existing file' do
        expect { manage.chmod(rand(36**8).to_s(36), 'u+x') }.to raise_error(Exception)
        expect { manage.chown(rand(36**8).to_s(36), `whoami`) }.to raise_error(Exception)
    end

    it 'should fail to change ownership to a non existing user' do
        expect { manage.chown('', rand(36**8).to_s(36)) }.to raise_error(Exception)
    end

    it 'should fail to read from non existing file' do
        expect { manage.file_read(rand(36**8).to_s(36)) }.to raise_error(Exception)
    end

    it 'respond to #delete with 1 arguments' do
        expect(manage).to respond_to(:delete).with(1).arguments
    end

    it 'checks delete' do
        manage.delete(@dir_name)
        manage.delete(@file_name)

        expect(manage.exist?(@dir_name)).to eq(false)
        expect(manage.exist?(@file_name)).to eq(false)
        expect(File.exist?("#{manage.prefix}/#{@dir_name}")).to eq(false)
        expect(File.exist?("#{manage.prefix}/#{@file_name}")).to eq(false)
    end
end

RSpec.shared_examples_for 'privileged config file operation' do |manage|
    before(:all) do
        @file_name = "/tmp/#{rand(36**8).to_s(36)}"

        if manage.prefix == '/'
            FileUtils.touch(@file_name)
        else
            FileUtils.mkdir("#{manage.prefix}/tmp")
            FileUtils.touch("#{manage.prefix}/#{@file_name}")
        end
    end

    it 'checks chown' do
        groups = `groups`.split(' ').reject {|g| g ==`whoami`.strip }
        group  = groups.sample
        gid    = `getent group #{group} | cut -d ':' -f 3`

        old_gid = ::File.stat("#{manage.prefix}/#{@file_name}").gid
        manage.chown(@file_name, `whoami`.strip, group)
        expect(::File.stat("#{manage.prefix}/#{@file_name}").gid).to eq(old_gid)
    end

    it 'checks delete' do
        manage.delete(@file_name)
    end
end

#####

RSpec.describe 'OneCfg::Config::FileOperation' do
    context 'default' do
        it_behaves_like 'config file operation',
                        OneCfg::Config::FileOperation.new
    end

    context 'privileged' do
        it_behaves_like 'privileged config file operation',
                        OneCfg::Config::FileOperation.new('/', true)
    end

    context 'prefixed' do
        base_dir = Dir.mktmpdir

        it_behaves_like 'config file operation',
                        OneCfg::Config::FileOperation.new(base_dir)

        after(:all) do
            FileUtils.rm_r(base_dir)
        end
    end

    context 'prefixed and privileged' do
        base_dir = Dir.mktmpdir

        it_behaves_like 'privileged config file operation',
                        OneCfg::Config::FileOperation.new(base_dir, true)

        after(:all) do
            FileUtils.rm_r(base_dir)
        end
    end
end
