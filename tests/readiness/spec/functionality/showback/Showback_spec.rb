require 'init_functionality'

RSpec.describe 'Showback tests' do
    before(:all) do
        # Update TM_MADs
        cli_update('onedatastore update 0', 'TM_MAD=dummy', false)
        cli_update('onedatastore update 1', 'TM_MAD=dummy', false)

        # Create dummy host
        @host_id = cli_create('onehost create localhost -i dummy -v dummy')

        # Create VM template
        template = <<-EOF
                    NAME   = vm_template
                    CPU    = 1
                    MEMORY = 128
                    CPU_COST="1"
                    MEMORY_COST="2"
        EOF

        template_id = cli_create('onetemplate create', template)

        # Instantiate the template multiple times
        @vms = []

        5.times do
            @vms << VM.new(cli_create("onetemplate instantiate #{template_id}"))
        end
    end

    it 'should wait until all VMs are in running state' do
        @vms.each do |vm|
            next if vm.state == 'RUNNING'

            cli_action("onevm deploy #{vm.id} #{@host_id}")
        end

        @vms.each {|vm| vm.running? }

        # Wait 1 minute to simulate some showback
        sleep 60
    end

    # [0] -> RUNNING   computes
    # [1] -> STOPPED   doesn't compute
    # [2] -> SUSPENDED computes
    # [3] -> UNDEPLOY  doesn't compute
    # [4] -> POWEROFF  computes
    it 'should check showback' do
        cli_action("onevm stop #{@vms[1].id}")
        cli_action("onevm suspend #{@vms[2].id}")
        cli_action("onevm undeploy #{@vms[3].id}")
        cli_action("onevm poweroff #{@vms[4].id}")

        # caclulate showback
        cli_action('oneshowback calculate')

        # get current showback
        showback = cli_action_xml('oneshowback list -x')

        h1 = showback["//SHOWBACK[VMID=#{@vms[1].id}]/HOURS"]
        h3 = showback["//SHOWBACK[VMID=#{@vms[3].id}]/HOURS"]

        c0 = showback["//SHOWBACK[VMID=#{@vms[0].id}]/CPU_COST"].to_f
        c1 = showback["//SHOWBACK[VMID=#{@vms[1].id}]/CPU_COST"]
        c2 = showback["//SHOWBACK[VMID=#{@vms[2].id}]/CPU_COST"].to_f
        c3 = showback["//SHOWBACK[VMID=#{@vms[3].id}]/CPU_COST"]
        c4 = showback["//SHOWBACK[VMID=#{@vms[4].id}]/CPU_COST"].to_f

        m0 = showback["//SHOWBACK[VMID=#{@vms[0].id}]/MEMORY_COST"].to_f
        m1 = showback["//SHOWBACK[VMID=#{@vms[1].id}]/MEMORY_COST"]
        m2 = showback["//SHOWBACK[VMID=#{@vms[2].id}]/MEMORY_COST"].to_f
        m3 = showback["//SHOWBACK[VMID=#{@vms[3].id}]/MEMORY_COST"]
        m4 = showback["//SHOWBACK[VMID=#{@vms[4].id}]/MEMORY_COST"].to_f

        # Wait 1 minute to simulate some showback
        sleep 60

        # caclulate showback
        cli_action('oneshowback calculate')

        # get current showback
        showback = cli_action_xml('oneshowback list -x')

        expect(showback["//SHOWBACK[VMID=#{@vms[0].id}]/HOURS"].to_f).to be_between(0.03, 0.06)
        expect(showback["//SHOWBACK[VMID=#{@vms[1].id}]/HOURS"]).to eq(h1)
        expect(showback["//SHOWBACK[VMID=#{@vms[2].id}]/HOURS"].to_f).to be_between(0.03, 0.06)
        expect(showback["//SHOWBACK[VMID=#{@vms[3].id}]/HOURS"]).to eq(h3)
        expect(showback["//SHOWBACK[VMID=#{@vms[4].id}]/HOURS"].to_f).to be_between(0.03, 0.06)

        expect(showback["//SHOWBACK[VMID=#{@vms[0].id}]/CPU_COST"].to_f).to be_between(1.5*c0, 2*c0)
        expect(showback["//SHOWBACK[VMID=#{@vms[1].id}]/CPU_COST"]).to eq(c1)
        expect(showback["//SHOWBACK[VMID=#{@vms[2].id}]/CPU_COST"].to_f).to be_between(1.5*c2, 2*c2)
        expect(showback["//SHOWBACK[VMID=#{@vms[3].id}]/CPU_COST"]).to eq(c3)
        expect(showback["//SHOWBACK[VMID=#{@vms[4].id}]/CPU_COST"].to_f).to be_between(1.5*c4, 2*c4)

        expect(showback["//SHOWBACK[VMID=#{@vms[0].id}]/MEMORY_COST"].to_f).to be_between(1.5*m0, 2*m0)
        expect(showback["//SHOWBACK[VMID=#{@vms[1].id}]/MEMORY_COST"]).to eq(m1)
        expect(showback["//SHOWBACK[VMID=#{@vms[2].id}]/MEMORY_COST"].to_f).to be_between(1.5*m2, 2*m2)
        expect(showback["//SHOWBACK[VMID=#{@vms[3].id}]/MEMORY_COST"]).to eq(m3)
        expect(showback["//SHOWBACK[VMID=#{@vms[4].id}]/MEMORY_COST"].to_f).to be_between(1.5*m4, 2*m4)
    end

    it 'should fail to poweroff a VM and calculate showback' do
        File.open('/tmp/opennebula_dummy_actions/cancel', 'w') do |file|
            file.write("0\n")
        end

        # get current showback
        showback = cli_action_xml('oneshowback list -x')
        h1       = showback["//SHOWBACK[VMID=#{@vms[0].id}]/HOURS"]

        cli_action("onevm poweroff #{@vms[0].id}")

        # Wait 1 minute to simulate some showback
        sleep 60

        expect(showback["//SHOWBACK[VMID=#{@vms[0].id}]/HOURS"].to_f).not_to eq(h1)
        expect(showback["//SHOWBACK[VMID=#{@vms[0].id}]/HOURS"].to_f).to be_between(0.03, 0.06)
    end

    after(:all) do
        FileUtils.rm_r('/tmp/opennebula_dummy_actions')
    end
end
