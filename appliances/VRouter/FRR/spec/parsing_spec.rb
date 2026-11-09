# frozen_string_literal: true

require_relative 'support/quiet_logs'
require_relative '../parsing'

RSpec.describe Service::FRR::Parsing::Reader do
    def reader(attrs) = described_class.new(attrs, 'X_')

    it 'builds the attribute name from the prefix' do
        expect(reader({}).key('ASN')).to eq 'X_ASN'
    end

    it 'treats a blank value like a missing one' do
        expect(reader('X_A' => '  ').value('A')).to be_nil
        expect(reader('X_A' => ' 5 ').value('A')).to eq ' 5 '
    end

    it 'reads integers within a range and reports the rest, naming the attribute' do
        errors = []
        r = reader('X_N' => '7', 'X_BAD' => 'abc', 'X_BIG' => '99')

        expect(r.integer('N', 1..10, errors)).to eq 7
        expect(r.integer('BAD', 1..10, errors, default: 3)).to eq 3
        expect(r.integer('BIG', 1..10, errors)).to be_nil
        expect(errors).to eq ['X_BAD must be an integer, got "abc"', 'X_BIG must be between 1 and 10, got 99']
    end

    it 'reports a missing required integer' do
        errors = []
        reader({}).integer('N', 1..10, errors, required: true)

        expect(errors).to eq ['X_N is required']
    end

    it 'does not echo a rejected text value (it may be a password)' do
        errors = []
        reader('X_PW' => 'a b').text('PW', Service::FRR::Parsing::SECRET_FORMAT, 'no whitespace', errors)

        expect(errors).to eq ['X_PW must match: no whitespace']
    end

    it 'parses YES/NO booleans and reports the rest' do
        errors = []
        r = reader('X_A' => 'yes', 'X_B' => '0', 'X_C' => 'maybe')

        expect([r.boolean('A', errors), r.boolean('B', errors), r.boolean('C', errors), r.boolean('D', errors)])
            .to eq [true, false, false, false]
        expect(errors).to eq ['X_C must be YES or NO, got "maybe"']
    end

    it 'accepts YES/1 and NO/0 only, like the rest of the appliance (TRUE and FALSE are errors)' do
        errors = []
        r = reader('X_A' => 'YES', 'X_B' => '1', 'X_C' => 'no', 'X_D' => '0', 'X_E' => 'TRUE', 'X_F' => 'false')

        expect(%w[A B C D].map { |name| r.boolean(name, errors) }).to eq [true, true, false, false]
        expect(errors).to be_empty

        r.boolean('E', errors)
        r.boolean('F', errors)

        expect(errors).to eq ['X_E must be YES or NO, got "TRUE"', 'X_F must be YES or NO, got "false"']
    end

    it 'reads a fixed number of integers' do
        errors = []
        r = reader('X_T' => '5 200 200', 'X_U' => '1 2')

        expect(r.integers('T', 3, errors)).to eq '5 200 200'
        expect(r.integers('U', 3, errors)).to be_nil
        expect(r.integers('V', 3, errors, default: '3 300 300')).to eq '3 300 300'
        expect(errors).to eq ['X_U must be 3 integers separated by spaces, got "1 2"']
    end

    it 'reads an IPv4 address and explains the 32-bit router-id' do
        errors = []
        r = reader('X_R' => '10.0.0.1', 'X_S' => 'fd77::1')

        expect(r.ipv4('R', errors)).to eq '10.0.0.1'
        expect(r.ipv4('S', errors)).to be_nil
        expect(errors.first).to start_with('X_S must be an IPv4 address, got "fd77::1"')
    end

    it 'reads prefix lists, de-duplicated, and names invalid entries' do
        errors = []
        r = reader('X_P' => '10.0.0.0/8 le 24, 10.0.0.0/8 le 24, bad', 'X_Q' => '10.1.0.0/16 le 24')

        expect(r.prefixes('P', errors)).to eq ['10.0.0.0/8 le 24']
        expect(errors).to eq ['X_P has an invalid prefix "bad" (IPv4 or IPv6, no host bits, lengths within the family)']
        expect(r.prefixes('Q', [], ranges: false)).to eq []
    end
end
