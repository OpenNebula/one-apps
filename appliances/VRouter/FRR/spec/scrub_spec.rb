# frozen_string_literal: true

require_relative 'support/quiet_logs'
require_relative '../scrub'

RSpec.describe Service::FRR::Scrub do
    it 'masks the value after any password keyword, with or without an encryption type' do
        text = "neighbor 1.1.1.1 password abc\nno neighbor 2.2.2.2 Password 7 def\n"

        expect(described_class.text(text)).to eq "neighbor 1.1.1.1 password ***\nno neighbor 2.2.2.2 Password 7 ***\n"
    end

    it 'never masks across a line break' do
        expect(described_class.text("password 5\nrouter bgp 1")).to eq "password ***\nrouter bgp 1"
    end

    it 'masks every known secret anywhere, longest first' do
        expect(described_class.text('x s3cret y s3cret-long', %w[s3cret s3cret-long])).to eq 'x *** y ***'
    end

    it 'ignores nil and blank secrets' do
        expect(described_class.text('keep me', [nil, ''])).to eq 'keep me'
    end

    it 'reads the password values of a config' do
        conf = " neighbor 1.1.1.1 password abc\n neighbor 2.2.2.2 remote-as 1\n neighbor 3.3.3.3 password 7 def\n"

        expect(described_class.secrets_in(conf)).to eq %w[abc def]
    end

    it 'masks the key of an ospf message-digest-key line' do
        text = "no ip ospf message-digest-key 1 md5 OLDKEY\nip ospf message-digest-key 1 md5 NEWKEY"

        expect(described_class.text(text)).to eq "no ip ospf message-digest-key 1 md5 ***\nip ospf message-digest-key 1 md5 ***"
    end

    it 'finds the md5 keys and the passwords written in a config' do
        config = " neighbor 10.0.0.1 password BGPSECRET\n ip ospf message-digest-key 1 md5 OSPFKEY\n"

        expect(described_class.secrets_in(config)).to contain_exactly('BGPSECRET', 'OSPFKEY')
    end
end
