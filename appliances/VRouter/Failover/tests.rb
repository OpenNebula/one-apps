# frozen_string_literal: true

require 'rspec'
require 'tmpdir'
require_relative '../../lib/helpers.rb'
require_relative 'execute.rb'

RSpec.describe Service::Failover do
    let(:dir) { Dir.mktmpdir }
    let(:out) { Dir.mktmpdir }
    let(:log) { File.join(out, 'log') }
    let(:errors) { [] }

    before do
        allow(described_class).to receive(:msg) { |level, text| errors << text if level == :error }
    end

    after do
        FileUtils.remove_entry(dir)
        FileUtils.remove_entry(out)
    end

    def alive?(pid)
        Process.kill(0, pid)
        true
    rescue Errno::ESRCH
        false
    end

    def hook(name, body, mode: 0o755)
        path = File.join(dir, name)
        File.write path, "#!/bin/sh\n#{body}\n"
        File.chmod mode, path
    end

    it 'runs the hooks in name order with the direction as argument' do
        hook '20-b', %(echo "b $1" >> #{log})
        hook '10-a', %(echo "a $1" >> #{log})

        described_class.run_hooks :up, dir: dir

        expect(File.read(log)).to eq "a up\nb up\n"
    end

    it 'skips files that are not executable' do
        hook '10-a', %(echo a >> #{log}), mode: 0o644

        described_class.run_hooks :down, dir: dir

        expect(File.exist?(log)).to be false
    end

    it 'keeps going and does not raise when a hook fails' do
        hook '10-fail', 'exit 3'
        hook '20-ok', %(echo ok >> #{log})

        expect { described_class.run_hooks :down, dir: dir }.not_to raise_error
        expect(File.read(log)).to eq "ok\n"
    end

    it 'does nothing when the hook directory does not exist' do
        expect { described_class.run_hooks :up, dir: File.join(dir, 'missing') }.not_to raise_error
    end

    it 'logs a failing hook and runs the next one' do
        hook '10-fail', 'echo boom; exit 3'
        hook '20-ok', %(echo ok >> #{log})

        described_class.run_hooks :down, dir: dir

        expect(errors.join).to match(/10-fail.*failed \(3\).*boom/m)
        expect(File.read(log)).to eq "ok\n"
    end

    it 'logs a signal-killed hook without an empty exit status' do
        hook '10-sig', 'kill -9 $$'

        described_class.run_hooks :down, dir: dir

        expect(errors.join).to match(/10-sig/)
        expect(errors.join).not_to match(/\(\)/)
    end

    it 'kills a hanging hook after the timeout and runs the next one' do
        pidfile = File.join(out, 'pid')
        hook '10-hang', %(echo $$ > #{pidfile}\nsleep 60)
        hook '20-ok', %(echo ok >> #{log})

        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        described_class.run_hooks :up, dir: dir, timeout: 1
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

        expect(elapsed).to be < 5
        expect(alive?(File.read(pidfile).to_i)).to be false
        expect(errors.join).to match(/10-hang.*timed out/)
        expect(File.read(log)).to eq "ok\n"
    end

    it 'does not wait for a background child that outlives the hook' do
        pidfile = File.join(out, 'pid')
        hook '10-bg', %(sleep 30 &\necho $! > #{pidfile})

        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        described_class.run_hooks :up, dir: dir, timeout: 10
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

        expect(elapsed).to be < 5
    ensure
        Process.kill('KILL', File.read(pidfile).to_i) if pidfile && File.exist?(pidfile)
    end

    it 'logs a hook that cannot be executed and does not raise' do
        path = File.join(dir, '10-noshebang')
        File.write path, "not a program\n"
        File.chmod 0o755, path
        hook '20-ok', %(echo ok >> #{log})

        expect { described_class.run_hooks :up, dir: dir }.not_to raise_error
        expect(errors.join).to match(/10-noshebang/)
        expect(File.read(log)).to eq "ok\n"
    end

    describe 'hook ordering' do
        let(:calls) { [] }

        before do
            allow(described_class).to receive(:wait_ready) { |role| calls << [:wait_ready, role] }
            allow(described_class).to receive(:load_env)
            allow(described_class).to receive(:puts)
            allow(described_class).to receive(:sleep)
            allow(described_class).to receive(:bash) { |script, **| calls << [:bash, script]; '' }
            allow(described_class).to receive(:run_hooks) { |direction| calls << [:hooks, direction] }
        end

        it 'runs the up hooks only after the stock services were restarted' do
            ENV['ONEAPP_VNF_ROUTER4_ENABLED'] = 'YES'

            described_class.up

            restarts = calls.each_index.select { |i| calls[i].first == :bash && calls[i].last.include?('restart') }
            expect(restarts).not_to be_empty
            expect(calls.index([:hooks, :up])).to be > restarts.max
            expect(calls.last).to eq [:hooks, :up]
        ensure
            ENV.delete 'ONEAPP_VNF_ROUTER4_ENABLED'
        end

        it 'runs the down hooks first, before waiting for keepalived and stopping services' do
            described_class.down

            expect(calls.first).to eq [:hooks, :down]
            expect(calls.index([:wait_ready, :standby])).to eq 1
        end
    end

    describe 'VRRP instance events' do
        it 'ignores the events of a single instance' do
            allow(described_class).to receive(:load_state).and_return(state: +'BACKUP')
            expect(described_class).not_to receive(:save_state)

            task = described_class.to_task(described_class.to_event('INSTANCE "ETH1" MASTER 100'))

            expect(task).to include(ignored: true, direction: :stay)
        end

        it 'reacts to the group event only' do
            allow(described_class).to receive(:load_state).and_return(state: +'BACKUP')
            allow(described_class).to receive(:save_state)

            task = described_class.to_task(described_class.to_event('GROUP "VRouter" MASTER 100'))

            expect(task).to include(ignored: false, direction: :up)
        end
    end
end
