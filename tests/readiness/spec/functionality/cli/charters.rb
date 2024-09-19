require 'init_functionality'

#-------------------------------------------------------------------------------
# Checks CLI VM charters
#-------------------------------------------------------------------------------

RSpec.describe 'VM charters' do
    before(:all) do
        @vm = cli_create('onevm create --memory 1 --cpu 1 --name "test"')
    end

    it 'should create a VM charter' do
        cli_action("onevm create-chart #{@vm}")

        xml = cli_action_xml("onevm show #{@vm} -x")

        stime = xml['/VM/STIME'].to_i
        time1 = stime + 1209600
        time2 = time1 + 1209600

        warntime1 = stime + 86400
        warntime2 = time1 + 86400

        expect(xml['/VM/TEMPLATE/SCHED_ACTION[ID=0]/ACTION']).to eq('suspend')
        expect(xml['/VM/TEMPLATE/SCHED_ACTION[ID=0]/TIME'].to_i).to be_between(time1, time1+10)
        expect(xml['/VM/TEMPLATE/SCHED_ACTION[ID=0]/WARNING'].to_i).to be_between(warntime1, warntime1+10)

        expect(xml['/VM/TEMPLATE/SCHED_ACTION[ID=1]/ACTION']).to eq('terminate')
        expect(xml['/VM/TEMPLATE/SCHED_ACTION[ID=1]/TIME'].to_i).to be_between(time2, time2+10)
        expect(xml['/VM/TEMPLATE/SCHED_ACTION[ID=1]/WARNING'].to_i).to be_between(warntime2, warntime2+10)
    end

    it 'should delete a VM charter' do
        cli_action("onevm delete-chart #{@vm} 0")

        xml = cli_action_xml("onevm show #{@vm} -x")

        expect(xml['/VM/TEMPLATE/SCHED_ACTION[ID=0]/ACTION']).to be_nil
        expect(xml['/VM/TEMPLATE/SCHED_ACTION[ID=0]/TIME']).to be_nil
    end

    it 'should update a VM charter' do
        template = <<-EOF
            ACTION="terminate"
            ID="1"
            TIME="+7200"
            WARNING="120"
        EOF

        cli_update("onevm update-chart #{@vm} 1", template, false)

        xml = cli_action_xml("onevm show #{@vm} -x")

        stime = xml['/VM/STIME'].to_i

        expect(xml['/VM/TEMPLATE/SCHED_ACTION[ID=1]/ACTION']).to eq('terminate')
        expect(xml['/VM/TEMPLATE/SCHED_ACTION[ID=1]/TIME'].to_i).to be(stime+7200)
        expect(xml['/VM/TEMPLATE/SCHED_ACTION[ID=1]/WARNING'].to_i).to be(120)
    end
end
