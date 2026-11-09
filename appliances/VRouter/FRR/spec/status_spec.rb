# frozen_string_literal: true

require_relative 'support/quiet_logs'
require 'json'
require_relative '../status'
require_relative '../reporter'

RSpec.describe Service::FRR::Status do
    let(:summary) do
        JSON.generate('ipv4Unicast' => { 'peers' => {
            '10.0.0.2' => { 'state' => 'Established', 'pfxRcd' => 3, 'pfxSnt' => 2, 'peerUptimeMsec' => 123 },
            '10.0.0.3' => { 'state' => 'Active', 'pfxRcd' => 0, 'pfxSnt' => 0 }
        } })
    end

    it 'extracts state and prefix counts per neighbor, without uptime' do
        expect(described_class.neighbors(summary)).to eq(
            '10.0.0.2' => { state: 'Established', received: 3, advertised: 2 },
            '10.0.0.3' => { state: 'Active', received: 0, advertised: 0 }
        )
    end

    it 'lists the peers of both address families' do
        both = JSON.generate(
            'ipv4Unicast' => { 'peers' => { '10.0.0.2' => { 'state' => 'Established', 'pfxRcd' => 3, 'pfxSnt' => 2 } } },
            'ipv6Unicast' => { 'peers' => { 'fd77::21' => { 'state' => 'Active', 'pfxRcd' => 0, 'pfxSnt' => 0 } } }
        )

        expect(described_class.neighbors(both)).to eq(
            { '10.0.0.2' => { state: 'Established', received: 3, advertised: 2 },
              'fd77::21' => { state: 'Active', received: 0, advertised: 0 } }
        )
    end

    it 'formats an IPv6 neighbor in the OneGate-safe form and keeps the colons' do
        text = described_class.format_neighbors({ 'fd77::21' => { state: 'Established', received: 1, advertised: 2 } })

        expect(text).to eq 'fd77::21: Established rcv 1 snt 2'
        expect(described_class.sanitize(text)).to eq text
    end

    it 'returns no neighbors for empty or invalid output' do
        expect(described_class.neighbors('{}')).to eq({})
        expect(described_class.neighbors('not json')).to eq({})
    end

    it 'returns no neighbors for null JSON, empty array, or nil' do
        expect(described_class.neighbors('null')).to eq({})
        expect(described_class.neighbors('[]')).to eq({})
        expect(described_class.neighbors(nil)).to eq({})
    end

    it 'returns no neighbors when peers is an array instead of a hash' do
        peers_as_array = JSON.generate('ipv4Unicast' => { 'peers' => ['not', 'a', 'hash'] })
        expect(described_class.neighbors(peers_as_array)).to eq({})
    end

    it 'skips null peer entries and reports valid ones' do
        with_null_peer = JSON.generate('ipv4Unicast' => { 'peers' => {
            '10.0.0.2' => { 'state' => 'Established', 'pfxRcd' => 1, 'pfxSnt' => 1 },
            '10.0.0.3' => nil,
            '10.0.0.4' => { 'state' => 'Active', 'pfxRcd' => 0, 'pfxSnt' => 0 }
        } })
        result = described_class.neighbors(with_null_peer)
        expect(result).to eq(
            '10.0.0.2' => { state: 'Established', received: 1, advertised: 1 },
            '10.0.0.4' => { state: 'Active', received: 0, advertised: 0 }
        )
    end

    it 'formats neighbors on one line' do
        text = described_class.format_neighbors(described_class.neighbors(summary))

        expect(text).to eq '10.0.0.2: Established rcv 3 snt 2; 10.0.0.3: Active rcv 0 snt 0'
        expect(described_class.format_neighbors({})).to eq 'no neighbors'
    end

    it 'removes characters that would break the OpenNebula template and truncates' do
        text = described_class.sanitize(%(a "quoted"\nline \\ #{'x' * 400}))

        expect(text).not_to match(/["\\\n]/)
        expect(text.length).to eq 300
    end

    it 'replaces the characters OneGate rejects in a value' do
        expect(described_class.sanitize('a=b, [c] d')).to eq 'a:b; (c) d'
    end

    it 'never leaves = , [ ] inside a value of the template data' do
        messages = [
            %(rejected 2026-10-05T08:54:04Z invalid BGP configuration: ONEAPP_VNF_BGP_NEIGHBOR1_ASN must be an integer, got "abc"),
            'failed 2026-10-05T08:54:04Z password *** neighbor [x] a=b, c',
            '=,[]' * 100
        ]

        messages.each do |message|
            data = described_class.to_template(states: { 'BGP_STATE' => message }, apply: message)

            data.each_line do |line|
                value = line.chomp[/\A[A-Z_]+="(.*)"\z/, 1]
                expect(value).not_to be_nil
                expect(value).not_to match(/[=,\[\]"]/)
                expect(value.length).to be <= 300
            end
        end
    end

    it 'builds the template data' do
        data = described_class.to_template(states: { 'BGP_STATE' => 'a: Established' }, apply: 'applied 2026-10-01T10:00:00Z')

        expect(data).to eq %(BGP_STATE="a: Established"\nFRR_APPLY="applied 2026-10-01T10:00:00Z"\n)
    end

    it 'sanitizes every value for OneGate (= , [ ] replaced, quotes and newlines stripped)' do
        data = described_class.to_template(states: { 'BGP_STATE' => 'a=b,c[d]' }, apply: %(x"y\nz))

        expect(data).to eq %(BGP_STATE="a:b;c(d)"\nFRR_APPLY="x y z"\n)
    end

    it 'renders several states in the given order, before the apply line' do
        data = described_class.to_template(states: { 'BGP_STATE' => 'one', 'OSPF_STATE' => 'two' }, apply: 'none')

        expect(data).to eq %(BGP_STATE="one"\nOSPF_STATE="two"\nFRR_APPLY="none"\n)
    end

    it 'puts the time and a short message into the apply line' do
        line = described_class.apply_line(:rejected, 'bad ASN', Time.utc(2026, 10, 1, 10))

        expect(line).to eq 'rejected 2026-10-01T10:00:00Z bad ASN'
        expect(described_class.apply_line(:applied, '', Time.utc(2026, 10, 1, 10))).to eq 'applied 2026-10-01T10:00:00Z'
    end
end

RSpec.describe Service::FRR::Reporter do
    let(:sent) { [] }
    let(:onegate) do
        s = sent  # Capture sent as local variable for closure
        Object.new.tap { |o| o.define_singleton_method(:vm_update) { |data| s << data; '' } } # real OneGate: 200, empty body
    end
    let(:json) { '{"ipv4Unicast":{"peers":{"10.0.0.2":{"state":"Established","pfxRcd":1,"pfxSnt":1}}}}' }
    let(:reloader) { Struct.new(:json) { def summary(_command) = Service::FRR::Reloader::Result.new(ok: true, output: json) }.new(json) }
    let(:reporter) { described_class.new(onegate: onegate, reloader: reloader, clock: -> { Time.utc(2026, 10, 1) }) }

    it 'publishes both protocol states and the apply result in one update' do
        both = Object.new
        both.define_singleton_method(:summary) do |command|
            output = command.last.include?('ospf') ? File.read(File.join(__dir__, 'fixtures', 'ospf_neighbor.json')) : '{}'
            Service::FRR::Reloader::Result.new(ok: true, output: output)
        end

        described_class.new(onegate: onegate, reloader: both, clock: -> { Time.utc(2026, 10, 1) },
                            sections: [Service::FRR::Sections::Bgp, Service::FRR::Sections::Ospf]).publish

        expect(sent.size).to eq 1
        expect(sent.first).to eq %(BGP_STATE="no neighbors"\nOSPF_STATE="10.0.0.2: Full/DR eth1"\nFRR_APPLY="none"\n)
    end

    it 'does not ask for OSPF neighbors when the OSPF section is not given (BGP-only router)' do
        asked = []
        spy   = Object.new
        spy.define_singleton_method(:summary) do |command|
            asked << command
            Service::FRR::Reloader::Result.new(ok: true, output: '{}')
        end

        described_class.new(onegate: onegate, reloader: spy, clock: -> { Time.utc(2026, 10, 1) },
                            sections: [Service::FRR::Sections::Bgp]).publish

        expect(asked.flatten.join(' ')).not_to include('ospf')
    end

    it 'asks only the sections it was given' do
        asked = []
        spy   = Object.new
        spy.define_singleton_method(:summary) do |command|
            asked << command
            Service::FRR::Reloader::Result.new(ok: true, output: '{}')
        end

        described_class.new(onegate: onegate, reloader: spy, clock: -> { Time.utc(2026, 10, 1) }, sections: []).publish

        expect(asked).to eq []
        expect(sent.first).to eq %(FRR_APPLY="none"\n)
    end

    it 'publishes no BGP key for a reporter without the BGP section' do
        described_class.new(onegate: onegate, reloader: reloader, clock: -> { Time.utc(2026, 10, 1) }, sections: []).publish

        expect(sent.first).not_to include('BGP_STATE')
    end

    it 'asks the reloader for the status command of the BGP section' do
        asked = []
        spy   = Object.new
        spy.define_singleton_method(:summary) do |command|
            asked << command
            Service::FRR::Reloader::Result.new(ok: true, output: '{}')
        end

        described_class.new(onegate: onegate, reloader: spy, clock: -> { Time.utc(2026, 10, 1) },
                            sections: [Service::FRR::Sections::Bgp]).publish

        expect(asked).to eq [['vtysh', '-c', 'show bgp summary json']]
    end

    it 'publishes once and stays quiet while nothing changes' do
        reporter.publish
        reporter.publish

        expect(sent.size).to eq 1
        expect(sent.first).to include('BGP_STATE="10.0.0.2: Established rcv 1 snt 1"', 'FRR_APPLY="none"')
    end

    it 'publishes again after an apply result' do
        reporter.publish
        reporter.apply_result(Service::FRR::Reporter::Applied.new(:applied, '', nil))
        reporter.publish

        expect(sent.size).to eq 2
        expect(sent.last).to include('FRR_APPLY="applied 2026-10-01T00:00:00Z"')
    end

    it 'does nothing without OneGate' do
        described_class.new(onegate: nil, reloader: reloader).publish

        expect(sent).to be_empty
    end

    it 'does not resend after a success with an empty body' do
        log = sent
        ok = Object.new.tap { |o| o.define_singleton_method(:vm_update) { |data| log << data; '' } }
        rep = described_class.new(onegate: ok, reloader: reloader)

        3.times { rep.publish }

        expect(sent.size).to eq 1
    end

    context 'when OneGate answers with an error body' do
        let(:now)    { [Time.utc(2026, 10, 1)] }
        let(:clock)  { -> { now.first } }
        let(:bodies) { ['Internal server error'] }
        let(:flaky) do
            s = sent
            b = bodies
            Object.new.tap { |o| o.define_singleton_method(:vm_update) { |data| s << data; b.first } }
        end
        let(:reporter) { described_class.new(onegate: flaky, reloader: reloader, clock: clock, retry_delay: 60) }

        before { allow_any_instance_of(Object).to receive(:msg) }

        it 'does not retry before the delay' do
            reporter.publish
            now[0] += 59
            reporter.publish

            expect(sent.size).to eq 1
        end

        it 'retries after the delay and stops once it succeeds' do
            reporter.publish
            bodies.replace([''])
            now[0] += 60
            reporter.publish
            now[0] += 600
            reporter.publish

            expect(sent.size).to eq 2
        end

        it 'warns once per distinct body, without the values' do
            warnings = []
            allow_any_instance_of(Object).to receive(:msg) { |_, level, text| warnings << [level, text] }

            reporter.publish
            now[0] += 60
            reporter.publish
            bodies.replace(['Other error'])
            now[0] += 60
            reporter.publish

            expect(warnings.map(&:first)).to eq %i[warn warn]
            expect(warnings.map(&:last).join).not_to include('BGP_STATE', 'Established')
            expect(warnings.map(&:last)).to include(/Internal server error/, /Other error/)
        end
    end

    context 'when the OneGate request itself fails' do
        let(:now)    { [Time.utc(2026, 10, 1)] }
        let(:clock)  { -> { now.first } }
        let(:answers) { [nil] }
        let(:flaky) do
            s = sent
            a = answers
            Object.new.tap do |o|
                o.define_singleton_method(:vm_update) do |data|
                    s << data
                    raise a.first if a.first.is_a?(Class)

                    a.first
                end
            end
        end
        let(:reporter) { described_class.new(onegate: flaky, reloader: reloader, clock: clock, retry_delay: 60) }

        before { allow_any_instance_of(described_class).to receive(:msg) }

        it 'treats a nil answer as a failure: retries after the delay and sends again' do
            reporter.publish
            reporter.publish
            expect(sent.size).to eq 1

            now[0] += 60
            reporter.publish
            expect(sent.size).to eq 2
        end

        it 'counts only an empty string as sent' do
            reporter.publish
            answers.replace([''])
            now[0] += 60
            reporter.publish
            now[0] += 600
            reporter.publish

            expect(sent.size).to eq 2
        end

        it 'does not raise out of publish when vm_update raises, and retries later' do
            answers.replace([IOError])

            expect { reporter.publish }.not_to raise_error
            expect { reporter.publish }.not_to raise_error
            expect(sent.size).to eq 1

            answers.replace([''])
            now[0] += 60
            reporter.publish
            expect(sent.size).to eq 2
        end

        it 'warns once per distinct error, naming the class only' do
            warnings = []
            allow_any_instance_of(described_class).to receive(:msg) { |_, level, text| warnings << [level, text] }

            reporter.publish
            now[0] += 60
            reporter.publish
            answers.replace([IOError])
            now[0] += 60
            reporter.publish
            now[0] += 60
            reporter.publish

            expect(warnings.size).to eq 2
            expect(warnings.last.last).to include('IOError')
        end
    end

    it 'still publishes FRR_APPLY when a status command fails, marks that state unavailable and logs a warning' do
        failed_reloader = Struct.new(:json) do
            def summary(_command) = Service::FRR::Reloader::Result.new(ok: false, output: 'vtysh error')
        end.new(json)

        expect_any_instance_of(Object).to receive(:msg).with(:warn, /failed summary/).at_least(:once)

        reporter = described_class.new(onegate: onegate, reloader: failed_reloader)
        reporter.apply_result(Service::FRR::Reporter::Applied.new(status: :rejected, message: 'bad asn', config: nil))
        reporter.publish

        expect(sent.size).to eq 1
        expect(sent.first).to include('BGP_STATE="unavailable"', 'FRR_APPLY="rejected')
    end

    it 'warns once per outage of a status command, not on every poll, and again after a recovery' do
        down    = true
        flaky   = Struct.new(:json, :state) do
            def summary(_command) = Service::FRR::Reloader::Result.new(ok: !state.call, output: json)
        end.new(json, -> { down })
        warnings = []
        allow_any_instance_of(Object).to receive(:msg) { |_, level, text| warnings << text if level == :warn }
        reporter = described_class.new(onegate: onegate, reloader: flaky, sections: [Service::FRR::Sections::Bgp])

        3.times { reporter.publish }
        expect(warnings.grep(/BGP_STATE unavailable/).size).to eq 1

        down = false
        reporter.publish
        down = true
        reporter.publish
        expect(warnings.grep(/BGP_STATE unavailable/).size).to eq 2
    end

    it 'publishes the states that answer even when another status command fails' do
        mixed = Struct.new(:json) do
            def summary(command) = Service::FRR::Reloader::Result.new(ok: command.join.include?('bgp'), output: json)
        end.new(json)
        allow_any_instance_of(Object).to receive(:msg)

        described_class.new(onegate: onegate, reloader: mixed).publish

        expect(sent.first).to include('BGP_STATE="10.0.0.2: Established rcv 1 snt 1"', 'OSPF_STATE="unavailable"')
    end

    it 'publishes the real state once a failed summary recovers' do
        s = sent  # Capture sent as local variable for closure
        failed_reloader = Struct.new(:json) do
            def summary(_command) = Service::FRR::Reloader::Result.new(ok: false, output: 'vtysh error')
        end.new(json)

        allow_any_instance_of(Object).to receive(:msg)

        reporter_with_failed = described_class.new(onegate: onegate, reloader: failed_reloader, clock: -> { Time.utc(2026, 10, 1) })
        reporter_with_failed.publish

        # Now fix the reloader
        good_reloader = Struct.new(:json) { def summary(_command) = Service::FRR::Reloader::Result.new(ok: true, output: json) }.new(json)
        reporter_with_good = described_class.new(onegate: onegate, reloader: good_reloader, clock: -> { Time.utc(2026, 10, 1) })
        reporter_with_good.publish

        expect(sent.size).to eq 2
        expect(sent.first).to include('BGP_STATE="unavailable"')
        expect(sent.last).to include('BGP_STATE="10.0.0.2: Established rcv 1 snt 1"')
    end
end
