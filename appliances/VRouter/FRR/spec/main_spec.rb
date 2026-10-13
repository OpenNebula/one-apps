# frozen_string_literal: true

require_relative 'support/quiet_logs'
require 'tmpdir'
require_relative '../main'

RSpec.describe Service::FRR do
    let(:dir) { Dir.mktmpdir }
    let(:p) { Service::FRR::Attributes::PREFIX }

    before do
        ENV.delete_if { |name| name.start_with?('ETH') || name.start_with?(p) || name == 'ONEAPP_VNF_STATIC_ROUTES' }
        allow(described_class).to receive(:toggle)
        allow(described_class).to receive(:toggle_poller)
    end

    after { FileUtils.remove_entry(dir) }

    # No owner/group: the test container has no frr user to chown to.
    def configure = described_class.configure(conf_dir: dir, state_dir: File.join(dir, 'state'), owner: nil, group: nil)

    def set_env(values) = values.each { |name, value| ENV[name] = value }

    describe '.enable_daemons' do
        it 'turns bgpd, ospfd and bfdd on and leaves the rest alone' do
            path = File.join(dir, 'daemons')
            File.write path, "bgpd=no\nospfd=no\nbfdd=no\nzebra=yes\n"

            described_class.enable_daemons(path)

            expect(File.read(path)).to eq "bgpd=yes\nospfd=yes\nbfdd=yes\nzebra=yes\n"
        end

        it 'is idempotent: a second run changes nothing' do
            path = File.join(dir, 'daemons')
            File.write path, "bgpd=no\nbfdd=no\n"

            2.times { described_class.enable_daemons(path) }

            expect(File.read(path)).to eq "bgpd=yes\nbfdd=yes\n"
        end

        it 'enables bfdd although no section asks for it (several protocols can use BFD)' do
            path = File.join(dir, 'daemons')
            File.write path, "bfdd=no\nzebra=yes\n"

            expect(Service::FRR::Sections::ALL.flat_map(&:daemons)).not_to include('bfdd')
            described_class.enable_daemons(path)

            expect(File.read(path)).to eq "bfdd=yes\nzebra=yes\n"
        end
    end

    describe 'keeping frr.conf in step with the applies' do
        it 'writes the config FRR loads on a restart with the same mode as at boot' do
            described_class.send(:write_frr_conf, "router bgp 1\n", conf_dir: dir, owner: nil, group: nil)

            expect(File.read(File.join(dir, 'frr.conf'))).to eq "router bgp 1\n"
            expect(File.stat(File.join(dir, 'frr.conf')).mode & 0o777).to eq 0o640
        end

        it 'hands that writer to the applier of the poller' do
            allow(OneGate).to receive(:instance)
            expect(Service::FRR::Applier).to receive(:new).with(hash_including(conf_writer: kind_of(Method))).and_call_original

            described_class.send(:build_poller, online: false)
        end
    end

    it 'keeps the shared router-id and the BGP boot-only keys out of the stored overrides' do
        expect(described_class::BOOT_ONLY_KEYS).to include('ONEAPP_VNF_FRR_ROUTER_ID', 'ONEAPP_VNF_BGP_ASN')
    end

    describe '.poller_service' do
        it 'is an OpenRC script that runs Service::FRR.poll after frr' do
            script = described_class.poller_service

            expect(script).to include('#!/sbin/openrc-run', '-e Service::FRR.poll', 'need frr')
        end

        it 'is killed when it does not stop on SIGTERM, so a restart cannot fail with "refused to stop"' do
            expect(described_class.poller_service).to include('retry="TERM/10/KILL/5"')
        end
    end

    describe '.hook_script' do
        it 'calls ha_transition with the direction from Failover' do
            expect(described_class.hook_script).to include('Service::FRR.ha_transition', '"$1"')
        end

        it 'still runs ha_transition when one_env is missing' do
            script = described_class.hook_script

            expect(script).to include('[ -r /run/one-context/one_env ] && . /run/one-context/one_env')
            expect(script).not_to match(%r{^\. /run/one-context/one_env})
            expect(system('sh', '-n', '-c', script)).to be true
        end
    end

    describe '.configure' do
        it 'does nothing but stop and disable FRR when BGP is not enabled' do
            expect(described_class).to receive(:toggle).with(%i[stop disable])

            configure

            expect(File.exist?(File.join(dir, 'frr.conf'))).to be false
        end

        it 'renders frr.conf from the context when enabled' do
            set_env('ONEAPP_VNF_BGP_ENABLED' => 'YES', "#{p}ASN" => '65010', 'ETH1_IP' => '10.99.37.2',
                    "#{p}NEIGHBOR0_ADDRESS" => '10.99.37.1', "#{p}NEIGHBOR0_ASN" => '65100')

            configure

            expect(File.read(File.join(dir, 'frr.conf'))).to include('router bgp 65010', 'bgp router-id 10.99.37.2',
                                                                    'neighbor 10.99.37.1 remote-as 65100')
        end

        it 'still boots with a minimal frr.conf when the BGP attributes are invalid' do
            set_env('ONEAPP_VNF_BGP_ENABLED' => 'YES', "#{p}ASN" => 'not-a-number')

            expect { configure }.not_to raise_error

            conf = File.read(File.join(dir, 'frr.conf'))
            expect(conf).to include('frr defaults traditional')
            expect(conf).not_to include('router bgp')
        end

        it 'does not put a password into the log when the attributes are invalid' do
            set_env('ONEAPP_VNF_BGP_ENABLED' => 'YES', "#{p}ASN" => 'x', "#{p}NEIGHBOR0_PASSWORD" => 's3cretpw')

            logged = []
            allow(described_class).to receive(:msg) { |_level, text| logged << text }

            configure

            expect(logged).not_to be_empty
            expect(logged.join).not_to include('s3cretpw')
        end

        context 'with a valid BGP context' do
            before do
                set_env('ONEAPP_VNF_BGP_ENABLED' => 'YES', "#{p}ASN" => '65010', 'ETH1_IP' => '10.99.37.2')
            end

            let(:conf_path) { File.join(dir, 'frr.conf') }

            it 'records the booted config as last-good, so a failed first apply rolls back to what is running' do
                configure

                expect(File.read(File.join(dir, 'state', 'last-good.conf'))).to eq File.read(conf_path)
                expect(File.stat(File.join(dir, 'state', 'last-good.conf')).mode & 0o777).to eq 0o600
            end

            it 'does not replace last-good with the minimal fallback when FRR rejects the booted config' do
                File.write(File.join(dir, 'state', 'last-good.conf'), "router bgp 1\n") if Dir.mkdir(File.join(dir, 'state'))
                restarts = 0
                allow(described_class).to receive(:toggle) do |ops|
                    next unless ops.include?(:restart)

                    restarts += 1
                    raise 'frr rejected the config' if restarts == 1
                end

                configure

                expect(File.read(File.join(dir, 'state', 'last-good.conf'))).to eq "router bgp 1\n"
            end

            it 'keeps the rendered config when the pin cannot be written' do
                allow(Service::FRR::Applier).to receive(:write_pin).and_raise(Errno::ENOSPC)

                expect { configure }.not_to raise_error

                expect(File.read(conf_path)).to include('router bgp 65010')
            end

            it 'falls back to the minimal config and retries once when the first restart fails' do
                restarts = 0
                allow(described_class).to receive(:toggle) do |ops|
                    next unless ops.include?(:restart)

                    restarts += 1
                    raise 'frr rejected the config' if restarts == 1
                end

                expect { configure }.not_to raise_error

                expect(restarts).to eq 2
                expect(File.read(conf_path)).to include('frr defaults traditional')
                expect(File.read(conf_path)).not_to include('router bgp')
            end

            it 'still enables FRR when the restart fails' do
                calls = []
                allow(described_class).to receive(:toggle) do |ops|
                    calls << ops
                    raise 'boom' if ops.include?(:restart)
                end

                configure

                expect(calls).to include([:enable])
            end

            it 'does not raise when both restarts fail' do
                allow(described_class).to receive(:toggle) { |ops| raise 'boom' if ops.include?(:restart) }

                expect { configure }.not_to raise_error
            end
        end

        context 'when something unexpected goes wrong (configure must never fail the appliance)' do
            before do
                set_env('ONEAPP_VNF_BGP_ENABLED' => 'YES', "#{p}ASN" => '65010', 'ETH1_IP' => '10.99.37.2')
            end

            let(:conf_path) { File.join(dir, 'frr.conf') }
            let(:restarts) { [] }

            before do
                allow(described_class).to receive(:toggle) { |ops| restarts << ops if ops.include?(:restart) }
            end

            def expect_minimal_config_started
                conf = File.read(conf_path)
                expect(conf).to include('frr defaults traditional')
                expect(conf).not_to include('router bgp')
                expect(restarts).not_to be_empty
            end

            it 'renders BGP for a hostname with an underscore' do
                allow(Socket).to receive(:gethostname).and_return('vr_1')

                configure

                expect(File.read(conf_path)).to include('hostname vr_1', 'router bgp 65010')
            end

            it 'writes the minimal config without the hostname when the hostname is unsafe' do
                allow(Socket).to receive(:gethostname).and_return("vr1\nrouter bgp 1")

                expect { configure }.not_to raise_error

                expect_minimal_config_started
                expect(File.read(conf_path)).not_to include('vr1')
            end

            it 'writes the minimal config when the hostname cannot be read' do
                allow(Socket).to receive(:gethostname).and_raise(SocketError, 'no hostname')

                expect { configure }.not_to raise_error

                expect_minimal_config_started
            end

            it 'writes the minimal config when the HA state cannot be read' do
                allow(Service::FRR::HaState).to receive(:read).and_raise(Errno::EACCES)

                expect { configure }.not_to raise_error

                expect_minimal_config_started
            end

            it 'still renders from the context when overrides.json is valid JSON but not an object' do
                FileUtils.mkdir_p File.join(dir, 'state')
                File.write File.join(dir, 'state', 'overrides.json'), '"x"'

                expect { configure }.not_to raise_error

                expect(File.read(conf_path)).to include('router bgp 65010')
            end

            it 'still restarts FRR when enabling the service fails' do
                allow(described_class).to receive(:toggle) do |ops|
                    raise 'rc-update failed' if ops == [:enable]

                    restarts << ops if ops.include?(:restart)
                end

                expect { configure }.not_to raise_error

                expect(restarts).to eq [[:restart]]
            end

            it 'does not raise when frr.conf cannot be written at all' do
                allow(described_class).to receive(:file).and_raise(Errno::EACCES)

                expect { configure }.not_to raise_error
            end

            it 'logs the error class and message but no attribute value' do
                set_env("#{p}NEIGHBOR0_ADDRESS" => '10.99.37.1', "#{p}NEIGHBOR0_ASN" => '65100',
                        "#{p}NEIGHBOR0_PASSWORD" => 's3cretpw')
                allow(Service::FRR::HaState).to receive(:read).and_raise(Errno::EACCES)
                logged = []
                allow(described_class).to receive(:msg) { |_level, text| logged << text }

                configure

                expect(logged.join("\n")).to include('Errno::EACCES')
                expect(logged.join("\n")).not_to include('s3cretpw')
            end
        end

        context 'with remembered runtime overrides' do
            let(:state) { File.join(dir, 'state') }
            let(:conf_path) { File.join(dir, 'frr.conf') }
            let(:last_good) { "frr defaults traditional\nhostname vr1\nrouter bgp 65010\n bgp router-id 10.99.37.2\nexit\n" }

            before do
                set_env('ONEAPP_VNF_BGP_ENABLED' => 'YES', "#{p}ASN" => '65010', 'ETH1_IP' => '10.99.37.2')
                FileUtils.mkdir_p state
            end

            def store(overrides) = File.write(File.join(state, 'overrides.json'), JSON.generate(overrides))

            it 'boots last-good.conf when the stored overrides make the config invalid' do
                store("#{p}NEIGHBOR0_ADDRESS" => '10.99.37.1', "#{p}NEIGHBOR0_ASN" => 'bad')
                File.write File.join(state, 'last-good.conf'), last_good
                File.write File.join(state, 'boot.json'), '{"asn":1,"router_id":"1.1.1.1"}'

                configure

                expect(File.read(conf_path)).to eq last_good
                expect(File.stat(conf_path).mode & 0o777).to eq 0o640
                expect(File.exist?(File.join(state, 'boot.json'))).to be false
            end

            it 'logs that last-good.conf was used' do
                store("#{p}NEIGHBOR0_ADDRESS" => '10.99.37.1', "#{p}NEIGHBOR0_ASN" => 'bad')
                File.write File.join(state, 'last-good.conf'), last_good
                logged = []
                allow(described_class).to receive(:msg) { |_level, text| logged << text }

                configure

                expect(logged.join("\n")).to include('last-good.conf')
            end

            ['', nil].each do |content|
                it "boots the minimal config when the config is invalid and last-good.conf is #{content.nil? ? 'missing' : 'empty'}" do
                    store("#{p}NEIGHBOR0_ADDRESS" => '10.99.37.1', "#{p}NEIGHBOR0_ASN" => 'bad')
                    File.write File.join(state, 'last-good.conf'), content unless content.nil?

                    configure

                    expect(File.read(conf_path)).to include('frr defaults traditional')
                    expect(File.read(conf_path)).not_to include('router bgp')
                end
            end

            it 'renders a valid merged config rather than last-good.conf' do
                store("#{p}NEIGHBOR0_ADDRESS" => '10.99.37.1', "#{p}NEIGHBOR0_ASN" => '65100')
                File.write File.join(state, 'last-good.conf'), last_good

                configure

                expect(File.read(conf_path)).to include('neighbor 10.99.37.1 remote-as 65100')
            end

            it 'takes ASN and ROUTER_ID from the context only, but applies the other overrides' do
                store("#{p}ASN" => '65999', "#{p}ROUTER_ID" => '10.9.9.9',
                      "#{p}NEIGHBOR0_ADDRESS" => '10.99.37.1', "#{p}NEIGHBOR0_ASN" => '65100')

                configure

                conf = File.read(conf_path)
                expect(conf).to include('router bgp 65010', 'bgp router-id 10.99.37.2', 'neighbor 10.99.37.1 remote-as 65100')
                expect(conf).not_to include('65999', '10.9.9.9')
                expect(JSON.parse(File.read(File.join(state, 'boot.json')))).to eq('asn' => 65_010, 'router_id' => '10.99.37.2')
            end

            it 'is not broken by an invalid stored ASN' do
                store("#{p}ASN" => 'not-a-number')

                configure

                expect(File.read(conf_path)).to include('router bgp 65010')
            end
        end

        it 'keeps the state directory private (it holds passwords)' do
            state = File.join(dir, 'state')
            FileUtils.mkdir_p state, mode: 0o755
            File.chmod 0o755, state
            set_env('ONEAPP_VNF_BGP_ENABLED' => 'YES', "#{p}ASN" => '65010', 'ETH1_IP' => '10.99.37.2')

            configure

            expect(File.stat(state).mode & 0o777).to eq 0o700
            expect(File.stat(File.join(state, 'boot.json')).mode & 0o777).to eq 0o600
        end

        it 'removes a stale boot pin when the context is invalid' do
            state = File.join(dir, 'state')
            FileUtils.mkdir_p state
            File.write File.join(state, 'boot.json'), '{"asn":1,"router_id":"1.1.1.1"}'
            set_env('ONEAPP_VNF_BGP_ENABLED' => 'YES', "#{p}ASN" => 'bad')

            configure

            expect(File.exist?(File.join(state, 'boot.json'))).to be false
        end
    end

    describe 'static routes' do
        let(:state) { File.join(dir, 'state') }
        let(:conf_path) { File.join(dir, 'frr.conf') }
        let(:routes) { 'ONEAPP_VNF_STATIC_ROUTES' }
        let(:started) { [] }

        before do
            allow(described_class).to receive(:toggle) { |ops| started << ops }
        end

        it 'starts FRR with only the static routes when BGP is not enabled' do
            set_env(routes => '1.1.1.1/32 via 10.99.37.1, 9.9.9.9/32 via 10.99.37.1')

            configure

            conf = File.read(conf_path)
            expect(conf).to include("ip route 1.1.1.1/32 10.99.37.1\n", "ip route 9.9.9.9/32 10.99.37.1\n")
            expect(conf).not_to include('router bgp')
            expect(started).to include([:enable], [:restart])
            expect(File.exist?(File.join(state, 'boot.json'))).to be false
        end

        it 'does not stop FRR or the poller when only static routes are set' do
            set_env(routes => '1.1.1.1/32 via 10.99.37.1')
            polls = []
            allow(described_class).to receive(:toggle_poller) { |ops| polls << ops }

            configure

            expect(started).not_to include(%i[stop disable])
            expect(polls).to eq []
        end

        it 'keeps today\'s behavior when BGP is off and there are no routes' do
            configure

            expect(started).to eq [%i[stop disable]]
            expect(File.exist?(conf_path)).to be false
        end

        it 'lets NONE in the context start FRR with no routes so they can be added live' do
            set_env(routes => 'none')

            configure

            expect(File.read(conf_path)).not_to include('ip route', 'router bgp')
            expect(started).to include([:restart])
        end

        it 'renders the routes next to BGP when BGP is enabled' do
            set_env('ONEAPP_VNF_BGP_ENABLED' => 'YES', "#{p}ASN" => '65010', 'ETH1_IP' => '10.99.37.2',
                    routes => '1.1.1.1/32 via 10.99.37.1')

            configure

            expect(File.read(conf_path)).to include('router bgp 65010', "ip route 1.1.1.1/32 10.99.37.1\n")
        end

        it 'boots with the routes remembered from the user template' do
            set_env(routes => '1.1.1.1/32 via 10.99.37.1')
            FileUtils.mkdir_p state
            File.write File.join(state, 'overrides.json'), JSON.generate(routes => '2.2.2.2/32 via 10.99.37.1')

            configure

            expect(File.read(conf_path)).to include('ip route 2.2.2.2/32')
            expect(File.read(conf_path)).not_to include('1.1.1.1/32')
        end

        it 'ignores a stored BGP_ENABLED override: it is boot-only' do
            set_env(routes => '1.1.1.1/32 via 10.99.37.1')
            FileUtils.mkdir_p state
            File.write File.join(state, 'overrides.json'), JSON.generate("#{p}ENABLED" => 'YES', "#{p}ASN" => '65010')

            configure

            expect(File.read(conf_path)).not_to include('router bgp')
        end

        it 'removes a stale boot pin from an earlier BGP boot' do
            FileUtils.mkdir_p state
            File.write File.join(state, 'boot.json'), '{"asn":1,"router_id":"1.1.1.1"}'
            set_env(routes => '1.1.1.1/32 via 10.99.37.1')

            configure

            expect(File.exist?(File.join(state, 'boot.json'))).to be false
        end

        context 'with invalid routes' do
            before { set_env(routes => '1.1.1.1/32 dev eth0') }

            it 'never raises and starts FRR with the minimal config' do
                expect { configure }.not_to raise_error

                expect(File.read(conf_path)).to include('frr defaults traditional')
                expect(File.read(conf_path)).not_to include('ip route')
                expect(started).to include([:restart])
            end

            it 'falls back to last-good.conf like invalid BGP attributes do' do
                FileUtils.mkdir_p state
                File.write File.join(state, 'last-good.conf'), "frr defaults traditional\nip route 5.5.5.5/32 10.99.37.1\n"

                configure

                expect(File.read(conf_path)).to include('ip route 5.5.5.5/32')
            end

            it 'logs the validation message naming the attribute' do
                logged = []
                allow(described_class).to receive(:msg) { |_level, text| logged << text }

                configure

                expect(logged.join("\n")).to include('ONEAPP_VNF_STATIC_ROUTES')
            end
        end
    end

    describe '.bootstrap' do
        before do
            allow(described_class).to receive(:toggle_poller)
        end

        it 'enables the poller for static routes without BGP when OneGate is there' do
            set_env('ONEAPP_VNF_STATIC_ROUTES' => '1.1.1.1/32 via 10.99.37.1', 'ONEGATE_ENDPOINT' => 'http://169.254.16.9:5030')

            described_class.bootstrap

            expect(described_class).to have_received(:toggle_poller).with(%i[enable restart])
        ensure
            ENV.delete 'ONEGATE_ENDPOINT'
        end

        it 'does not stop the bootstrap of the other modules when the poller cannot be started' do
            set_env('ONEAPP_VNF_STATIC_ROUTES' => '1.1.1.1/32 via 10.99.37.1', 'ONEGATE_ENDPOINT' => 'http://169.254.16.9:5030')
            allow(described_class).to receive(:toggle_poller).and_raise(RuntimeError, '1: + rc-service one-frr-poller restart')
            logged = []
            allow(described_class).to receive(:msg) { |level, text| logged << [level, text] }

            expect { described_class.bootstrap }.not_to raise_error

            error = logged.find { |level, _| level == :error }
            expect(error.last).to include('FRR::bootstrap', 'RuntimeError', 'frr-rc.log')
        ensure
            ENV.delete 'ONEGATE_ENDPOINT'
        end

        it 'does nothing when BGP is off and there are no routes' do
            ENV['ONEGATE_ENDPOINT'] = 'http://169.254.16.9:5030'

            described_class.bootstrap

            expect(described_class).not_to have_received(:toggle_poller)
        ensure
            ENV.delete 'ONEGATE_ENDPOINT'
        end

        it 'does not need the poller without OneGate: the routes come from the context' do
            set_env('ONEAPP_VNF_STATIC_ROUTES' => '1.1.1.1/32 via 10.99.37.1')

            described_class.bootstrap

            expect(described_class).not_to have_received(:toggle_poller)
        end
    end

    describe '.ha_transition' do
        it 'maps up to master and down to backup, rejecting anything else' do
            expect(Service::FRR::HaState).to receive(:write).with(:master)
            expect(Service::FRR::HaState).to receive(:write).with(:backup)

            described_class.ha_transition('up')
            described_class.ha_transition('down')

            expect { described_class.ha_transition('sideways') }.to raise_error(ArgumentError)
        end

        context 'with BGP enabled' do
            before do
                ENV["#{p}ENABLED"] = 'YES'
                allow(Service::FRR::HaState).to receive(:write)
            end

            it 'applies once through the poller tick' do
                poller = instance_double(Service::FRR::Poller, tick: nil)
                allow(described_class).to receive(:build_poller).and_return(poller)

                described_class.ha_transition('up')

                expect(poller).to have_received(:tick).once
            end

            it 'ticks an offline poller: no OneGate client is built, fetched from or published to' do
                ENV['ONEGATE_ENDPOINT'] = 'http://169.254.16.9:5030'
                expect(OneGate).not_to receive(:instance)
                built = {}
                allow(Service::FRR::Reporter).to receive(:new).and_wrap_original do |orig, **kw|
                    built[:reporter] = kw[:onegate]
                    orig.call(**kw)
                end
                allow(Service::FRR::Poller).to receive(:new) do |**kw|
                    built[:poller] = kw
                    instance_double(Service::FRR::Poller, tick: nil)
                end

                described_class.ha_transition('down')

                expect(built[:poller]).to include(onegate: nil)
                expect(built).to include(reporter: nil)
            ensure
                ENV.delete 'ONEGATE_ENDPOINT'
            end

            it 'records the state and returns normally when the apply fails' do
                poller = instance_double(Service::FRR::Poller)
                allow(poller).to receive(:tick).and_raise('apply blew up')
                allow(described_class).to receive(:build_poller).and_return(poller)

                expect { described_class.ha_transition('up') }.not_to raise_error

                expect(Service::FRR::HaState).to have_received(:write).with(:master)
            end
        end
    end
end
