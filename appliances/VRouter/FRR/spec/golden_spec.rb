# frozen_string_literal: true

require_relative 'support/quiet_logs'
require_relative 'support/golden_cases'
require_relative '../config'
require_relative '../renderer'

# The rendered frr.conf must stay byte-identical across refactors.
# Regenerate on purpose only: GOLDEN_UPDATE=1 rspec spec/golden_spec.rb
RSpec.describe 'golden frr.conf output' do
    dir = File.join(__dir__, 'fixtures', 'golden')

    GoldenCases::CASES.each do |name, kase|
        it "renders #{name} exactly as the fixture" do
            config = Service::FRR::Config.parse_frr(kase.fetch(:attrs))
            out    = Service::FRR::Renderer.render(config, hostname: 'vr1', ha_state: kase.fetch(:ha_state, :master))
            path   = File.join(dir, "#{name}.conf")

            File.write(path, out) if ENV['GOLDEN_UPDATE'] == '1'
            expect(File.read(path)).to eq out
        end
    end

    it 'has a fixture for every case and no stray fixtures' do
        expect(Dir[File.join(dir, '*.conf')].map { |f| File.basename(f, '.conf') }.sort).to eq GoldenCases::CASES.keys.sort
    end
end
