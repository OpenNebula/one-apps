RSpec.shared_examples_for 'invalid configs' do |cls, files|
    before(:all) do
        @cfgs = []
    end

    it 'fails to load' do
        files.each do |name|
            err_msg = "File #{name} was expected to fail on load!"

            cfg = cls.new(name)
            expect { cfg.load }.to raise_error(Exception), err_msg
            expect(cfg.content).to be_nil, err_msg
        end
    end
end
