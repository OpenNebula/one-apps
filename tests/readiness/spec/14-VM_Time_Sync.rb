require 'init'

RSpec.describe 'Guest time sync' do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        @info = {}

        # clone the template to add guest agent
        tmpl = "sync_time_#{rand(36**8).to_s(36)}"
        cli_action("onetemplate clone #{@defaults[:template]} #{tmpl}")

        # update the template with guest agent
        cli_update("onetemplate update #{tmpl}",
                   "FEATURES=[GUEST_AGENT=\"yes\"]",
                   true)

        @info[:vm_id] = cli_create("onetemplate instantiate #{tmpl}")
        @info[:vm]    = VM.new(@info[:vm_id])

        # delete one-shot template
        cli_action("onetemplate delete #{tmpl}")
    end

    it 'deploys' do
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it 'sets wrong time in VM' do
        @info[:vm].ssh('TZ=UTC date -s \'1995-04-13\'')
        expect(@info[:vm].ssh('TZ=UTC date +%Y-%m-%d').stdout.strip).to eq('1995-04-13')
    end

    it 'suspends' do
        cli_action("onevm suspend #{@info[:vm_id]}")
        @info[:vm].state?("SUSPENDED")
    end

    it 'resumes' do
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it 'synchronized time in VM' do
        c_date = Time.now.getgm.strftime("%Y-%m-%d")

        wait_loop(:timeout => 30) do
            break if @info[:vm].ssh('TZ=UTC date +%Y-%m-%d').stdout.strip != '1995-04-13'
        end

        expect(@info[:vm].ssh('TZ=UTC date +%Y-%m-%d').stdout.strip).not_to eq('1995-04-13')
        expect(@info[:vm].ssh('TZ=UTC date +%Y-%m-%d').stdout.strip).to eq(c_date)
    end

    it 'terminates' do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end
end
