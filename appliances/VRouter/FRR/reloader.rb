# frozen_string_literal: true

require 'tempfile'

module Service
module FRR
class Reloader
    RELOAD_PY = '/usr/lib/frr/frr-reload.py'
    TIMEOUT   = 60 # seconds; a wedged vtysh or daemon must not hang the poller
    WAIT_STEP = 0.05

    Result = Data.define(:ok, :output)

    # Runs a command bounded by `timeout` seconds. Output goes to a file, not a
    # pipe, so a leftover child cannot block us; on timeout the whole process
    # group is killed and reaped.
    def self.system_runner(timeout: TIMEOUT)
        ->(command) { execute(command, timeout) }
    end

    def self.execute(command, timeout)
        Tempfile.create('one-frr-cmd') do |out|
            pid = Process.spawn([command.first, command.first], *command.drop(1),
                                pgroup: true, in: File::NULL, %i[out err] => out)
            status = wait_bounded(pid, Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout)
            next ["#{command.join(' ')} timed out after #{timeout} s", false] if status.nil?

            out.rewind
            [out.read, status.success?]
        end
    rescue SystemCallError => e
        [e.message, false]
    end

    # The exit status, or nil after killing the process group at the deadline.
    def self.wait_bounded(pid, deadline)
        loop do
            _, status = Process.wait2(pid, Process::WNOHANG)
            return status if status
            break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

            sleep WAIT_STEP
        end
        kill_group pid
        nil
    end

    def self.kill_group(pid)
        Process.kill('KILL', -pid)
    rescue Errno::ESRCH, Errno::EPERM
        nil
    ensure
        Process.wait(pid)
    end

    def initialize(runner: nil, timeout: TIMEOUT)
        @runner = runner || self.class.system_runner(timeout: timeout)
    end

    def test(path)
        run [RELOAD_PY, '--test', '--stdout', path]
    end

    def reload(path)
        run [RELOAD_PY, '--reload', '--stdout', path]
    end

    # `commands` come from the sections; the result is informational only (the Applier ignores it).
    def soft_refresh(commands)
        results = commands.map { |command| run(command) }
        Result.new(ok: results.all?(&:ok), output: results.map(&:output).join)
    end

    def summary(command)
        run(command)
    end

    private

    def run(command)
        output, ok = @runner.call(command)
        Result.new(ok: ok, output: output)
    end
end
end
end
