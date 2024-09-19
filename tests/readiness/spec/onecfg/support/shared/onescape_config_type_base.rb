RSpec.shared_examples_for 'OneCfg::Config::Type::Base' do |new_count,
                                                            opts = [],
                                                            new_args = []|
    before(:each) do |_example|
        @tmp = Tempfile.new('rspec.')
        @tmp.close
    end

    after(:each) do
        @tmp.unlink
    end

    ###

    it 'initialized' do
        expect(obj).not_to be_nil
        expect(obj.name).not_to be_empty

        if opts.include?(:load)
            expect(obj.content).to be_nil
        else
            expect(obj.content).not_to be_nil
            expect(obj.content).not_to be_empty
        end
    end

    it "respond to #new with #{new_count} arguments" do
        expect(obj.class).to respond_to(:new).with(new_count).arguments
    end

    it 'has strict' do
        expect(obj.strict).to be(true).or be(false)
    end

    it 'respond to #basename' do
        expect(obj).to respond_to(:basename).with(0).arguments
    end

    it 'has valid basename' do
        expect(obj.name).to end_with(obj.basename)
    end

    it 'respond to #exist? with 0..1 arguments' do
        expect(obj).to respond_to(:exist?).with(0..1).arguments
    end

    it 'exist?' do
        expect(File.exist?(obj.name)).to be true
        expect(obj.exist?).to be true

        obj.delete

        expect(File.exist?(obj.name)).to be false
        expect(obj.exist?).to be false
    end

    it 'exist?(custom)' do
        Tempfile.open('rspec') do |tmp|
            fn = tmp.path

            expect(File.exist?(fn)).to be true
            expect(obj.exist?(fn)).to be true

            tmp.close!

            expect(File.exist?(fn)).to be false
            expect(obj.exist?(fn)).to be false
        end
    end

    it 'respond to #reset' do
        expect(obj).to respond_to(:reset).with(0).arguments
    end

    it 'resets' do
        obj.content = 'CONTENT'
        expect(obj.content).to eq('CONTENT')
        obj.reset
        expect(obj.content).to be_nil
    end

    it 'respond to #load with 0..1 arguments' do
        expect(obj).to respond_to(:load).with(0..1).arguments
    end

    it 'returns content on load' do
        skip('Not loadable type') unless opts.include?(:load)

        content = obj.load
        expect(content).not_to be_nil
        expect(content).to be(obj.content)
    end

    it 'respond to #save with 0..1 arguments' do
        expect(obj).to respond_to(:save).with(0..1).arguments
    end

    it 'saves and loads' do
        skip('Not loadable type') unless opts.include?(:load)

        obj.load
        obj.delete
        expect(obj.exist?).to be false
        obj.save

        obj2 = obj.class.new(obj.name, *new_args)
        obj2.content = nil
        obj2.load

        expect(obj2.content).not_to be_nil
        expect(obj2.same?(obj)).to be true
    end

    it 'saves and loads custom' do
        skip('Not loadable type') unless opts.include?(:load)

        obj.load
        obj.delete
        expect(obj.exist?).to be false

        # save and load from custom
        Tempfile.open('rspec') do |tmp|
            fn = tmp.path
            tmp.close!

            expect(File.exist?(fn)).to be false
            expect(obj.exist?(fn)).to be false

            obj.save(fn)

            expect(File.exist?(fn)).to be true
            expect(obj.exist?(fn)).to be true

            obj2 = obj.class.new(nil, *new_args)
            obj2.load(fn)

            expect(obj2.content).not_to be_nil
            expect(obj2.same?(obj)).to be true

            File.unlink(fn) if File.exist?(fn)
        end
    end

    it 'fails to load missing file' do
        skip('Not loadable type') unless opts.include?(:load)

        tmp = Tempfile.new('rspec.')
        fn  = tmp.path
        tmp.close!

        obj.content = 'dummy'
        expect { obj.load(fn) }.to raise_error(Exception)
        expect(obj.content).to be_nil
    end

    it 'fails to save uninitialized content' do
        skip('Not loadable type') unless opts.include?(:load)

        Tempfile.open('rspec') do |tmp|
            expect { obj.save(tmp.path) }.to raise_error(Exception)
        end
    end

    it 'respond to #validate' do
        expect(obj).to respond_to(:validate).with(0).arguments
    end

    it 'respond to #copy with 1 argument' do
        expect(obj).to respond_to(:copy).with(1).arguments
    end

    it 'copies self' do
        skip('Not loadable type') unless opts.include?(:load)

        obj.load

        obj2 = obj.class.new(obj.name, *new_args)
        obj2.copy(obj)
        obj3 = obj.class.new(nil, *new_args)
        obj3.copy(obj)

        # compare objects
        expect(obj.name).to eq(obj2.name)
        expect(obj.name).not_to eq(obj3.name)
        expect(obj.same?(obj2)).to be true
        expect(obj.same?(obj3)).to be true

        # break obj2 and compare
        obj2.content = nil

        expect(obj.same?(obj2)).not_to be true
        expect(obj.same?(obj3)).to be true
    end

    it 'respond to #same? with 1 argument' do
        expect(obj).to respond_to(:same?).with(1).arguments
    end

    it 'is same? self' do
        skip('Not loadable type') unless opts.include?(:load)

        obj.load

        expect(obj.same?(obj)).to be true
    end

    it 'respond to #similar? with 1 argument' do
        expect(obj).to respond_to(:similar?).with(1).arguments
    end

    it 'is similar? self' do
        skip('Not loadable type') unless opts.include?(:load)

        obj.load

        expect(obj.similar?(obj)).to be true
    end

    it 'respond to #diff with 1 argument' do
        expect(obj).to respond_to(:diff).with(1).arguments
    end

    it 'has nil diff on self' do
        skip('Not loadable type') unless opts.include?(:load)
        obj.load

        skip('Not diffable type') unless opts.include?(:diff)
        expect(obj.diff(obj)).to be nil
    end

    it 'has non-empty diff on different' do
        skip('Not loadable type') unless opts.include?(:load)

        obj.load
        obj2.load

        # generate diff
        skip('Not diffable type') unless opts.include?(:diff)
        diff = obj.diff(obj2)
        expect(diff).to be_a(Array)
        expect(diff).not_to be_empty
    end

    # TODO: validate diff format
    # TODO: validate report
    # TODO: get hintings
    # TODO: get hintings w/ report

    it 'respond to #patch with 1..2 arguments' do
        expect(obj).to respond_to(:patch).with(1..2).arguments
    end

    it 'has non-empty patch result on different' do
        skip('Not loadable type') unless opts.include?(:load)

        obj.load
        obj2.load

        # generate diff
        skip('Not diffable type') unless opts.include?(:diff)
        diff = obj.diff(obj2)
        ret, rep = obj.patch(diff)

        # validate we have return and report
        expect(ret).not_to be_nil
        expect(ret).to be(true).or be(false)
        expect(rep).to be_a(Array)
        expect(rep).not_to be_empty
        expect(rep.length).to eq(diff.length)
    end

    it 'doesn\'t patch content on nil diff' do
        obj.content = 'CONTENT'
        expect(obj.content).to eq('CONTENT')
        obj.patch(nil)
        expect(obj.content).to eq('CONTENT')
    end

    # it 'respond to #patch_diff with 2 argument' do
    #     expect(obj).to respond_to(:patch_diff).with(2).arguments
    # end

    it 'respond to #hinting with 1..2 arguments' do
        expect(obj).to respond_to(:hintings).with(1..2).arguments
    end

    it 'returns hintings for all diff operations' do
        skip('Not loadable type') unless opts.include?(:load)

        obj.load
        obj2.load

        skip('Not diffable type') unless opts.include?(:diff)

        diff = obj.diff(obj2)
        expect(diff).to be_a(Array)
        expect(diff).not_to be_empty

        hint = obj.hintings(diff)
        expect(hint.length).to be(diff.length)
    end

    it 'respond to #to_s' do
        expect(obj).to respond_to(:to_s).with(0).arguments
    end

    it 'renders content as string with to_s' do
        skip('Not loadable type') unless opts.include?(:load)

        obj.load

        s = obj.to_s
        expect(s).not_to be_empty

        # if configuration class preserves the formatting,
        # to_s should render to the same content as what we read
        unless opts.include?(:breaks_format)
            expect(s).to eq(File.read(obj.name))
        end
    end

    it 'respond to #delete' do
        expect(obj).to respond_to(:delete).with(0).arguments
    end

    it 'deletes' do
        expect(obj.exist?).to be true
        expect(File.exist?(obj.name)).to be true

        obj.delete

        expect(obj.exist?).to be false
        expect(File.exist?(obj.name)).to be false
    end

    #TODO: do we want this behaviour?
    it 'raises exception on delete of missing file' do
        obj.delete

        expect(obj.exist?).to be false
        expect(File.exist?(obj.name)).to be false

        expect { obj.delete }.to raise_error(Errno::ENOENT)
    end
end
