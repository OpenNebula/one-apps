require 'init'

RSpec.describe 'Run vnm action extensions' do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        @info = {} # Used to pass info accross tests

        # Create VM for the whole test
        cmd = "onetemplate instantiate '#{@defaults[:template]}'"
        @info[:vm_id] = cli_create(cmd)
        @info[:vm]    = VM.new(@info[:vm_id])

        # Load the test hooks
        @info[:hooks] = []
        Dir["#{__dir__}/vnm_hooks/*"].each {|file| @info[:hooks] << file }
    end

    it 'runs without hooks' do
        @info[:vm].running?

        @info[:host] = @info[:vm].hostname
        @info[:vnm] = @info[:vm]['TEMPLATE/NIC[1]/VN_MAD']
        @info[:vnm_dir] = "#{Dir.home}/remotes/vnm/#{@info[:vnm]}"

        stop
    end

    it 'runs without hooks and with directory' do
        start
        stop
    end

    it 'runs executable hooks' do
        add_hook('ruby1')
        add_hook('bash1')

        start
    end

    it 'STDIN is passed' do
        copy_hook_log
        stdin?
    end

    it 'ARGV is passed' do
        argv?
        stop
    end

    it 'skips non executable hooks' do
        add_hook('nox')

        start
        stop
    end

    it 'fails if bad hooks, exitstatus' do
        add_hook('exit1')

        fails?
    end

    it 'fails if bad hooks, hook_crash' do
        add_hook('ruby_crash')

        fails?
    end

    it 'terminate vm' do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    after(:all) do
        clean_hooks
    end

    #### Helper methods #####

    # triggers pre and post
    def start
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
    end

    # triggers clean
    def stop
        cli_action("onevm poweroff --hard #{@info[:vm_id]}")
        @info[:vm].stopped?
    end

    def fails?
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].stopped?
    end

    # copies hook into each action directory of the current vnet driver
    def add_hook(name)
        hook = @info[:hooks].find {|h| /#{name}/ =~ h }

        ['pre.d', 'post.d', 'clean.d'].each do |dir|
            FileUtils.cp(hook, "#{@info[:vnm_dir]}/#{dir}")
        end

        cli_action('onehost sync --force')
    end

    # Deletes the test vnm hooks
    def clean_hooks
        # Clean hooks from frontend
        ['pre.d', 'post.d', 'clean.d'].each do |dir|
            @info[:hooks].each do |h|
                hook = h.split('/').last
                FileUtils.rm_f("#{@info[:vnm_dir]}/#{dir}/#{hook}")
            end
        end

        cli_action('onehost sync --force')
    end

    def copy_hook_log
        @info[:hook_log] = '/tmp/01_vnm_hooks.log'

        cmd = "scp #{@info[:host]}:#{@info[:hook_log]} #{@info[:hook_log]}"
        cmd = SafeExec.run(cmd)
        expect(cmd.success?).to be(true)
    end

    def param?(pattern)
        true if File.foreach(@info[:hook_log]).any? {|l| l[pattern] }
    end

    def stdin?
        param?("<VM><ID>#{@info[:vm_id]}</ID>")
    end

    def argv?
        param?("[#{@info[:vm_id]}]")
    end
end
