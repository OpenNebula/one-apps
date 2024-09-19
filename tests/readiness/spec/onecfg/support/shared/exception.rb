require 'rspec'

RSpec.shared_examples_for 'exception' do |cls, value = nil, mandatory = false|
    unless mandatory
        it 'initializes' do
            expect(cls.new).not_to be_nil
        end
    end

    unless value.nil?
        it 'initializes with value' do
            expect(cls.new(value)).not_to be_nil
        end
    end

    unless mandatory
        it 'raises' do
            expect { raise cls }.to raise_error(cls)
        end
    end

    if value
        it 'raises with value' do
            expect { raise cls, value }.to raise_error(cls)
        end
    end
end
