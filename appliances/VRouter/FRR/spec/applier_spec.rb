# frozen_string_literal: true

require_relative 'support/quiet_logs'
require_relative 'support/bgp_config'
require 'tmpdir'
require_relative '../applier'
require_relative '../override_store'
require_relative 'support/fakes'

RSpec.describe Service::FRR::OverrideStore do
    let(:dir) { Dir.mktmpdir }
    let(:store) { described_class.new(File.join(dir, 'overrides.json')) }

    after { FileUtils.remove_entry(dir) }

    it 'returns an empty hash when nothing was saved' do
        expect(store.load).to eq({})
    end

    it 'round-trips overrides' do
        store.save('ONEAPP_VNF_BGP_ASN' => '65010')

        expect(described_class.new(File.join(dir, 'overrides.json')).load).to eq('ONEAPP_VNF_BGP_ASN' => '65010')
    end

    it 'writes the file 0600 in a 0700 directory' do
        path = File.join(dir, 'state', 'overrides.json')

        described_class.new(path).save('ONEAPP_VNF_BGP_NEIGHBOR0_PASSWORD' => 'x')

        expect(File.stat(path).mode & 0o777).to eq 0o600
        expect(File.stat(File.dirname(path)).mode & 0o777).to eq 0o700
    end

    it 'ignores a corrupt file instead of failing' do
        File.write(File.join(dir, 'overrides.json'), '{broken')

        expect(store.load).to eq({})
    end

    it 'ignores valid JSON that is not an object' do
        ['"x"', '[1]', 'null', '3'].each do |junk|
            File.write(File.join(dir, 'overrides.json'), junk)

            expect(store.load).to eq({})
        end
    end
end

RSpec.describe Service::FRR::Applier do
    let(:dir) { Dir.mktmpdir }
    let(:p) { Service::FRR::Attributes::PREFIX }
    let(:attrs) do
        {
            "#{p}ENABLED" => 'YES', "#{p}ASN" => '65010', "#{p}ROUTER_ID" => '10.0.0.1',
            "#{p}NEIGHBOR0_ADDRESS" => '10.0.0.2', "#{p}NEIGHBOR0_ASN" => '65100'
        }
    end

    after { FileUtils.remove_entry(dir) }

    def applier(reloader, conf_writer: nil)
        described_class.new(reloader: reloader, dir: dir, hostname: 'vr1', default_router_id: nil,
                            lock_path: File.join(dir, 'lock'), conf_writer: conf_writer)
    end

    it 'scrubs a password out of a validation message, like every other message that leaves the router' do
        allow(Service::FRR::Config).to receive(:parse_frr)
            .and_raise(Service::FRR::ConfigError.new(['neighbor 10.0.0.2 password s3cretpw is wrong']))

        result = applier(FakeReloader.new).call(attrs)

        expect(result.status).to eq :rejected
        expect(result.message).not_to include('s3cretpw')
        expect(result.message).to include('neighbor 10.0.0.2')
    end

    describe 'keeping frr.conf in step with the running config' do
        it 'hands the applied config to the writer, so a restart of FRR keeps the live changes' do
            written = []

            result = applier(FakeReloader.new, conf_writer: ->(content) { written << content }).call(attrs)

            expect(result.status).to eq :applied
            expect(written).to eq [File.read(File.join(dir, 'candidate.conf'))]
            expect(written.first).to include('router bgp 65010')
        end

        it 'does not touch frr.conf when the config is rejected or the reload fails' do
            written = []
            writer  = ->(content) { written << content }

            applier(FakeReloader.new(test: false), conf_writer: writer).call(attrs)
            applier(FakeReloader.new(reload: [false]), conf_writer: writer).call(attrs)

            expect(written).to be_empty
        end

        it 'stays applied and says so when frr.conf cannot be written (the running config is right)' do
            result = applier(FakeReloader.new, conf_writer: ->(_) { raise Errno::ENOSPC }).call(attrs)

            expect(result.status).to eq :applied
            expect(result.message).to include('could not update frr.conf')
        end

        it 'works without a writer' do
            expect(applier(FakeReloader.new).call(attrs).status).to eq :applied
        end
    end

    def last_good = File.read(File.join(dir, 'last-good.conf'))

    it 'tests, reloads and soft-refreshes a valid candidate, then keeps it as last-good' do
        reloader = FakeReloader.new

        result = applier(reloader).call(attrs)

        expect(result.status).to eq :applied
        expect(reloader.calls.map(&:first)).to eq %i[test reload soft_refresh]
        expect(last_good).to include('router bgp 65010')
    end

    it 'hands the reloader the soft refresh commands of the BGP section' do
        reloader = FakeReloader.new

        applier(reloader).call(attrs)

        expect(reloader.calls.last).to eq [
            :soft_refresh,
            [['vtysh', '-c', 'clear bgp ipv4 unicast * soft'], ['vtysh', '-c', 'clear bgp ipv6 unicast * soft']]
        ]
    end

    it 'rejects invalid attributes without touching FRR' do
        reloader = FakeReloader.new

        result = applier(reloader).call(attrs.merge("#{p}ASN" => 'abc'))

        expect(result.status).to eq :rejected
        expect(result.message).to include("#{p}ASN must be an integer")
        expect(reloader.calls).to be_empty
    end

    it 'rejects a candidate that fails frr-reload --test and does not reload' do
        reloader = FakeReloader.new(test: false)

        result = applier(reloader).call(attrs)

        expect(result.status).to eq :rejected
        expect(reloader.calls.map(&:first)).to eq [:test]
        expect(File.exist?(File.join(dir, 'last-good.conf'))).to be false
    end

    it 'restores the last-good config when a reload fails' do
        reloader = FakeReloader.new(reload: [true, false, true])
        subject  = applier(reloader)
        subject.call(attrs)

        result = subject.call(attrs.merge("#{p}NEIGHBOR1_ADDRESS" => '10.0.0.3', "#{p}NEIGHBOR1_ASN" => '65200'))

        expect(result.status).to eq :failed
        expect(result.message).to include('last-good config restored')
        expect(reloader.calls.select { |c| c.first == :reload }.last.last).to eq File.join(dir, 'last-good.conf')
        expect(last_good).not_to include('10.0.0.3')
    end

    it 'ignores a runtime change of the local ASN and router-id (boot-only)' do
        subject = applier(FakeReloader.new)
        subject.call(attrs)

        result = subject.call(attrs.merge("#{p}ASN" => '65999', "#{p}ROUTER_ID" => '10.0.0.9'))

        expect(result.status).to eq :applied
        expect(result.message).to eq 'ignored runtime change of asn, router_id ' \
                                     '(boot-only: set in the VM context, then re-context or reboot)'
        expect(last_good).to include('router bgp 65010', 'bgp router-id 10.0.0.1')
        expect(last_good).not_to include('65999')
    end

    it 'remembers the boot-only values across instances (hook process vs poller process)' do
        applier(FakeReloader.new).call(attrs)

        result = applier(FakeReloader.new).call(attrs.merge("#{p}ASN" => '65999'))

        expect(result.message).to include('boot-only')
    end

    it 'never puts a neighbor password into a result message' do
        reloader = FakeReloader.new(test: false, test_output: 'neighbor 10.0.0.2 password s3cretpw')

        result = applier(reloader).call(attrs.merge("#{p}NEIGHBOR0_PASSWORD" => 's3cretpw'))

        expect(result.message).not_to include('s3cretpw')
        expect(result.message).to include('***')
    end

    it 'turns a hostname the renderer refuses into a failed result instead of raising' do
        reloader = FakeReloader.new
        subject  = described_class.new(reloader: reloader, dir: dir, hostname: "vr1\nrouter bgp 1",
                                       default_router_id: nil, lock_path: File.join(dir, 'lock'))

        result = nil
        expect { result = subject.call(attrs) }.not_to raise_error

        expect(result.status).to eq :failed
        expect(result.message).to include('could not render')
        expect(reloader.calls).to be_empty
    end

    describe 'scrubbing secrets from messages' do
        let(:old_pw) { attrs.merge("#{p}NEIGHBOR0_PASSWORD" => 'Old5ecret') }
        let(:new_pw) { attrs.merge("#{p}NEIGHBOR0_PASSWORD" => 'N3wsecret') }
        let(:output) do
            "Executing: no neighbor 10.0.0.2 password Old5ecret\nline: neighbor 10.0.0.2 password N3wsecret\n" \
                "vtysh: Old5ecret rejected; also PASSWORD 7 Other\n"
        end

        def expect_scrubbed(message)
            expect(message).not_to include('Old5ecret', 'N3wsecret', 'Other')
            expect(message).to include('password ***')
        end

        it 'scrubs the previous password from a failed reload and its rollback' do
            subject = applier(FakeReloader.new(reload: [true, false, true], reload_output: output))
            subject.call(old_pw)

            result = subject.call(new_pw)

            expect(result.status).to eq :failed
            expect(result.message).to include('last-good config restored')
            expect_scrubbed result.message
        end

        it 'scrubs the previous password from a frr-reload --test rejection' do
            subject = applier(FakeReloader.new)
            subject.call(old_pw)
            rejecting = applier(FakeReloader.new(test: false, test_output: output))

            result = rejecting.call(new_pw)

            expect(result.status).to eq :rejected
            expect_scrubbed result.message
        end

        it 'leaves validation messages unchanged' do
            bad      = new_pw.merge("#{p}ASN" => 'abc')
            expected = begin
                parse_bgp(bad, default_router_id: nil)
            rescue Service::FRR::ConfigError => e
                e.message
            end

            expect(applier(FakeReloader.new).call(bad).message).to eq expected
        end
    end

    it 'fails quickly instead of hanging when another process holds the apply lock' do
        reloader = FakeReloader.new
        subject  = described_class.new(reloader: reloader, dir: dir, hostname: 'vr1', default_router_id: nil,
                                       lock_path: File.join(dir, 'lock'), lock_timeout: 0.5)
        holder = File.open(File.join(dir, 'lock'), File::CREAT | File::RDWR)
        holder.flock(File::LOCK_EX)

        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result  = subject.call(attrs)

        expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 3
        expect(result.status).to eq :failed
        expect(result.message).to eq 'could not acquire the apply lock within 0.5 s'
        expect(reloader.calls).to be_empty

        holder.close
        expect(subject.call(attrs).status).to eq :applied
    ensure
        holder&.close unless holder&.closed?
    end

    it 'keeps candidate, last-good and the pin private: files 0600 in a 0700 directory' do
        state = File.join(dir, 'state')
        FileUtils.mkdir_p state
        File.chmod 0o755, state
        File.write File.join(state, 'candidate.conf.tmp'), 'stale'
        File.chmod 0o644, File.join(state, 'candidate.conf.tmp')
        subject = described_class.new(reloader: FakeReloader.new, dir: state, hostname: 'vr1', default_router_id: nil,
                                      lock_path: File.join(dir, 'lock'))

        expect(subject.call(attrs.merge("#{p}NEIGHBOR0_PASSWORD" => 's3cretpw')).status).to eq :applied

        expect(File.stat(state).mode & 0o777).to eq 0o700
        %w[candidate.conf last-good.conf boot.json].each do |name|
            expect(File.stat(File.join(state, name)).mode & 0o777).to eq(0o600), name
        end
    end

    it 'uses the backup profile when asked' do
        applier(FakeReloader.new).call(attrs, ha_state: :backup)

        expect(last_good).to include('set as-path prepend 65010 65010 65010')
    end

    def pin_path = File.join(dir, 'boot.json')

    it 'does not pin when the first apply is rejected by frr-reload --test' do
        applier(FakeReloader.new(test: false)).call(attrs)

        expect(File.exist?(pin_path)).to be false
    end

    it 'does not pin when the first reload fails, so a later apply defines the pin' do
        applier(FakeReloader.new(reload: [false])).call(attrs)
        expect(File.exist?(pin_path)).to be false

        applier(FakeReloader.new).call(attrs.merge("#{p}ASN" => '65777'))
        result = applier(FakeReloader.new).call(attrs)

        expect(JSON.parse(File.read(pin_path))['asn']).to eq 65_777
        expect(result.message).to include('boot-only')
    end

    ['{broken', '[]'].each do |junk|
        it "treats a #{junk} boot.json as no pin and re-pins after a successful apply" do
            File.write(pin_path, junk)

            result = applier(FakeReloader.new).call(attrs)

            expect(result.status).to eq :applied
            expect(JSON.parse(File.read(pin_path))).to include('asn' => 65_010)
        end
    end

    it 'writes the pin atomically' do
        config = parse_bgp(attrs, default_router_id: nil)

        described_class.write_pin(dir, config)

        expect(Dir.children(dir)).to eq ['boot.json']
    end

    it 'honors a boot.json that holds only the BGP values' do
        File.write(File.join(dir, 'boot.json'), '{"asn":65010,"router_id":"10.0.0.1"}')

        result = applier(FakeReloader.new).call(attrs.merge("#{p}ASN" => '65099'))

        expect(result.status).to eq :applied
        expect(result.message).to include('ignored runtime change of asn')
        expect(result.config.section(:bgp).asn).to eq 65_010
    end

    it 'does not blank a value the pin file does not have' do
        File.write(File.join(dir, 'boot.json'), '{"asn":65010}')

        result = applier(FakeReloader.new).call(attrs.merge("#{p}ROUTER_ID" => '10.0.0.9'))

        expect(result.status).to eq :applied
        expect(result.config.section(:bgp).router_id).to eq '10.0.0.9'
        expect(result.message).to be_empty
    end

    describe 'with BGP and OSPF together' do
        let(:o) { 'ONEAPP_VNF_OSPF_' }
        let(:both) do
            attrs.merge("#{o}ENABLED" => 'YES', "#{o}ROUTER_ID" => '10.0.0.5', "#{o}INTERFACE0_NAME" => 'eth1',
                        "#{o}INTERFACE0_PASSWORD" => 'OLDSECRET')
        end

        it 'ignores a runtime change of the OSPF router-id, reports only that one, and leaves BGP quiet' do
            subject = applier(FakeReloader.new)
            subject.call(both)

            result = subject.call(both.merge("#{o}ROUTER_ID" => '10.0.0.77'))

            expect(result.status).to eq :applied
            expect(result.message).to include('ignored runtime change of ospf_router_id')
            expect(result.message).not_to include('asn')
            expect(result.config.section(:ospf).router_id).to eq '10.0.0.5'
            expect(JSON.parse(File.read(File.join(dir, 'boot.json')))).to eq(
                'asn' => 65_010, 'router_id' => '10.0.0.1', 'ospf_router_id' => '10.0.0.5'
            )
        end

        it 'keeps the BGP message exactly as it was when only BGP changes' do
            subject = applier(FakeReloader.new)
            subject.call(both)

            result = subject.call(both.merge("#{p}ASN" => '65099'))

            expect(result.message).to eq 'ignored runtime change of asn (boot-only: set in the VM context, then re-context or reboot)'
        end

        it 'does not blank the OSPF router-id when the pin file is from a BGP-only boot' do
            File.write(File.join(dir, 'boot.json'), '{"asn":65010,"router_id":"10.0.0.1"}')

            result = applier(FakeReloader.new).call(both)

            expect(result.status).to eq :applied
            expect(result.message).to be_empty
            expect(result.config.section(:ospf).router_id).to eq '10.0.0.5'
        end

        it 'completes a pin file that lacks the OSPF router-id and keeps the values it has' do
            File.write(File.join(dir, 'boot.json'), '{"asn":65010,"router_id":"10.0.0.1"}')

            applier(FakeReloader.new).call(both.merge("#{p}ASN" => '65099'))

            expect(JSON.parse(File.read(File.join(dir, 'boot.json')))).to eq(
                'asn' => 65_010, 'router_id' => '10.0.0.1', 'ospf_router_id' => '10.0.0.5'
            )
        end

        it 'masks the MD5 key that was just removed as well as the new one in a failed apply' do
            reloader = FakeReloader.new(
                reload: [true, false],
                reload_output: 'no ip ospf message-digest-key 1 md5 OLDSECRET ip ospf message-digest-key 1 md5 NEWSECRET'
            )
            subject = applier(reloader)
            subject.call(both)

            result = subject.call(both.merge("#{o}INTERFACE0_PASSWORD" => 'NEWSECRET'))

            expect(result.status).to eq :failed
            expect(result.message).to include('md5 ***')
            expect(result.message).not_to include('OLDSECRET')
            expect(result.message).not_to include('NEWSECRET')
        end
    end

    it 'fails with context and keeps last-good intact when the last-good write hits ENOSPC' do
        subject = applier(FakeReloader.new)
        subject.call(attrs)
        before = last_good
        allow(File).to receive(:rename).and_wrap_original do |orig, from, to|
            raise Errno::ENOSPC if to.end_with?('last-good.conf')

            orig.call(from, to)
        end

        result = subject.call(attrs.merge("#{p}NEIGHBOR0_ASN" => '65101'))

        expect(result.status).to eq :failed
        expect(result.message).to include('could not write last-good config')
        expect(last_good).to eq before
    end

    it 'fails with context when the candidate cannot be written' do
        allow(File).to receive(:write).and_wrap_original do |orig, path, *rest|
            raise Errno::ENOSPC if path.to_s.end_with?('candidate.conf.tmp')

            orig.call(path, *rest)
        end

        result = applier(FakeReloader.new).call(attrs)

        expect(result.status).to eq :failed
        expect(result.message).to include('could not write candidate config')
    end

    it 'reports when the restore of last-good ALSO fails' do
        subject = applier(FakeReloader.new(reload: [true, false, false]))
        subject.call(attrs)

        result = subject.call(attrs.merge("#{p}NEIGHBOR0_ASN" => '65101'))

        expect(result.status).to eq :failed
        expect(result.message).to include('restore of last-good ALSO failed')
    end

    it 'reports when there is no last-good config to restore' do
        result = applier(FakeReloader.new(reload: [false])).call(attrs)

        expect(result.status).to eq :failed
        expect(result.message).to include('no last-good config to restore')
    end

    describe 'static routes' do
        let(:routes) { 'ONEAPP_VNF_STATIC_ROUTES' }
        let(:static_only) { { routes => '1.1.1.1/32 via 10.0.0.1, 9.9.9.9/32 via 10.0.0.1' } }

        it 'renders the routes next to BGP and reloads them like any other change' do
            reloader = FakeReloader.new

            result = applier(reloader).call(attrs.merge(routes => '1.1.1.1/32 via 10.0.0.1'))

            expect(result.status).to eq :applied
            expect(last_good).to include("ip route 1.1.1.1/32 10.0.0.1\n", 'router bgp 65010')
            expect(reloader.calls.map(&:first)).to eq %i[test reload soft_refresh]
        end

        it 'rejects invalid routes without touching FRR, naming the attribute' do
            reloader = FakeReloader.new

            result = applier(reloader).call(attrs.merge(routes => '1.1.1.1/32 dev eth0'))

            expect(result.status).to eq :rejected
            expect(result.message).to include('ONEAPP_VNF_STATIC_ROUTES', 'not supported yet')
            expect(reloader.calls).to be_empty
        end

        it 'applies static routes alone when BGP is not enabled' do
            reloader = FakeReloader.new

            result = applier(reloader).call(static_only)

            expect(result.status).to eq :applied
            expect(result.config.section(:bgp)).to be_nil
            expect(last_good).to include("ip route 1.1.1.1/32 10.0.0.1\nip route 9.9.9.9/32 10.0.0.1\n")
            expect(last_good).not_to include('router bgp')
        end

        it 'does not refresh BGP or write a boot pin without BGP' do
            reloader = FakeReloader.new

            applier(reloader).call(static_only)

            expect(reloader.calls.map(&:first)).to eq %i[test reload]
            expect(File.exist?(File.join(dir, 'boot.json'))).to be false
        end

        it 'does not bring back the ASN of an old pin without BGP' do
            File.write File.join(dir, 'boot.json'), '{"asn":65010,"router_id":"10.0.0.1"}'

            applier(FakeReloader.new).call(static_only)

            expect(last_good).not_to include('router bgp')
        end

        it 'removes every route live with NONE' do
            subject = applier(FakeReloader.new)
            subject.call(static_only)

            result = subject.call({ routes => 'NONE' })

            expect(result.status).to eq :applied
            expect(last_good).not_to include('ip route')
        end

        it 'renders identical routes for the backup' do
            applier(FakeReloader.new).call(attrs.merge(routes => '1.1.1.1/32 via 10.0.0.1'), ha_state: :backup)

            expect(last_good).to include("ip route 1.1.1.1/32 10.0.0.1\n")
        end
    end
end
