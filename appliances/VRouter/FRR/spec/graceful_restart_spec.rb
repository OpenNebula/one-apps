# frozen_string_literal: true

require_relative 'support/quiet_logs'
require_relative 'support/bgp_config'
require_relative '../config'
require_relative '../renderer'

RSpec.describe 'BGP graceful restart' do
    let(:p) { Service::FRR::Attributes::PREFIX }

    let(:attrs) do
        {
            "#{p}ASN" => '65010', "#{p}ROUTER_ID" => '10.99.37.2',
            "#{p}NEIGHBOR0_ADDRESS" => '10.99.37.1', "#{p}NEIGHBOR0_ASN" => '65100'
        }
    end

    def parse(extra = {}) = parse_bgp(attrs.merge(extra)).section(:bgp)

    def error_for(extra)
        parse(extra)
        nil
    rescue Service::FRR::ConfigError => e
        e.message
    end

    def render(extra = {}) = Service::FRR::Renderer.render(parse_bgp(attrs.merge(extra)), hostname: 'vr1')

    describe 'parsing' do
        it 'is off with FRR default timers when nothing is set' do
            expect(parse).to have_attributes(graceful_restart: :no, gr_restart_time: 120, gr_stalepath_time: 360)
        end

        it 'reads the mode in any case' do
            expect(parse("#{p}GRACEFUL_RESTART" => 'helper').graceful_restart).to eq :helper
            expect(parse("#{p}GRACEFUL_RESTART" => 'No').graceful_restart).to eq :no
        end

        it 'reads the timers with HELPER' do
            config = parse("#{p}GRACEFUL_RESTART" => 'HELPER', "#{p}GR_RESTART_TIME" => '300', "#{p}GR_STALEPATH_TIME" => '200')

            expect(config).to have_attributes(gr_restart_time: 300, gr_stalepath_time: 200)
        end

        it 'rejects an unknown mode' do
            expect(error_for("#{p}GRACEFUL_RESTART" => 'MAYBE')).to include("#{p}GRACEFUL_RESTART must be NO or HELPER, got")
        end

        it 'does not offer YES in the message for a value that is not a mode, as YES is refused' do
            expect(error_for("#{p}GRACEFUL_RESTART" => '1')).not_to include('YES')
        end

        it 'rejects restarter mode, which the restart of the whole frr service cannot support' do
            expect(error_for("#{p}GRACEFUL_RESTART" => 'YES')).to include("#{p}GRACEFUL_RESTART=YES (restarter) is not supported")
        end

        it 'checks the timer ranges of FRR with HELPER' do
            helper = { "#{p}GRACEFUL_RESTART" => 'HELPER' }

            expect(error_for(helper.merge("#{p}GR_RESTART_TIME" => '4096'))).to include("#{p}GR_RESTART_TIME must be between 0 and 4095")
            expect(error_for(helper.merge("#{p}GR_STALEPATH_TIME" => '0'))).to include("#{p}GR_STALEPATH_TIME must be between 1 and 4095")
            expect(error_for(helper.merge("#{p}GR_STALEPATH_TIME" => 'x'))).to include("#{p}GR_STALEPATH_TIME must be an integer")
        end

        it 'accepts the range limits with HELPER' do
            expect(error_for("#{p}GRACEFUL_RESTART" => 'HELPER', "#{p}GR_RESTART_TIME" => '0', "#{p}GR_STALEPATH_TIME" => '4095')).to be_nil
        end

        it 'does not check the timers while graceful restart is off, where they are ignored' do
            expect(error_for("#{p}GR_RESTART_TIME" => '9999', "#{p}GR_STALEPATH_TIME" => 'x')).to be_nil
            expect(error_for("#{p}GRACEFUL_RESTART" => 'NO', "#{p}GR_RESTART_TIME" => '9999')).to be_nil
            expect(parse("#{p}GR_RESTART_TIME" => '9999')).to have_attributes(gr_restart_time: 120, gr_stalepath_time: 360)
        end
    end

    describe 'rendering' do
        it 'renders nothing by default' do
            expect(render).not_to include('graceful')
        end

        it 'renders nothing for NO, whatever the timers' do
            expect(render("#{p}GRACEFUL_RESTART" => 'NO', "#{p}GR_RESTART_TIME" => '30')).not_to include('graceful')
        end

        it 'marks every neighbor as helper for HELPER' do
            out = render("#{p}GRACEFUL_RESTART" => 'HELPER', "#{p}NEIGHBOR1_ADDRESS" => 'fd77::21', "#{p}NEIGHBOR1_ASN" => '65002')

            expect(out).to include(" neighbor 10.99.37.1 graceful-restart-helper\n", " neighbor fd77::21 graceful-restart-helper\n")
            expect(out).not_to include("\n bgp graceful-restart\n")
        end

        it 'leaves timers equal to the FRR defaults out, as FRR does not print them back' do
            expect(render("#{p}GRACEFUL_RESTART" => 'HELPER', "#{p}GR_RESTART_TIME" => '120')).not_to include('restart-time')
        end

        it 'renders no graceful restart line after a live change back to the default values' do
            out = render("#{p}GRACEFUL_RESTART" => 'HELPER', "#{p}GR_RESTART_TIME" => '120', "#{p}GR_STALEPATH_TIME" => '360')

            expect(out).not_to include('stalepath-time')
            expect(out).not_to include('restart-time')
        end

        it 'renders timers that differ from the defaults' do
            out = render("#{p}GRACEFUL_RESTART" => 'HELPER', "#{p}GR_RESTART_TIME" => '60', "#{p}GR_STALEPATH_TIME" => '200')

            expect(out).to include(" bgp graceful-restart restart-time 60\n", " bgp graceful-restart stalepath-time 200\n")
        end
    end
end
