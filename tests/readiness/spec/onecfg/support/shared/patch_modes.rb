require 'rubygems'
require 'pp'

def load_file(name, cls, cls_class)
    err_msg = "File #{name} was expected to load!"

    cfg = cls.new(name)
    expect { cfg.load }.not_to raise_error(Exception), err_msg
    expect(cfg.content).not_to be_nil, err_msg
    expect(cfg.content.class).to be(cls_class), err_msg

    cfg
end

RSpec.shared_examples_for 'patch modes' do |cls, examples|
    examples.each do |e|
        context e[:name] do
            before(:all) do
                @data = { :files => {} }
            end

            it 'loads' do
                e[:files].each do |type, path|
                    cfg = cls.new(one_file_fixture(path))
                    @data[:files][type] = cfg

                    expect { cfg.load }.not_to raise_error(Exception)
                    expect(cfg.content).not_to be_nil

                    # Augeas doesn't have 'empty?' method
                    if defined?(cfg.content.empty?)
                        expect(cfg.content).not_to be_empty
                    end
                end
            end

            it 'diffs' do
                f1 = @data[:files][:dist_old]
                f2 = @data[:files][:dist_new]
                @data[:diff] = f1.diff(f2)

                expect(@data[:diff]).not_to be_nil
            end

            it 'patches' do
                f = @data[:files][:old]

                @data[:ret] = nil
                @data[:rep] = nil

                if e[:fails]
                    expect do
                        @data[:ret], @data[:rep] = f.patch(@data[:diff])
                    end.to raise_error(e[:fails]) do |error|
                        # our patch exceptions must carry
                        # data structure with failing diff
                        # operation
                        expect(error.data).to be_a(Hash)
                    end

                    expect(@data[:ret]).to be_nil
                    expect(@data[:rep]).to be_nil
                end

                # DIRTY WORKAROUND: fail examples are expected to fail always
                if e[:fatal]
                    expect do
                        @data[:ret], @data[:rep] = f.patch(@data[:diff], e[:mode])
                    end.to raise_error(e[:fails]) do |error|
                        # our patch exceptions must carry
                        # data structure with failing diff
                        # operation
                        expect(error.data).to be_a(Hash)
                    end
                else
                    expect do
                        @data[:ret], @data[:rep] = f.patch(@data[:diff], e[:mode])
                    end.not_to raise_error(Exception)

                    # validate we have return and report
                    expect(@data[:ret]).not_to be_nil
                    expect(@data[:ret]).to be(true).or be(false)
                    expect(@data[:rep]).to be_a(Array)
                    expect(@data[:rep]).not_to be_empty
                end
            end

            it 'has valid report' do
                skip('patch expected to always fail') if e[:fatal]

                # report must be of same size as diff
                expect(@data[:rep].length).to be(@data[:diff].length)

                # report must contain some status same as mode
                # (i.e., for :skip mode, there'll be some
                # operation in the report with :mode => :skip),
                # except the dummy mode
                e[:mode].each do |m|
                    next if m == :dummy

                    mode_ops = @data[:rep].select do |r|
                        r[:mode] == m
                    end

                    # NOTE: if more modes are combined, this
                    # doesn't have to be always true!!!
                    # Suitable file fixtures must be provided.
                    err = "Missing #{m} report in #{@data[:rep]}"
                    expect(mode_ops).not_to be_empty, err
                end

                # return value must be true if at least one
                # patch change operation was done
                ret = false
                @data[:rep].map do |r|
                    ret ||= r[:status]
                end

                expect(@data[:ret]).to eq(ret)
            end

            it 'is similar' do
                skip('patch expected to always fail') if e[:fatal]

                f1 = @data[:files][:old]
                f2 = @data[:files][:new]

                diff = f1.diff(f2)

                expect(f1.similar?(f2)).to eq(true), diff
            end

            it 'has empty diff with Hashdiff' do
                skip('patch expected to always fail') if e[:fatal]

                f1 = @data[:files][:old]
                f2 = @data[:files][:new]
                c1 = f1.content
                c2 = f2.content

                skip('only Array/Hash') unless [Array, Hash].include?(c1.class)

                unless f1.strict
                    # sort arrays in non-strict configurations
                    sort_non_strict!(c1)
                    sort_non_strict!(c2)
                end

                diff = Hashdiff.best_diff(c1, c2)
                expect(diff).to be_empty, <<-DBG
Hashdiff was expected to be empty, but a difference found

Hashdiff
--------
#{diff}

Content 1
---------
#{c1}

Content 2
---------
#{c2}
DBG
            end
        end
    end
end
