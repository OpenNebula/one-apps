require 'hashdiff'

RSpec.shared_examples_for 'comparable configs' do |cls, cls_class, files, same, similar, strict=false|
    before(:all) do
        @cfgs = []
    end

    it 'loads' do
        files.sort.each do |name|
            err_msg = "File #{name} was expected to load!"

            cfg = cls.new(name)
            expect{ cfg.load }.not_to raise_error(Exception), err_msg
            expect(cfg.content).not_to be_nil, err_msg
            expect(cfg.content.class).to be(cls_class), err_msg

            @cfgs << cfg
        end
    end

    it "checks files are #{same ? '' : 'NOT '}same" do
        @cfgs.combination(2).to_a.each do |c|
            err_msg = "Failed combination #{c[0].name} and #{c[1].name}"

            expect(c[0].same?(c[1])).to be(same), err_msg
        end
    end

    it "checks files are #{similar ? '' : 'NOT '}similar" do
        @cfgs.combination(2).to_a.each do |c|
            err_msg = "Failed combination #{c[0].name} and #{c[1].name}"

            expect(c[0].similar?(c[1])).to be(similar), err_msg
        end
    end

    it "checks files are #{similar ? '' : 'NOT '}similar with Hashdiff" do
        skip('only Array/Hash') unless [Array, Hash].include?(cls_class)

        @cfgs.combination(2).to_a.each do |c|
            #TODO: take strict from configuration class
            if strict
                c0 = c[0].content
                c1 = c[1].content
            else
                # for the non-strictly ordered arrays, we have to go
                # recusively into each content and sort arrays to be
                # comparable
                c0 = Marshal.load(Marshal.dump(c[0].content))
                c1 = Marshal.load(Marshal.dump(c[1].content))

                sort_non_strict!(c0)
                sort_non_strict!(c1)
            end

            # safe check via Hashdiff.best_diff
            diff = Hashdiff.best_diff(c0, c1)

            err_msg = """Failed combination #{c[0].name} and #{c[1].name}

Content
-------
#{c0}

Content
-------
#{c1}

Hashdiff.best_diff
------------------
#{diff}
"""

            if similar
                expect(diff).to be_empty, err_msg
            else
                expect(diff).not_to be_empty, err_msg
            end
        end
    end

#    describe "checks files are #{similar ? 'NOT ' : ''}similar" do
#        @cfgs.combination(2).to_a.each do |c|
#            expect(c[0].similar?(c[1])).to be similar
#        end
#    end
end
