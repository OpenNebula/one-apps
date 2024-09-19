#-------------------------------------------------------------------------------
# Check OneCfg CE commands availability
#-------------------------------------------------------------------------------

require 'init_functionality'
require 'tempfile'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe 'OneCfg' do
    it 'has patch subcommand' do
        Tempfile.open('onecfg-patch') do |tmp_f|
            tmp_f.puts('/etc/one/oned.conf ins ONECFG_PATCH "\"works\""')
            tmp_f.close

            expect(system('grep -q "ONECFG_PATCH" /etc/one/oned.conf')).to eq(false)
            expect(system("ONECFG_BACKUP_DIR=/var/tmp onecfg patch #{tmp_f.path}")).to eq(true)
            expect(system('grep -q "ONECFG_PATCH" /etc/one/oned.conf')).to eq(true)
        end
    end
end
