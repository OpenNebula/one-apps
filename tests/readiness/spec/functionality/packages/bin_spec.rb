require 'init_functionality'

describe 'Binary files' do
    before(:all) do
        # binary to do all the hardening checks
        hardening_check = File.dirname(__FILE__) + '/hardening-check'

        # check each listed command
        commands = ['/usr/bin/oned', '/usr/bin/mm_sched']
        rtn = SafeExec.run("#{hardening_check} #{commands.join(' ')} --lintian")
        expect(rtn.fail?).to be false

        # parse hardening-check failing tests in format - "error:binary", e.g.:
        # no-pie:/usr/bin/oned
        # no-stackprotector:/usr/bin/oned
        # no-fortify-functions:/usr/bin/oned
        # no-bindnow:/usr/bin/oned
        @errors = {}
        rtn.stdout.each_line do |line|
            error, binary = line.chomp.split(':', 2)

            if @errors.key?(error)
                @errors[error] << binary
            else
                @errors[error] = [binary]
            end
        end
    end

    it 'checked binaries' do
        true
    end

    it 'are PIE' do
        err = 'no-pie'
        msg = "Wrong binaries #{(@errors[err] || []).join(',')}"
        expect(@errors[err]).to be_nil, msg
    end

    it 'are stack protected' do
        err = 'no-stackprotector'
        msg = "Wrong binaries #{(@errors[err] || []).join(',')}"
        expect(@errors[err]).to be_nil, msg
    end

    it 'use Fortify Source functions' do
        err = 'no-fortify-functions'
        msg = "Wrong binaries #{(@errors[err] || []).join(',')}"
        expect(@errors[err]).to be_nil, msg
    end

    it 'have read-only relocations' do
        err = 'no-relro'
        msg = "Wrong binaries #{(@errors[err] || []).join(',')}"
        expect(@errors[err]).to be_nil, msg
    end

    it 'use immediate binding' do
        err = 'no-bindnow'
        msg = "Wrong binaries #{(@errors[err] || []).join(',')}"
        expect(@errors[err]).to be_nil, msg
    end

    it 'returns version including git commit' do
        cmd = SafeExec.run('/usr/bin/oned --version')
        expect(cmd.stdout).to match(
            /^OpenNebula [0-9\.]* \([a-z0-9]{8}\)/
        )
    end

    it 'returns correct edition' do
        cmd = SafeExec.run('/usr/bin/oned --version')

        if @main_defaults[:build_components].include?('enterprise')
            expect(cmd.stdout).to match(/Enterprise Edition/)
        else
            expect(cmd.stdout).not_to match(/Enterprise Edition/)
        end
    end
end
