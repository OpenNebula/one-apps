# frozen_string_literal: true

require 'rspec'
require 'tmpdir'
require_relative 'helpers.rb'

RSpec.describe 'load_env' do
    it 'should load env vars from file' do
        tests = [
            [ { :E1 => 'V1',
                :E2 => 'V2',
                :E3 => 'V3' },
              <<~INPUT
                export E1="V1"
                export E2="V2"
                export E3="V3"
              INPUT
            ],
            [ { :E1 => '"',
                :E2 => "\n",
                :E3 => "\\n" },
              <<~'INPUT'
                export E1="\""
                export E2="\n"
                export E3="\\n"
              INPUT
            ],
            [ { :E1 => "A\nB\nC",
                :E2 => "A\nB\nC" },
              <<~'INPUT'
                export E1="A
                B
                C"
                export E2="A
                B\nC"
              INPUT
            ],
            [ { :E1 => "\nA\nB\n",
                :E2 => "\nA\nB",
                :E3 => "A\n\nB\n" },
              <<~'INPUT'

                export E1="
                A
                B
                "

                export E2="
                A
                B"

                export E3="A

                B
                "

              INPUT
            ]
        ]
        Dir.mktmpdir do |dir|
            tests.each do |output, input|
                File.write "#{dir}/one_env", input
                load_env "#{dir}/one_env"
                output.each do |k, v|
                    expect(ENV[k.to_s]).to eq v
                end
            end
        end
    end
end

RSpec.describe 'bash' do
    it 'should raise' do
        allow(self).to receive(:exit).and_return nil
        expect { bash 'false' }.to raise_error(RuntimeError)
    end
    it 'should not raise' do
        allow(self).to receive(:exit).and_return nil
        expect { bash 'false', terminate: true }.not_to raise_error
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

RSpec.describe 'hashmap' do
    tests = [
        [ [{}, {}], {} ],

        [ [{a: 1}, {b: 2}], {a: 1, b: 2} ],

        [ [{a: 1, b: 3}, {b: 2}], {a: 1, b: 2} ],

        [ [{a: 1, b: 2}, {b: []}], {a: 1, b: []} ],

        [ [{a: 1, b: [:c]}, {b: []}], {a: 1, b: []} ],

        [ [{a: 1, b: {c: 3, d: 3}}, {b: {c: 2, e: 4}}], {a: 1, b: {c: 2, d: 3, e: 4}} ]
    ]
    it 'should recursively combine two hashmaps' do
        tests.each do |(a, b), c|
            expect(hashmap.combine(a, b)).to eq c
        end
    end
    it 'should recursively combine two hashmaps (in-place)' do
        tests.each do |(a, b), c|
            hashmap.combine!(a, b)
            expect(a).to eq c
        end
    end
end

RSpec.describe 'sortkeys' do
    it 'should v-sort according to a pattern' do
        tests = [
            [ %w[ETH1_VIP10 Y ETH1_VIP1 X ETH0_VIP0],
              /^ETH(\d+)_VIP(\d+)$/,
              %w[ETH0_VIP0 Y ETH1_VIP1 X ETH1_VIP10] ],

            [ %w[lo eth10 eth0 eth1 eth2],
              /^eth(\d+)$/,
              %w[lo eth0 eth1 eth2 eth10] ],
        ]
        tests.each do |input, pattern, output|
            expect(sortkeys.as_version(input, pattern: pattern)).to eq output
            sortkeys.as_version!(input, pattern: pattern)
            expect(input).to eq output
        end
    end
end

RSpec.describe 'sorted_deps' do
    it 'should sort dependencies' do
        tests = [
            [ { :a => [:b],
                :b => [:c],
                :c => [:d],
                :d => [] }, [:d, :c, :b, :a] ],

            [ { :d => [:b],
                :c => [:b, :d],
                :b => [:a],
                :a => [] }, [:a, :b, :d, :c] ],

            [
                {
                    :Failover   => [:Keepalived],
                    :NAT4       => [:Failover, :Router4],
                    :Keepalived => [],
                    :Router4    => [:Failover]
                },
                [
                    :Keepalived,
                    :Failover,
                    :Router4,
                    :NAT4
                ]
            ]
        ]
        tests.each do |input, output|
            expect(sorted_deps(input)).to eq output
        end
    end
end

RSpec.describe 'set_motd' do
    it 'should render motd' do
        output = <<~'OUTPUT'
        .
           ___   _ __    ___
          / _ \ | '_ \  / _ \   OpenNebula Service Appliance
         | (_) || | | ||  __/
          \___/ |_| |_| \___|


         All set and ready to serve 8)

        OUTPUT
        Dir.mktmpdir do |dir|
            set_motd :bootstrap, :success, "#{dir}/motd"
            result = File.read "#{dir}/motd"
            expect(result).to eq output.delete_prefix('.')
        end
    end
end

RSpec.describe 'set_status' do
    it 'should set status' do
        allow(self).to receive(:set_motd).and_return nil
        tests = [
            [ :install, 'install_started' ],
            [ :success, 'install_success' ],
            [ :configure, 'configure_started' ],
            [ :success, 'configure_success' ],
            [ :bootstrap, 'bootstrap_started' ],
            [ :failure, 'bootstrap_failure' ]
        ]
        Dir.mktmpdir do |dir|
            tests.each do |input, output|
                set_status input, "#{dir}/status"
                result = File.open("#{dir}/status", &:gets).strip
                expect(result).to eq output
            end
        end
    end
end
