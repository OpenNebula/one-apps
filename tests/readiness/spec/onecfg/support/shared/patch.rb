require 'rspec'
require 'tempfile'

RSpec.shared_examples_for 'patch configs' do |cls, fn1, fn2, fn3, block|
    before(:all) do
        @tmps = []
        @tmps << Tempfile.open('rspec')
        @tmps << Tempfile.open('rspec')
        @tmps << Tempfile.open('rspec')
        @tmps.map { |tmp| tmp.close }

        FileUtils.cp(fn1, @tmps[0].path)
        FileUtils.cp(fn2, @tmps[1].path)
        FileUtils.cp(fn3, @tmps[2].path)

        @cfg1 = cls.new(@tmps[0].path)
        @cfg2 = cls.new(@tmps[1].path)
        @cfg3 = cls.new(@tmps[2].path)
    end

    it 'loads' do
        expect { @cfg1.load }.not_to raise_error(Exception)
        expect(@cfg1.content).not_to be_nil
        expect { @cfg2.load }.not_to raise_error(Exception)
        expect(@cfg2.content).not_to be_nil
        expect { @cfg3.load }.not_to raise_error(Exception)
        expect(@cfg3.content).not_to be_nil
    end

    it 'check diff is not nil' do
        diff = @cfg1.diff(@cfg2)
        expect(diff).not_to be nil
        expect(diff).to be_an(Array)
        expect(diff).not_to be_empty
    end

    it 'patch file with diff' do
        diff = @cfg1.diff(@cfg2)
        @cfg3.patch(diff)

        expect(block.call(@cfg3)).to eq(true)
    end

    it 'reset files content' do
        @cfg1.load
        @cfg2.load
        @cfg3.load
    end

    it 'patch file itself with diff' do
        diff = @cfg1.diff(@cfg2)
        @cfg1.patch(diff)

        expect(@cfg1.similar?(@cfg2))
    end

    it 'diff with the patched file' do
        expect(@cfg1.diff(@cfg2)).to be nil
    end
end
