require 'rspec'
require 'tempfile'

def check_state(state)
    @cfg1.diff(@cfg2).select {|d| d[:state] == state }
end

RSpec.shared_examples_for 'diff configs' do |cls, fn1, fn2, block|
    before(:all) do
        @tmps = []
        @tmps << Tempfile.open('rspec-')
        @tmps << Tempfile.open('rspec-')
        @tmps.map {|tmp| tmp.close }

        FileUtils.cp(fn1, @tmps[0].path)
        FileUtils.cp(fn2, @tmps[1].path)

        @cfg1 = cls.new(@tmps[0].path)
        @cfg2 = cls.new(@tmps[1].path)
    end

    it 'loads' do
        expect { @cfg1.load }.not_to raise_error(Exception)
        expect(@cfg1.content).not_to be_nil
        expect { @cfg2.load }.not_to raise_error(Exception)
        expect(@cfg2.content).not_to be_nil
    end

    it 'has empty diff' do
        expect(@cfg1.diff(@cfg2)).to be nil
    end

    it 'changes content' do
        block.call(@cfg1)
    end

    it 'has non-empty diff' do
        diff = @cfg1.diff(@cfg2)
        expect(diff).not_to be nil
        expect(diff).to be_an(Array)
        expect(diff).not_to be_empty
    end

    it 'has diff with delete action' do
        expect(check_state(:delete)).not_to be_empty
    end

    it 'has diff with insert action' do
        expect(check_state(:insert)).not_to be_empty
    end

    it 'has diff with insert action' do
        expect(check_state(:different)).not_to be_empty
    end
end
