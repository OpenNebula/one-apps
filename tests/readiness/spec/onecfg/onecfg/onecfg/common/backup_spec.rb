require 'tmpdir'
require 'fileutils'
require 'open3'

BACKUP_FAKE_DIRS = [
    'etc/one',
    'etc/one/vmm_exec',
    'etc/one/cli',
    'etc/httpd',
    'etc/httpd/conf',
    'var/lib/one/remotes/etc/vmm/kvm',
    'var/lib/one/remotes/etc/vmm/lxd',
    'var/lib/rpm',
    'root'
]

BACKUP_FAKE_FILES = [
    'etc/one/oned.conf',
    'etc/one/vmm_exec/vmm_exec_kvm.conf',
    'etc/one/cli/onevm.yaml',
    'etc/one/cli/onehost.yaml',
    'etc/httpd/conf/httpd.conf',
    'etc/passwd',
    'var/lib/one/one.db',
    'var/lib/one/remotes/etc/vmm/kvm/kvmrc',
    'var/lib/one/remotes/etc/vmm/kvm/lxdrc',
    'var/lib/rpm/Name',
    'root/.bashrc'
]

def create_fake(target)
    BACKUP_FAKE_DIRS.each do |name|
        FileUtils.mkdir_p("#{target}/#{name}")
    end

    BACKUP_FAKE_FILES.each do |name|
        File.open("#{target}/#{name}", 'w') do |file|
            file.puts(name)
        end
    end
end

def check_subtree(subdir, dir_temp, dir_ref, result = true)
    cmd = "diff -ur #{dir_temp}/#{subdir} #{dir_ref}/#{subdir}"
    _o, e, s = Open3.capture3(cmd)
    expect(s.success?).to eq(result), e
end

###

RSpec.shared_examples_for 'file backup' do
    before(:all) do
        @backup = OneCfg::Common::Backup

        @dir_temp = Dir.mktmpdir
        @dir_ref  = Dir.mktmpdir # this is a reference directory for compare
        @dir_bak  = Dir.mktmpdir

        create_fake(@dir_temp)
        create_fake(@dir_ref)
    end

    after(:all) do
        FileUtils.rm_r(@dir_temp) if defined?(@dir_temp)
        FileUtils.rm_r(@dir_ref)  if defined?(@dir_ref)
        FileUtils.rm_r(@dir_bak)  if defined?(@dir_bak)
    end

#    def break_dir
#        FileUtils.rm("#{@info[:dir]}/a")
#        FileUtils.rm_r("#{@info[:dir]}/a_dir")
#        FileUtils.rm_r("#{@info[:dir]}/c_dir/a")
#
#        expect(File.exist?("#{@info[:dir]}/a")).to eq(false)
#        expect(File.exist?("#{@info[:dir]}/a_dir")).to eq(false)
#        expect(File.exist?("#{@info[:dir]}/c_dir/a")).to eq(false)
#    end
#
#    def restore
#        expect(File.exist?("#{@info[:dir]}/a")).to eq(true)
#        expect(File.exist?("#{@info[:dir]}/a_dir")).to eq(true)
#        expect(File.exist?("#{@info[:dir]}/c_dir/a")).to eq(true)
#
#        expect(File.exist?("#{@info[:dir]}/e")).to eq(false)
#        expect(File.exist?("#{@info[:dir]}/e_dir")).to eq(false)
#
#        expect(system("diff -ur #{@info[:dir]} #{@info[:backup]}")).to eq(true)
#    end
#
#    before(:all) do
#        @info = {}
#
#        @info[:dir]    = Dir.mktmpdir
#        @info[:backup] = Dir.mktmpdir
#
#        # Create some files into the dir
#        FileUtils.touch("#{@info[:dir]}/a")
#        FileUtils.touch("#{@info[:dir]}/b")
#        FileUtils.touch("#{@info[:dir]}/c")
#        FileUtils.touch("#{@info[:dir]}/d")
#
#        # Create some subdirectories
#        FileUtils.mkdir("#{@info[:dir]}/a_dir")
#        FileUtils.mkdir("#{@info[:dir]}/b_dir")
#        FileUtils.mkdir("#{@info[:dir]}/c_dir")
#        FileUtils.mkdir("#{@info[:dir]}/d_dir")
#
#        # Create some files into subdirectories
#        FileUtils.touch("#{@info[:dir]}/a_dir/a")
#        FileUtils.touch("#{@info[:dir]}/a_dir/b")
#        FileUtils.touch("#{@info[:dir]}/c_dir/a")
#        FileUtils.touch("#{@info[:dir]}/c_dir/b")
#    end

    it 'respond to #backup with 1,2 arguments' do
        expect(@backup).to respond_to(:backup).with(1..2).arguments
    end

    it 'respond to #restore with 2 arguments' do
        expect(@backup).to respond_to(:restore).with(2).arguments
    end

    it 'respond to #backup_dirs with 1..3 arguments' do
        expect(@backup).to respond_to(:backup_dirs).with(1..3).arguments
    end

    it 'respond to #restore_dirs with 1..3 arguments' do
        expect(@backup).to respond_to(:backup_dirs).with(1..3).arguments
    end

    it 'fails to backup missing source' do
        expect do
            @backup.backup("#{@dir_temp}/NonExisting", "#{@dir_bak}/01")
        end.to raise_error(OneCfg::Exception::FileNotFound)
    end

    it 'fails to restore missing backup' do
        expect do
            @backup.backup("#{@dir_bak}/01", "#{@dir_temp}/NonExisting")
        end.to raise_error(OneCfg::Exception::FileNotFound)
    end

    it 'creates a backup' do
        @backup.backup("#{@dir_temp}/etc/one", "#{@dir_bak}/02")

        expect(File.exist?("#{@dir_bak}/02")).to eq(true)
        expect(Dir["#{@dir_bak}/02/**"]).to_not eq('')
    end

    ['/etc/one', '/etc/one/'].each do |target|
        it "restores backup into #{target}" do
            check_subtree('etc', @dir_temp, @dir_ref)

            FileUtils.rm_r("#{@dir_temp}/etc/one/cli")
            FileUtils.touch("#{@dir_temp}/etc/one/my_file")
            File.write("#{@dir_temp}/etc/one/oned.conf", 'ReplacedContent')
            File.write("#{@dir_temp}/etc/one/oned.conf-backup", 'ReplacedContent')
            FileUtils.touch("#{@dir_temp}/etc/one/vmm_exec/my_file")

            check_subtree('etc/one', @dir_temp, @dir_ref, false)
            @backup.restore("#{@dir_bak}/02", "#{@dir_temp}#{target}")
            check_subtree('etc', @dir_temp, @dir_ref)
        end
    end

    ['/etc/one', '/etc/one/'].each do |target|
        it "restores backup into missing #{target}" do
            check_subtree('etc', @dir_temp, @dir_ref)

            FileUtils.rm_r("#{@dir_temp}/etc/one")

            check_subtree('etc/one', @dir_temp, @dir_ref, false)
            @backup.restore("#{@dir_bak}/02", "#{@dir_temp}#{target}")
            check_subtree('etc', @dir_temp, @dir_ref)
        end
    end

    it "restores backup and doesn't touch other files" do
        check_subtree('etc', @dir_temp, @dir_ref)

        FileUtils.mkdir_p("#{@dir_temp}/etc/my_dir")
        FileUtils.rm_r("#{@dir_temp}/etc/httpd/conf")
        File.write("#{@dir_temp}/passwd", 'ReplaceContent')

        @backup.restore("#{@dir_bak}/02", "#{@dir_temp}/etc/one")

        expect(File.exist?("#{@dir_temp}/etc/my_dir")).to eq(true)
        expect(File.exist?("#{@dir_temp}/etc/httpd/conf")).to eq(false)
        expect(File.read("#{@dir_temp}/passwd")).to eq('ReplaceContent')

        check_subtree('etc', @dir_temp, @dir_ref, false)
    end

    # TODO: backup_dirs / restore_dirs <-----------------------------

#    it 'breaks directory content' do
#        break_dir
#    end
#
#    it 'adds new files and directories' do
#        FileUtils.touch("#{@info[:dir]}/e")
#        FileUtils.mkdir("#{@info[:dir]}/e_dir")
#
#        expect(File.exist?("#{@info[:dir]}/e")).to eq(true)
#        expect(File.exist?("#{@info[:dir]}/e_dir")).to eq(true)
#    end


#    it 'restores from backup' do
#        manage.restore(@info[:backup], @info[:dir])
#        restore
#    end
#
#    #TODO: backup that we didn't break any other directory (/etc/..., non-one)
#
#    it 'deletes whole dir' do
#        FileUtils.rm_r(@info[:dir])
#        expect(File.exist?(@info[:dir])).to eq(false)
#    end
#
#    it 'restores from backup' do
#        manage.restore(@info[:backup], @info[:dir])
#        restore
#    end
#
#    it 'breaks directory content' do
#        break_dir
#    end
#
#    it 'syncs both directory' do
#        manage.rsync(@info[:backup], @info[:dir])
#        restore
#    end
#
#    it 'deletes backup' do
#        FileUtils.rm_r(@info[:backup])
#    end
#
#    it 'should fail to restore a deleted backup' do
#        expect { manage.restore(@info[:backup], @info[:dir]) }.to raise_error(Exception)
#    end
#
#    after(:all) do
#        FileUtils.rm_r(@info[:dir])
#    end
end

RSpec.describe 'OneCfg::Common:Backup' do
    include_examples 'file backup'
end

__END__

RSpec.shared_examples_for 'common file backup' do |manage|
    def break_dir
        FileUtils.rm("#{@info[:dir]}/a")
        FileUtils.rm_r("#{@info[:dir]}/a_dir")
        FileUtils.rm_r("#{@info[:dir]}/c_dir/a")

        expect(File.exist?("#{@info[:dir]}/a")).to eq(false)
        expect(File.exist?("#{@info[:dir]}/a_dir")).to eq(false)
        expect(File.exist?("#{@info[:dir]}/c_dir/a")).to eq(false)
    end

    def restore
        expect(File.exist?("#{@info[:dir]}/a")).to eq(true)
        expect(File.exist?("#{@info[:dir]}/a_dir")).to eq(true)
        expect(File.exist?("#{@info[:dir]}/c_dir/a")).to eq(true)

        expect(File.exist?("#{@info[:dir]}/e")).to eq(false)
        expect(File.exist?("#{@info[:dir]}/e_dir")).to eq(false)

        expect(system("diff -ur #{@info[:dir]} #{@info[:backup]}")).to eq(true)
    end

    before(:all) do
        @info = {}

        @info[:dir]    = Dir.mktmpdir
        @info[:backup] = Dir.mktmpdir

        # Create some files into the dir
        FileUtils.touch("#{@info[:dir]}/a")
        FileUtils.touch("#{@info[:dir]}/b")
        FileUtils.touch("#{@info[:dir]}/c")
        FileUtils.touch("#{@info[:dir]}/d")

        # Create some subdirectories
        FileUtils.mkdir("#{@info[:dir]}/a_dir")
        FileUtils.mkdir("#{@info[:dir]}/b_dir")
        FileUtils.mkdir("#{@info[:dir]}/c_dir")
        FileUtils.mkdir("#{@info[:dir]}/d_dir")

        # Create some files into subdirectories
        FileUtils.touch("#{@info[:dir]}/a_dir/a")
        FileUtils.touch("#{@info[:dir]}/a_dir/b")
        FileUtils.touch("#{@info[:dir]}/c_dir/a")
        FileUtils.touch("#{@info[:dir]}/c_dir/b")
    end

    it 'respond to #backup with 1,2 arguments' do
        expect(manage).to respond_to(:backup).with(1..2).arguments
    end

    it 'creates a backup' do
        manage.backup(@info[:dir], @info[:backup])

        expect(File.exist?(@info[:backup])).to eq(true)
        expect(Dir["#{@info[:backup]}/**"]).to_not eq('')
    end

    it 'breaks directory content' do
        break_dir
    end

    it 'adds new files and directories' do
        FileUtils.touch("#{@info[:dir]}/e")
        FileUtils.mkdir("#{@info[:dir]}/e_dir")

        expect(File.exist?("#{@info[:dir]}/e")).to eq(true)
        expect(File.exist?("#{@info[:dir]}/e_dir")).to eq(true)
    end

    it 'respond to #restore with 2 arguments' do
        expect(manage).to respond_to(:restore).with(2).arguments
    end

    it 'restores from backup' do
        manage.restore(@info[:backup], @info[:dir])
        restore
    end

    #TODO: backup that we didn't break any other directory (/etc/..., non-one)

    it 'deletes whole dir' do
        FileUtils.rm_r(@info[:dir])
        expect(File.exist?(@info[:dir])).to eq(false)
    end

    it 'restores from backup' do
        manage.restore(@info[:backup], @info[:dir])
        restore
    end

    it 'breaks directory content' do
        break_dir
    end

    it 'syncs both directory' do
        manage.rsync(@info[:backup], @info[:dir])
        restore
    end

    it 'deletes backup' do
        FileUtils.rm_r(@info[:backup])
    end

    it 'should fail to restore a deleted backup' do
        expect { manage.restore(@info[:backup], @info[:dir]) }.to raise_error(Exception)
    end

    after(:all) do
        FileUtils.rm_r(@info[:dir])
    end
end

RSpec.describe 'OneCfg::Common:Backup' do
    context 'check file backup' do
        it_behaves_like 'common file backup', OneCfg::Common::Backup
    end
end
