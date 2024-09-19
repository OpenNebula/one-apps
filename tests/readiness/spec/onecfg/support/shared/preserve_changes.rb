require 'rubygems'

def load_file(name, cls, cls_class)
    err_msg = "File #{name} was expected to load!"

    cfg = cls.new(name)
    expect{ cfg.load }.not_to raise_error(Exception), err_msg
    expect(cfg.content).not_to be_nil, err_msg
    expect(cfg.content.class).to be(cls_class), err_msg

    cfg
end

RSpec.shared_examples_for 'preserve changes' do |cls, cls_class, custom, stock, target, preserve, block|
    before(:all) do
        @custom = []
        @stock  = []
        @target = []
    end

    it 'loads' do
        custom.each do |name|
            @custom << load_file(name, cls, cls_class)
        end

        stock.each do |name|
            @stock << load_file(name, cls, cls_class)
        end

        target.each do |name|
            @target << load_file(name, cls, cls_class)
        end
    end

    #TODO: missing test for overwriting changes
    it 'diff and patch preserving values' do
        @custom.zip(@stock, @target, preserve) do |c, s, t, p|
            diff = s.diff(t)

            expect(diff).not_to be_nil
            c.patch(diff)

            expect(block.call(c, p)).to eq(true)
        end
    end
end
