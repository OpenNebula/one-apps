require 'rubygems'
require 'pp'

def load_file(name, cls, cls_class)
    err_msg = "File #{name} was expected to load!"

    cfg = cls.new(name)
    expect{ cfg.load }.not_to raise_error(Exception), err_msg
    expect(cfg.content).not_to be_nil, err_msg
    expect(cfg.content.class).to be(cls_class), err_msg

    cfg
end

RSpec.shared_examples_for 'old patch modes' do |cls, cls_class, patch, base, files|
    before(:all) do
        @original = load_file(patch, cls, cls_class)
        @patch    = load_file(patch, cls, cls_class)
        @base     = load_file(base, cls, cls_class)
        @cfgs     = []
    end

    it 'loads' do
        files.each do |name|
            @cfgs << load_file(name, cls, cls_class)
        end
    end

    it 'diff and patch in skip mode' do
        @cfgs.each do |file|
            diff = @base.diff(file)

            expect(diff).not_to be_nil

            STDERR.puts "Src:   #{@base.name}"
            STDERR.puts "Tgt:   #{file.name}"
            STDERR.puts "Patch: #{@patch.name}"
            STDERR.puts diff.pretty_inspect
            @patch.patch(diff, [:skip])

            expect(@original.similar?(@patch)).to eq(true)
            expect(@original.same?(@patch)).to eq(true)
        end
    end

    it 'diff and patch in none mode' do
        @cfgs.each do |file|
            diff = @base.diff(file)

            expect(diff).not_to be_nil

            expect{ @patch.patch(diff, :none) }.to raise_error(Exception)
        end
    end
end
