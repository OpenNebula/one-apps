require 'init_functionality'

describe 'Manual pages' do
    before(:all) do
        @empty = []
        @commands = []

        Dir.glob('/usr/bin/{one,econe-}*').sort.each do |path|
            command = File.basename(path)
            @commands << File.basename(path) if
                command !~ /^oned?$/ &&
                command !~ /^(onegate|econe-*|onehem-server|oneverify)/ &&
                command !~ /^(oneflow-server|oneirb|onevmdump|onegather)/
        end
    end

    it 'finds commands' do
        expect(@commands.size).to be > 25
    end

    it 'exist for commands' do
        failed = []
        @commands.each do |command|
            cmd = SafeExec.run("man #{command} 2>/dev/null")

            if cmd.fail?
                failed << command
            elsif cmd.stdout.nil? || cmd.stdout.lines.size < 15
                @empty << command
            end
        end

        expect(failed).to be_empty
    end

    it 'are not empty' do
        expect(@empty).to be_empty
    end
end
