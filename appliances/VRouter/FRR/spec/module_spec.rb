# frozen_string_literal: true

require_relative 'support/quiet_logs'
require_relative '../main'
require_relative '../../Failover/execute'

RSpec.describe Service::FRR do
    it 'has no module dependencies, so it does not wait for Keepalived or Failover' do
        expect(described_class::DEPENDS_ON).to eq []
    end

    it 'is not stopped by Failover on the standby node' do
        expect(Service::Failover::SERVICES.keys).not_to include('one-frr', 'frr', 'one-frr-poller')
    end

    it 'provides the three service steps' do
        expect(described_class).to respond_to(:install, :configure, :bootstrap)
    end
end
