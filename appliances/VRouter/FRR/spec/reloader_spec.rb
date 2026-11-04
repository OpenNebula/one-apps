# frozen_string_literal: true

require_relative 'support/quiet_logs'
require 'tmpdir'
require_relative '../reloader'

RSpec.describe Service::FRR::Reloader do
    let(:commands) { [] }
    let(:runner) { ->(command) { commands << command; ['output', true] } }
    let(:reloader) { described_class.new(runner: runner) }

    it 'tests a candidate with frr-reload.py --test' do
        result = reloader.test('/tmp/candidate.conf')

        expect(commands.last).to eq ['/usr/lib/frr/frr-reload.py', '--test', '--stdout', '/tmp/candidate.conf']
        expect(result).to have_attributes(ok: true, output: 'output')
    end

    it 'applies a candidate with frr-reload.py --reload' do
        reloader.reload('/tmp/candidate.conf')

        expect(commands.last).to eq ['/usr/lib/frr/frr-reload.py', '--reload', '--stdout', '/tmp/candidate.conf']
    end

    it 'runs the soft refresh commands it is given' do
        given = [['vtysh', '-c', 'clear bgp ipv4 unicast * soft'], ['vtysh', '-c', 'clear bgp ipv6 unicast * soft']]
        reloader.soft_refresh(given)

        expect(commands).to include(*given)
    end

    it 'runs the summary command it is given' do
        reloader.summary(['vtysh', '-c', 'show bgp summary json'])

        expect(commands.last).to eq ['vtysh', '-c', 'show bgp summary json']
    end

    it 'reports failures from the runner' do
        failing = described_class.new(runner: ->(_) { ['boom', false] })

        expect(failing.test('/x')).to have_attributes(ok: false, output: 'boom')
    end

    it 'turns a missing binary into a failed result instead of raising' do
        result = described_class.new.test('/x') # frr-reload.py does not exist in the test container

        expect(result.ok).to be false
        expect(result.output).to match(/No such file/i)
    end

    describe '.system_runner' do
        let(:tmp) { Dir.mktmpdir }

        after { FileUtils.remove_entry(tmp) }

        # A killed orphan is re-parented to the container's PID 1 (rspec), which
        # never reaps it, so a zombie counts as gone.
        def alive?(pid)
            File.read("/proc/#{pid}/stat").split[2] != 'Z'
        rescue Errno::ENOENT
            false
        end

        def elapsed
            started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            yield
            Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        end

        it 'returns the combined output and the exit status' do
            runner = described_class.system_runner

            expect(runner.call(['sh', '-c', 'echo out; echo err >&2'])).to eq ["out\nerr\n", true]
            expect(runner.call(['sh', '-c', 'echo bad; exit 3'])).to eq ["bad\n", false]
        end

        it 'kills a command and its children after the timeout and reports it' do
            pids   = File.join(tmp, 'pids')
            runner = described_class.system_runner(timeout: 1)
            output = nil

            took = elapsed do
                output = runner.call(['sh', '-c', "sleep 60 & echo $$ $! > #{pids}; wait"])
            end

            expect(took).to be < 5
            expect(output).to eq ['sh -c sleep 60 & echo $$ $! > ' + pids + '; wait timed out after 1 s', false]
            File.read(pids).split.map(&:to_i).each { |pid| expect(alive?(pid)).to be false }
        end

        it 'does not wait for a background child that keeps running after the command exits' do
            pid_file = File.join(tmp, 'pid')
            runner   = described_class.system_runner(timeout: 10)

            took = elapsed { runner.call(['sh', '-c', "sleep 30 > /dev/null 2>&1 & echo $! > #{pid_file}"]) }

            expect(took).to be < 5
        ensure
            Process.kill('KILL', File.read(pid_file).to_i) if pid_file && File.exist?(pid_file)
        end

        it 'is built with the timeout given to the reloader' do
            expect(described_class).to receive(:system_runner).with(timeout: 7).and_call_original

            described_class.new(timeout: 7)
        end
    end
end
