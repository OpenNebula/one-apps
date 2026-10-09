# frozen_string_literal: true

require_relative 'support/quiet_logs'
require 'tmpdir'
require_relative '../poller'
require_relative '../ha_state'
require_relative '../override_store'
require_relative 'support/fakes'

RSpec.describe Service::FRR::HaState do
    let(:path) { File.join(Dir.mktmpdir, 'ha-state') }

    it 'defaults to master when nothing was written' do
        expect(described_class.read(path)).to eq :master
    end

    it 'round-trips backup and master' do
        described_class.write(:backup, path)
        expect(described_class.read(path)).to eq :backup

        described_class.write(:master, path)
        expect(described_class.read(path)).to eq :master
    end

    it 'reads master when the state file cannot be read at all, instead of raising on every poll' do
        expect(described_class.read(Dir.mktmpdir)).to eq :master
    end

    it 'rejects an unknown state' do
        expect { described_class.write(:standby, path) }.to raise_error(ArgumentError)
    end

    it 'leaves no temporary file behind after a write' do
        described_class.write(:backup, path)

        expect(Dir.children(File.dirname(path))).to eq ['ha-state']
    end

    it 'keeps the previous state readable when a write fails' do
        described_class.write(:backup, path)
        allow(File).to receive(:rename).and_raise(Errno::ENOSPC)

        expect { described_class.write(:master, path) }.to raise_error(Errno::ENOSPC)
        expect(described_class.read(path)).to eq :backup
        expect(Dir.children(File.dirname(path))).to eq ['ha-state']
    end
end

RSpec.describe Service::FRR::Poller do
    let(:dir) { Dir.mktmpdir }
    let(:store) { Service::FRR::OverrideStore.new(File.join(dir, 'overrides.json')) }
    let(:p) { Service::FRR::Attributes::PREFIX }
    let(:context) { { "#{p}ASN" => '65010', "#{p}NEIGHBOR0_ASN" => '65100' } }
    let(:applier) { FakeApplier.new }
    let(:reporter) { FakeReporter.new }
    let(:onegate) { FakeOneGate.new({ "#{p}NEIGHBOR0_ASN" => '65200' }) }
    let(:ha) { [:master] }

    after { FileUtils.remove_entry(dir) }

    def poller(onegate: self.onegate)
        described_class.new(applier: applier, onegate: onegate, store: store, context: context,
                            ha_state: -> { ha.first }, reporter: reporter, sleeper: ->(_) {})
    end

    it 'applies the context merged with the user-template overrides' do
        poller.tick

        attrs, state = applier.calls.last
        expect(attrs).to include("#{p}ASN" => '65010', "#{p}NEIGHBOR0_ASN" => '65200')
        expect(state).to eq :master
    end

    it 'applies the context value of a boot-only key and warns once that the user template one is ignored' do
        warnings = []
        allow_any_instance_of(described_class).to receive(:msg) { |_, level, text| warnings << text if level == :warn }
        onegate.template = { "#{p}ASN" => '64999', "#{p}NEIGHBOR0_ASN" => '65200' }
        subject = poller

        subject.tick
        subject.tick

        expect(applier.calls.last.first).to include("#{p}ASN" => '65010')
        expect(warnings.grep(/boot-only/).size).to eq 1
        expect(warnings.grep(/boot-only/).first).to include("#{p}ASN")
        expect(warnings.grep(/boot-only/).first).not_to include('64999')
    end

    it 'tells FRR_APPLY which boot-only keys of the user template were ignored, and applies when one appears' do
        subject = poller
        subject.tick
        onegate.template = onegate.template.merge("#{p}ASN" => '64999')

        expect(subject.tick).to eq :applied
        expect(reporter.results.last.message).to include("ignored boot-only #{p}ASN in the user template")
        expect(reporter.results.last.message).not_to include('64999')
        expect(subject.tick).to eq :unchanged
    end

    it 'does nothing while neither the attributes nor the HA state change' do
        subject = poller
        subject.tick

        expect(subject.tick).to eq :unchanged
        expect(applier.calls.size).to eq 1
    end

    it 'applies again when an override changes' do
        subject = poller
        subject.tick
        onegate.template = { "#{p}NEIGHBOR0_ASN" => '65300' }

        subject.tick

        expect(applier.calls.size).to eq 2
    end

    it 'applies again when the HA state flips' do
        subject = poller
        subject.tick
        ha[0] = :backup

        subject.tick

        expect(applier.calls.last.last).to eq :backup
    end

    it 'does not react to the status attributes it writes itself' do
        subject = poller
        subject.tick
        onegate.template = onegate.template.merge('BGP_STATE' => 'x=Established', 'FRR_APPLY' => 'applied')

        expect(subject.tick).to eq :unchanged
    end

    it 'keeps the last known overrides when OneGate is unreachable' do
        poller.tick
        offline = FakeOneGate.new(nil)

        poller(onegate: offline).tick

        expect(applier.calls.last.first).to include("#{p}NEIGHBOR0_ASN" => '65200')
    end

    it 'still applies the fetched overrides when they cannot be remembered on disk' do
        allow(store).to receive(:save).and_raise(Errno::ENOSPC)

        expect { poller.tick }.not_to raise_error

        expect(applier.calls.last.first).to include("#{p}NEIGHBOR0_ASN" => '65200')
    end

    it 'works from the context alone without OneGate' do
        poller(onegate: nil).tick

        expect(applier.calls.last.first).to include("#{p}NEIGHBOR0_ASN" => '65100')
    end

    it 'retries a failed apply later but never a config that did not validate' do
        failing = FakeApplier.new(%i[failed rejected])
        subject = described_class.new(applier: failing, onegate: onegate, store: store, context: context,
                                      ha_state: -> { :master }, reporter: reporter, sleeper: ->(_) {})

        expect(subject.tick).to eq :failed
        expect(subject.tick).to eq :waiting
        expect(subject.tick).to eq :rejected
        expect(subject.tick).to eq :unchanged
        expect(failing.calls.size).to eq 2
    end

    describe 'retrying with backoff' do
        # The real Applier returns a config with :failed and with a rejected `frr-reload --test`.
        def retrying(status)
            Object.new.tap do |o|
                calls = []
                o.define_singleton_method(:calls) { calls }
                o.define_singleton_method(:call) do |attrs, ha_state:|
                    calls << [attrs, ha_state]
                    Service::FRR::Applier::Result.new(status: status, message: '', config: Struct.new(:poll_interval).new(30))
                end
            end
        end

        def poller_for(applier)
            described_class.new(applier: applier, onegate: onegate, store: store, context: context,
                                ha_state: -> { :master }, reporter: reporter, sleeper: ->(_) {})
        end

        it 'waits longer after every failed apply, up to 19 ticks, and keeps retrying' do
            failing = retrying(:failed)
            subject = poller_for(failing)
            applies = []
            80.times { |tick| applies << tick + 1 if (before = failing.calls.size) && subject.tick && failing.calls.size > before }

            expect(applies.first(6)).to eq [1, 3, 7, 15, 31, 51]
        end

        it 'retries a rejected frr-reload --test three times, then waits for a change' do
            rejecting = retrying(:rejected)
            subject   = poller_for(rejecting)

            200.times { subject.tick }

            expect(rejecting.calls.size).to eq 4
        end

        it 'applies at once when an attribute changes while it is waiting' do
            failing = retrying(:failed)
            subject = poller_for(failing)
            subject.tick
            expect(subject.tick).to eq :waiting

            onegate.template = { "#{p}NEIGHBOR0_ASN" => '65300' }

            expect(subject.tick).to eq :failed
            expect(failing.calls.size).to eq 2
        end

        it 'stops waiting once a retry succeeds' do
            statuses = FakeApplier.new(%i[failed applied])
            subject  = described_class.new(applier: statuses, onegate: onegate, store: store, context: context,
                                           ha_state: -> { :master }, reporter: reporter, sleeper: ->(_) {})

            results = Array.new(6) { subject.tick }

            expect(results).to eq %i[failed waiting applied unchanged unchanged unchanged]
        end
    end

    it 'reports an apply that raises as failed instead of raising out of the tick' do
        raising = FakeApplier.new
        allow(raising).to receive(:call).and_raise(ArgumentError, 'neighbor 10.0.0.2 password s3cretpw')
        subject = described_class.new(applier: raising, onegate: onegate, store: store, context: context,
                                      ha_state: -> { :master }, reporter: reporter, sleeper: ->(_) {})

        expect(subject.tick).to eq :failed
        expect(reporter.results.last.status).to eq :failed
        expect(reporter.results.last.message).to include('ArgumentError')
        expect(reporter.results.last.message).not_to include('s3cretpw')
    end

    it 'reports every apply result and publishes the state on every tick' do
        subject = poller
        subject.tick
        subject.tick

        expect(reporter.results.size).to eq 1
        expect(reporter.publishes).to eq 2
    end

    describe 'poll interval' do
        let(:key) { "#{p}POLL_INTERVAL" }
        let(:context) { { "#{p}ASN" => '65010', key => '90' } }

        def sleep_after(applier:, onegate: self.onegate)
            described_class.new(applier: applier, onegate: onegate, store: store, context: context,
                                ha_state: -> { :master }, reporter: reporter, sleeper: ->(_) {})
        end

        def interval_applier(*intervals)
            queue = intervals.dup
            Object.new.tap do |o|
                o.define_singleton_method(:call) do |_attrs, ha_state:|
                    interval = queue.size > 1 ? queue.shift : queue.first
                    config   = interval && Struct.new(:poll_interval).new(interval)
                    Service::FRR::Applier::Result.new(status: interval ? :applied : :rejected, message: '', config: config)
                end
            end
        end

        it 'uses the context interval before any apply' do
            expect(poller.sleep_interval).to eq 90
        end

        it 'keeps the context interval when the first apply is rejected' do
            subject = sleep_after(applier: interval_applier(nil))

            expect(subject.tick).to eq :rejected
            expect(subject.sleep_interval).to eq 90
        end

        it 'keeps the last valid interval when a later apply is rejected or raises' do
            raising = interval_applier(45)
            subject = sleep_after(applier: raising)
            subject.tick
            allow(raising).to receive(:call).and_raise(ArgumentError, 'boom')
            onegate.template = onegate.template.merge("#{p}NEIGHBOR0_ASN" => '65011')

            expect(subject.tick).to eq :failed
            expect(subject.sleep_interval).to eq 45
        end

        it 'takes a different interval from a later successful apply' do
            subject = sleep_after(applier: interval_applier(nil, 120))
            subject.tick
            onegate.template = onegate.template.merge("#{p}NEIGHBOR0_ASN" => '65011')
            subject.tick

            expect(subject.sleep_interval).to eq 120
        end

        # The real Applier returns :rejected and :failed with a non-nil config.
        def status_applier(*steps)
            queue = steps.dup
            Object.new.tap do |o|
                o.define_singleton_method(:call) do |_attrs, ha_state:|
                    status, interval = queue.size > 1 ? queue.shift : queue.first
                    Service::FRR::Applier::Result.new(status: status, message: '',
                                                      config: Struct.new(:poll_interval).new(interval))
                end
            end
        end

        %i[rejected failed].each do |status|
            it "keeps the last valid interval when a later apply is #{status} with a config" do
                subject = sleep_after(applier: status_applier([:applied, 45], [status, 120]))
                subject.tick
                onegate.template = onegate.template.merge("#{p}NEIGHBOR0_ASN" => '65011')
                subject.tick

                expect(subject.sleep_interval).to eq 45
            end
        end

        it 'updates to the interval of a later applied config' do
            subject = sleep_after(applier: status_applier([:applied, 45], [:rejected, 120], [:applied, 60]))
            subject.tick
            %w[65011 65012].each do |asn|
                onegate.template = onegate.template.merge("#{p}NEIGHBOR0_ASN" => asn)
                subject.tick
            end

            expect(subject.sleep_interval).to eq 60
        end

        { '1_0' => 10, ' 10 ' => 10 }.each do |raw, expected|
            it "reads the context value #{raw.inspect} like Config.integer does" do
                context[key] = raw

                expect(poller.sleep_interval).to eq expected
            end
        end

        ['abc', '4', '3601', '', '30 s'].each do |bad|
            it "falls back to 30 for the context value #{bad.inspect}" do
                context[key] = bad

                expect { poller }.not_to raise_error
                expect(poller.sleep_interval).to eq 30
            end
        end

        it 'falls back to 30 without a context value' do
            context.delete(key)

            expect(poller.sleep_interval).to eq 30
        end
    end

    describe 'static routes' do
        let(:routes) { 'ONEAPP_VNF_STATIC_ROUTES' }
        let(:context) { { routes => '1.1.1.1/32 via 10.0.0.1' } }
        let(:onegate) { FakeOneGate.new({}) }

        it 'applies the context routes when the user template has none' do
            poller.tick

            expect(applier.calls.last.first).to eq(routes => '1.1.1.1/32 via 10.0.0.1')
        end

        it 'applies a route added live in the user template' do
            subject = poller
            subject.tick
            onegate.template = { routes => '1.1.1.1/32 via 10.0.0.1, 2.2.2.2/32 via 10.0.0.1' }

            subject.tick

            expect(applier.calls.size).to eq 2
            expect(applier.calls.last.first[routes]).to include('2.2.2.2/32')
        end

        it 'applies NONE from the user template and keeps it across a restart' do
            onegate.template = { routes => 'NONE' }
            poller.tick

            poller(onegate: FakeOneGate.new(nil)).tick

            expect(applier.calls.last.first[routes]).to eq 'NONE'
        end

        it 'goes back to the context routes when the override is removed' do
            subject = poller
            onegate.template = { routes => 'NONE' }
            subject.tick
            onegate.template = {}

            subject.tick

            expect(applier.calls.last.first[routes]).to eq '1.1.1.1/32 via 10.0.0.1'
        end
    end

    describe '#run' do
        let(:stop) { Class.new(Exception) } # rubocop:disable Lint/InheritException

        def runner(sleeps)
            sleeper = lambda do |s|
                sleeps << s
                raise stop if sleeps.size >= 3
            end
            described_class.new(applier: applier, onegate: onegate, store: store, context: context,
                                ha_state: -> { :master }, reporter: reporter, sleeper: sleeper)
        end

        it 'propagates Interrupt immediately without sleeping' do
            sleeps  = []
            subject = runner(sleeps)
            allow(subject).to receive(:tick).and_raise(Interrupt)

            expect { subject.run }.to raise_error(Interrupt)
            expect(sleeps).to be_empty
        end

        it 'propagates SignalException immediately without sleeping' do
            sleeps  = []
            subject = runner(sleeps)
            allow(subject).to receive(:tick).and_raise(SignalException, 'TERM')

            expect { subject.run }.to raise_error(SignalException)
            expect(sleeps).to be_empty
        end

        # Runs the loop for `count` sleeps; `each_sleep` may change the world between ticks.
        def sleeps_of(count, onegate:, each_sleep: ->(_n) {})
            sleeps  = []
            sleeper = lambda do |s|
                sleeps << s
                raise stop if sleeps.size >= count

                each_sleep.call(sleeps.size)
            end
            described_class.new(applier: applier, onegate: onegate, store: store, context: context,
                                ha_state: -> { :master }, reporter: reporter, sleeper: sleeper).then do |subject|
                expect { subject.run }.to raise_error(stop)
            end
            sleeps
        end

        it 'doubles the sleep while OneGate does not answer, up to a cap, and does not publish' do
            sleeps = sleeps_of(8, onegate: FakeOneGate.new(nil))

            expect(sleeps).to eq [30, 60, 120, 240, 480, 600, 600, 600]
            expect(reporter.publishes).to eq 0
        end

        it 'goes back to the configured interval and publishes once OneGate answers again' do
            offline = FakeOneGate.new(nil)
            back    = ->(n) { offline.template = { "#{p}NEIGHBOR0_ASN" => '65200' } if n == 3 }

            sleeps = sleeps_of(5, onegate: offline, each_sleep: back)

            expect(sleeps).to eq [30, 60, 120, 30, 30]
            expect(reporter.publishes).to eq 2
        end

        context 'when the OneGate client raises' do
            let(:broken) { FakeOneGate.new({ "#{p}NEIGHBOR0_ASN" => '65200' }).tap { |o| allow(o).to receive(:vm_show).and_raise(IOError, 'HTTP session not yet started') } }

            it 'backs off like for a nil answer, up to the cap, and does not publish' do
                sleeps = sleeps_of(8, onegate: broken)

                expect(sleeps).to eq [30, 60, 120, 240, 480, 600, 600, 600]
                expect(reporter.publishes).to eq 0
            end

            it 'keeps applying the last known overrides' do
                store.save("#{p}NEIGHBOR0_ASN" => '65200')

                sleeps_of(2, onegate: broken)

                expect(applier.calls.last.first).to include("#{p}NEIGHBOR0_ASN" => '65200')
            end

            it 'does not let the exception escape tick' do
                subject = poller(onegate: broken)

                expect { subject.tick }.not_to raise_error
                expect(subject.sleep_interval).to eq 30
                subject.tick
                expect(subject.sleep_interval).to eq 60
            end

            it 'warns once per outage with the error class only' do
                warnings = []
                allow_any_instance_of(described_class).to receive(:msg) { |_, level, text| warnings << text if level == :warn }

                sleeps_of(4, onegate: broken)

                expect(warnings.size).to eq 1
                expect(warnings.first).to include('IOError')
                expect(warnings.first).not_to include('HTTP session')
            end
        end

        it 'does not back off without a OneGate endpoint' do
            expect(sleeps_of(3, onegate: nil)).to eq [30, 30, 30]
        end

        it 'warns only once while OneGate stays unreachable' do
            warnings = []
            allow_any_instance_of(described_class).to receive(:msg) { |_, level, text| warnings << text if level == :warn }

            sleeps_of(4, onegate: FakeOneGate.new(nil))

            expect(warnings.size).to eq 1
        end

        it 'sleeps once per iteration and keeps looping after a StandardError' do
            sleeps  = []
            subject = runner(sleeps)
            allow(subject).to receive(:tick).and_raise(StandardError, 'boom')

            expect { subject.run }.to raise_error(stop)
            expect(sleeps.size).to eq 3
        end
    end
end
