# frozen_string_literal: true

require 'rspec'

require_relative 'helpers.rb'

RSpec.describe 'bash' do
    it 'should raise' do
        allow(self).to receive(:exit).and_return nil
        expect { bash 'false', terminate: false }.to raise_error(RuntimeError)
    end
    it 'should not raise' do
        allow(self).to receive(:exit).and_return nil
        expect { bash 'false' }.not_to raise_error
    end
end

RSpec.describe 'ipv4?' do
    it 'should evaluate to true' do
        ipv4s = %w[
            10.11.12.13
            10.11.12.13/24
            10.11.12.13/32
            192.168.144.120
        ]
        ipv4s.each do |item|
            expect(ipv4?(item)).to be true
        end
    end
    it 'should evaluate to false' do
        ipv4s = %w[
            10.11.12
            10.11.12.
            10.11.12.256
            asd.168.144.120
            192.168.144.96-192.168.144.120
        ]
        ipv4s.each do |item|
            expect(ipv4?(item)).to be false
        end
    end
end
