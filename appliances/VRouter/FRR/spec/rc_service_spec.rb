# frozen_string_literal: true

require_relative 'support/quiet_logs'
require 'tmpdir'
require_relative '../main'

RSpec.describe Service::FRR do
    let(:scripts) { [] }

    before do
        allow(described_class).to receive(:bash) { |script| scripts << script; '' }
        allow(described_class).to receive(:puts) # toggle echoes the (stubbed) output
    end

    def toggle_scripts = scripts.map(&:to_s)

    def expect_detached(script, command)
        expect(script).to include(command)
        expect(script).to include('</dev/null')
        expect(script).to match(%r{>>\s*\S+\.log\s+2>&1})
    end

    {
        toggle:        { service: 'frr',            log: 'frr-rc.log' },
        toggle_poller: { service: 'one-frr-poller', log: 'frr-rc.log' }
    }.each do |method, meta|
        describe ".#{method}" do
            it "starts #{meta[:service]} detached from the capture pipes" do
                described_class.public_send(method, %i[restart])

                expect_detached(toggle_scripts.first, "rc-service #{meta[:service]} restart")
            end

            it "stops #{meta[:service]} detached and tolerates failure" do
                described_class.public_send(method, %i[stop])

                expect_detached(toggle_scripts.first, "rc-service #{meta[:service]} stop")
                expect(toggle_scripts.first).to match(/2>&1\s*\|\|:\s*\z/)
            end

            it "passes any other operation of #{meta[:service]} to rc-service detached" do
                described_class.public_send(method, %i[start])

                expect_detached(toggle_scripts.first, "rc-service #{meta[:service]} start")
            end

            it 'leaves the rc-update calls untouched' do
                described_class.public_send(method, %i[enable disable update])

                expect(toggle_scripts).to eq [
                    "rc-update add #{meta[:service]} default",
                    "rc-update del #{meta[:service]} default ||:",
                    'rc-update -u'
                ]
            end
        end
    end

    describe 'daemons started by rc-service' do
        let(:log) { File.join(Dir.mktmpdir, 'frr-rc.log') }
        let(:pidfile) { File.join(File.dirname(log), 'daemon.pid') }

        before do
            allow(described_class).to receive(:bash).and_call_original
            stub_const('Service::FRR::RC_LOG', log)
        end

        after do
            kill_daemon
            FileUtils.remove_entry File.dirname(log)
        end

        def kill_daemon
            Process.kill('KILL', File.read(pidfile).to_i) if File.exist?(pidfile)
        rescue Errno::ESRCH
            nil
        end

        def start_daemon(redirect) = bash("sleep 30 #{redirect} & echo $! > #{pidfile}")

        it 'would keep the helper waiting forever without the redirection' do
            helper = Thread.new { start_daemon('') }

            expect(helper.join(2)).to be_nil # still blocked on the inherited pipes
            kill_daemon
            expect(helper.join(5)).to eq helper # EOF at last, thread ends cleanly
        end

        it 'lets the helper return promptly with the redirection' do
            redirect = described_class.send(:rc_redirect)

            helper = Thread.new { start_daemon(redirect) }

            expect(helper.join(2)).to eq helper
            expect(File.read(pidfile).to_i).to be_positive
        end
    end
end
