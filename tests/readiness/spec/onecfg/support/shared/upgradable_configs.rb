require 'rspec'
require 'tempfile'

RSpec.shared_examples_for 'upgradable configs' do |cls, fn1, fn2, change|
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

    after(:all) do
        @cfg1.delete if @cfg1.exist?
        @cfg2.delete if @cfg2.exist?
    end

    it 'loads' do
        expect { @cfg1.load }.not_to raise_error(Exception)
        expect(@cfg1.content).not_to be_nil
        expect { @cfg2.load }.not_to raise_error(Exception)
        expect(@cfg2.content).not_to be_nil
    end

    it 'is not same/similar' do
        expect(@cfg1.same?(@cfg2)).to be false
        expect(@cfg1.similar?(@cfg2)).to be false
    end

    it 'has non-empty diff' do
        expect(@cfg1.diff(@cfg2)).not_to be nil
    end

    it 'executes custom code to change file' do
        change.call(@cfg1)
    end

    it 'saves' do
        @cfg1.save
    end

    it 'is similar' do
        expect(@cfg1.similar?(@cfg2)).to be true
    end

    it 'has empty diff' do
        expect(@cfg1.diff(@cfg2)).to be nil
    end

    it 'reloads' do
        @cfg1.load
    end

    it 'is similar' do
        expect(@cfg1.similar?(@cfg2)).to be true
    end

    it 'has empty diff' do
        expect(@cfg1.diff(@cfg2)).to be nil
    end
end
