require 'init'

RSpec.describe 'Nic Attach q35' do
    before(:all) do
        @info = {}
        @defaults = RSpec.configuration.defaults
        @info[:vm_id] = cli_create("onetemplate instantiate --raw 'OS=[MACHINE=\"q35\"]' \
                                   '#{@defaults[:template]}'")
        @info[:vm] = VM.new(@info[:vm_id])
        @info[:vm].running?
        @info[:vm].reachable?
        @info[:vm].info
    end

    after(:all) do
        @info[:vm].terminate_hard
        @info[:vm].done?
    end

    ############################################################################
    # Attach 4 NICs while running
    ############################################################################

    it 'attach 4 nics to vm while running' do
        exec_ini=@info[:vm].ssh('ip add | grep -e ^[0-9] | grep eth | wc -l')
        ini_nics=exec_ini.stdout.to_i

        (0..3).each do
            cli_action("onevm nic-attach #{@info[:vm_id]} --network 'public'")
            @info[:vm].running?
            @info[:vm].info
        end

        exec_end=@info[:vm].ssh('ip add | grep -e ^[0-9] | grep eth | wc -l')
        end_nics=exec_end.stdout.to_i

        expect(end_nics).to eq ini_nics+4
    end

    ############################################################################
    # Detach 4 NICs while running
    ############################################################################

    it 'detach 4 nics from vm while running' do
        exec_ini=@info[:vm].ssh('ip add | grep -e ^[0-9] | grep eth | wc -l')
        ini_nics=exec_ini.stdout.to_i
        last_nic_id = (@info[:vm]['TEMPLATE/NIC[last()]/NIC_ID']).to_i

        (0..3).each do |n|
            cli_action("onevm nic-detach #{@info[:vm_id]} #{last_nic_id-n}")
            @info[:vm].running?
            @info[:vm].info
        end

        exec_end=@info[:vm].ssh('ip add | grep -e ^[0-9] | grep eth | wc -l')
        end_nics=exec_end.stdout.to_i

        expect(end_nics).to eq ini_nics-4
    end

end
