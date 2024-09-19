require 'rubygems'
require 'hashdiff'

RSpec.shared_examples_for 'automatically upgradable configs' do |cls, cls_class, files, permutations, strict=false|
    before(:all) do
        @cfgs = []
    end

    it 'loads' do
        files.sort_by! do |name|
            vers = name.split('-')[-1]
            Gem::Version.new(vers)
        end

        files.each do |name|
            err_msg = "File #{name} was expected to load!"

            cfg = cls.new(name)
            expect{ cfg.load }.not_to raise_error(Exception), err_msg
            expect(cfg.content).not_to be_nil, err_msg
            expect(cfg.content.class).to be(cls_class), err_msg

            @cfgs << cfg
        end
    end

    it "diff and patch files #{permutations ? '' : '(consecutive only)'}" do
        if permutations
            matrix = @cfgs.permutation(2).to_a.each
        else
            matrix = @cfgs.each_cons(2)
        end

        matrix.each do |c|
            err_msg = "Failed combination #{c[0].name} and #{c[1].name}"

            # generate diff and apply patch
            diff = c[0].diff(c[1])
            expect(diff).not_to be(nil), err_msg
            ret, rep = c[0].patch(diff)
            expect(ret).to be(true), err_msg
            similar = c[0].similar?(c[1])

            if similar
                dbg_err_msg = err_msg
            else
                dbg_err_msg = """#{err_msg}

Diff
----
#{diff}

Patched File
------------
#{c[0].to_s}
"""
            end

            expect(similar).to be(true), dbg_err_msg

            # similar files should have empty diff
            diff = c[0].diff(c[1])
            expect(diff).to be(nil), err_msg

            # for Array/Hash contents, we thoroughly validate
            if [Array, Hash].include?(cls_class)
                c0 = Marshal.load(Marshal.dump(c[0].content))
                c1 = Marshal.load(Marshal.dump(c[1].content))

                # TODO: take strict from comparable configs
                unless strict
                    sort_non_strict!(c0)
                    sort_non_strict!(c1)
                end

                hash_diff = Hashdiff.best_diff(c0, c1)

                dbg_err_msg = """#{err_msg}
Diff
----
#{diff}

Patched Content 0
-----------------
#{c0}

Content 1
---------
#{c1}

Hashdiff.best_diff
------------------
#{hash_diff}
"""

                expect(hash_diff).to be_empty, dbg_err_msg
            end

            # reset source file
            err_msg = "File #{c[0].name} was expected to reload!"
            expect{ c[0].load }.not_to raise_error(Exception), err_msg
            expect(c[0].content).not_to be_nil, err_msg
            expect(c[0].content.class).to be(cls_class), err_msg
        end
    end
end
