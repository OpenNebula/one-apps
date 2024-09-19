require 'init_functionality'

describe 'Migrators files' do
    before(:all) do
        @info = {}

        if @main_defaults && @main_defaults[:build_components]
            @info[:ee] = @main_defaults[:build_components].include?('enterprise')
        else
            @info[:ee] = false
        end
    end

    it 'finds (none or 1) CE migrators and no EE migrators' do
        skip 'only on CE' if @info[:ee]

        expect(Dir['/usr/lib/one/ruby/onedb/local/*.rbm'].size).to eq(0).or eq(1)
        expect(Dir['/usr/lib/one/ruby/onedb/shared/*.rbm'].size).to eq(0).or eq(1)

        # There shouldn't be plain text migrators
        expect(Dir['/usr/lib/one/ruby/onedb/local/*.rb'].size).to eq(0)
        expect(Dir['/usr/lib/one/ruby/onedb/shared/*.rb'].size).to eq(0)
    end

    it 'finds EE migrators and no CE migrators' do
        skip 'only on EE' unless @info[:ee]

        expect(Dir['/usr/lib/one/ruby/onedb/local/*.rb'].size).to be >= 15
        expect(Dir['/usr/lib/one/ruby/onedb/shared/*.rb'].size).to be >= 15

        # There shouldn't be any obfuscated migrator
        expect(Dir['/usr/lib/one/ruby/onedb/local/*.rbm'].size).to eq(0)
        expect(Dir['/usr/lib/one/ruby/onedb/shared/*.rbm'].size).to eq(0)
    end
end
