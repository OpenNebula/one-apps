require 'init_functionality'

EDITION = '/var/lib/one/remotes/EDITION'

describe 'Check EDITION file' do
    before(:all) do
        @info = {}

        if @main_defaults && @main_defaults[:build_components]
            @info[:ee] = @main_defaults[:build_components].include?('enterprise')
        else
            @info[:ee] = false
        end
    end

    it 'finds EDITION with content CE' do
        skip 'only on CE' if @info[:ee]

        if File.exist?(EDITION)
            expect(File.read(EDITION).strip).to eq('CE')
        else
            skip 'EDITION file not found'
        end
    end

    it 'finds EDITION with content EE' do
        skip 'only on EE' unless @info[:ee]

        if File.exist?(EDITION)
            expect(File.read(EDITION).strip).to eq('EE')
        else
            skip 'EDITION file not found'
        end
    end
end
