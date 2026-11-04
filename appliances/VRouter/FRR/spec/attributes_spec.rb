# frozen_string_literal: true

require_relative 'support/quiet_logs'
require_relative '../attributes'

RSpec.describe Service::FRR::Attributes do
    let(:context) do
        { 'ONEAPP_VNF_BGP_ASN' => '65010', 'ONEAPP_VNF_BGP_NEIGHBOR0_ASN' => '65100', 'ETH0_IP' => '10.0.0.1' }
    end

    it 'picks the shared router-id from the context but never takes it from the overrides' do
        merged = described_class.merge({ 'ONEAPP_VNF_FRR_ROUTER_ID' => '10.9.9.9' }, { 'ONEAPP_VNF_FRR_ROUTER_ID' => '10.8.8.8' })

        expect(merged).to eq('ONEAPP_VNF_FRR_ROUTER_ID' => '10.9.9.9')
    end

    it 'keeps only non-empty BGP attributes' do
        picked = described_class.pick(context.merge('ONEAPP_VNF_BGP_MED' => '  '))

        expect(picked).to eq('ONEAPP_VNF_BGP_ASN' => '65010', 'ONEAPP_VNF_BGP_NEIGHBOR0_ASN' => '65100')
    end

    it 'lets overrides win over the context' do
        merged = described_class.merge(context, 'ONEAPP_VNF_BGP_NEIGHBOR0_ASN' => '65200')

        expect(merged).to include('ONEAPP_VNF_BGP_NEIGHBOR0_ASN' => '65200', 'ONEAPP_VNF_BGP_ASN' => '65010')
    end

    it 'falls back to the context when an override is empty' do
        merged = described_class.merge(context, 'ONEAPP_VNF_BGP_ASN' => '')

        expect(merged['ONEAPP_VNF_BGP_ASN']).to eq '65010'
    end

    it 'adds attributes that exist only in the overrides' do
        merged = described_class.merge(context, 'ONEAPP_VNF_BGP_NEIGHBOR1_ASN' => '65300')

        expect(merged['ONEAPP_VNF_BGP_NEIGHBOR1_ASN']).to eq '65300'
    end

    it 'ignores the status attributes the poller writes back' do
        merged = described_class.merge(context, 'BGP_STATE' => 'x', 'FRR_APPLY' => 'y')

        expect(merged.keys).not_to include('BGP_STATE', 'FRR_APPLY')
    end

    it 'returns frozen hashes' do
        expect(described_class.merge(context, {})).to be_frozen
    end

    it 'treats a source that is not a hash as empty' do
        ['x', nil, ['ONEAPP_VNF_BGP_ASN', '1']].each do |junk|
            expect(described_class.pick(junk)).to eq({})
        end
        expect(described_class.merge(context, 'x')).to include('ONEAPP_VNF_BGP_ASN' => '65010')
    end

    describe 'static routes' do
        let(:routes) { 'ONEAPP_VNF_STATIC_ROUTES' }

        it 'picks the static routes next to the BGP attributes' do
            picked = described_class.pick(context.merge(routes => '1.1.1.1/32 via 10.0.0.1', 'ETH0_IP' => 'x'))

            expect(picked).to include(routes => '1.1.1.1/32 via 10.0.0.1', 'ONEAPP_VNF_BGP_ASN' => '65010')
            expect(picked).not_to include('ETH0_IP')
        end

        it 'lets the override replace the context routes' do
            merged = described_class.merge(context.merge(routes => '1.1.1.1/32 via 10.0.0.1'),
                                           routes => '2.2.2.2/32 via 10.0.0.1')

            expect(merged[routes]).to eq '2.2.2.2/32 via 10.0.0.1'
        end

        it 'falls back to the context routes when the override is blank' do
            merged = described_class.merge(context.merge(routes => '1.1.1.1/32 via 10.0.0.1'), routes => '  ')

            expect(merged[routes]).to eq '1.1.1.1/32 via 10.0.0.1'
        end

        it 'keeps NONE as a value so that it can remove the context routes' do
            merged = described_class.merge(context.merge(routes => '1.1.1.1/32 via 10.0.0.1'), routes => 'none')

            expect(merged[routes]).to eq 'none'
        end

        it 'reads the boot-only ASN and router-ids from the context only' do
            boot  = { 'ONEAPP_VNF_BGP_ASN' => '65010', 'ONEAPP_VNF_BGP_ROUTER_ID' => '10.0.0.1',
                      'ONEAPP_VNF_OSPF_ROUTER_ID' => '10.0.0.2', 'ONEAPP_VNF_FRR_ROUTER_ID' => '10.0.0.3' }
            other = { 'ONEAPP_VNF_BGP_ASN' => '64999', 'ONEAPP_VNF_BGP_ROUTER_ID' => '10.9.9.1',
                      'ONEAPP_VNF_OSPF_ROUTER_ID' => '10.9.9.2', 'ONEAPP_VNF_FRR_ROUTER_ID' => '10.9.9.3' }

            expect(described_class.merge(context.merge(boot), other)).to include(boot)
            expect(described_class.merge({}, other).keys).to be_empty
        end

        it 'reads ENABLED from the context only (it is boot-only)' do
            merged = described_class.merge(context.merge('ONEAPP_VNF_BGP_ENABLED' => 'YES'),
                                           'ONEAPP_VNF_BGP_ENABLED' => 'NO')

            expect(merged['ONEAPP_VNF_BGP_ENABLED']).to eq 'YES'
        end
    end
end
