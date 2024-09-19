require 'init_functionality'

RSpec.describe 'Showback tests' do
    before(:all) do
        # Update TM_MADs
        cli_update('onedatastore update 0', "TM_MAD=dummy\nDS_MAD=dummy", false)
        cli_update('onedatastore update 1', "TM_MAD=dummy\nDS_MAD=dummy", false)

        # Create dummy host
        @host_id  = cli_create('onehost create localhost -i dummy -v dummy')
        @host_id2 = cli_create('onehost create localhost2 -i dummy -v dummy')

        # Create VM template
        template = <<-EOF
                    NAME   = vm_template
                    CPU    = 1
                    MEMORY = 128
        EOF

        @net_id = cli_create("onevnet create", <<-EOT)
            NAME = "test_vnet"
            VN_MAD = "dummy"
            BRIDGE = "dummy"
            AR = [
               TYPE = "IP4",
               IP = "10.0.0.1",
               SIZE = "200"
            ]
        EOT

        @img_id = cli_create("oneimage create -d default --no_check_capacity", <<-EOT)
            NAME = "test_img"
            TYPE = "DATABLOCK"
            FSTYPE = "ext3"
            SIZE = 1000
        EOT

        @template_id = cli_create('onetemplate create', template)

        @vm = VM.new(cli_create("onetemplate instantiate #{@template_id}"))

        cli_action("onevm deploy #{@vm.id} #{@host_id}")
    end

    def check_htimes(vm, seq)
        xml = vm.info

        htime = []

        %w(STIME ETIME PSTIME PETIME RSTIME RETIME ESTIME EETIME ACTION).each{ |w|
          htime << xml["HISTORY_RECORDS/HISTORY[ SEQ = #{seq} ]/#{w}"].to_i
        }

        htime
    end

    def open?(htimes)
        expect(htimes[0] > 0 && htimes[1] == 0).to be true
    end

    def closed?(htimes)
        expect(htimes[0] > 0 && htimes[1] >= htimes[0]).to be true
    end

    def prolog_closed?(htimes)
        expect(htimes[2] > 0 && htimes[3] >= htimes[2]).to be true
    end

    def prolog_open?(htimes)
        expect(htimes[2] > 0 && htimes[3] == 0).to be true
    end

    def running_closed?(htimes)
        expect(htimes[4]).to be > 0
        expect(htimes[5]).to be >= htimes[4]
    end

    def running_open?(htimes)
        expect(htimes[4] > 0 && htimes[5] == 0).to be true
    end

    def epilog_closed?(htimes)
        expect(htimes[6] > 0 && htimes[7] >= htimes[6]).to be true
    end

    def epilog_open?(htimes)
        expect(htimes[6] > 0 && htimes[7] == 0).to be true
    end

    it 'should have a record on RUNNING with STIME' do
        @vm.running?

        htime = check_htimes(@vm, 0)

        open?(htime)

        prolog_closed?(htime)

        running_open?(htime)
    end

    it 'should add records for poweroff - poweron cycles' do
        cli_action("onevm poweroff #{@vm.id}")

        @vm.state?('POWEROFF')

        htime = check_htimes(@vm, 0)

        open?(htime)

        prolog_closed?(htime)

        running_closed?(htime)

        expect(htime[8]).to be 19 #poweroff

        sleep 1

        cli_action("onevm resume #{@vm.id}")

        @vm.running?

        htime = check_htimes(@vm, 0)

        closed?(htime)

        prolog_closed?(htime)

        running_closed?(htime)

        closed?(htime)

        expect(htime[5]).to be < htime[1] # RETIME < ETIME

        htime = check_htimes(@vm, 1)

        open?(htime)

        running_open?(htime)

        expect(htime[8]).to be 0   #action none
    end

    it 'should add records for suspend - resume cycles' do
        cli_action("onevm suspend #{@vm.id}")

        @vm.state?('SUSPENDED')

        htime = check_htimes(@vm, 1)

        open?(htime)

        running_closed?(htime)

        expect(htime[8]).to be 10   #action suspend

        sleep 1

        cli_action("onevm resume #{@vm.id}")

        @vm.running?

        htime = check_htimes(@vm, 1)

        closed?(htime)

        running_closed?(htime)

        expect(htime[5]).to be < htime[1] # RETIME < ETIME

        expect(htime[8]).to be 10   #action suspend

        htime = check_htimes(@vm, 2)

        open?(htime)

        running_open?(htime)

        expect(htime[8]).to be 0
    end

    it 'should record disk attach actions and keep open records' do

        cli_action("onevm disk-attach #{@vm.id} --image #{@img_id}")

        htime = check_htimes(@vm, 2)

        closed?(htime)

        running_closed?(htime)

        expect(htime[8]).to be 21

        htime = check_htimes(@vm, 3)

        open?(htime)

        running_open?(htime)

        expect(htime[8]).to be 0

        cli_action("onevm poweroff #{@vm.id}")

        @vm.state?('POWEROFF')

        htime = check_htimes(@vm, 3)

        open?(htime)

        running_closed?(htime)

        cli_action("onevm disk-detach #{@vm.id} 0")

        htime = check_htimes(@vm, 3)

        closed?(htime)

        running_closed?(htime)

        expect(htime[8]).to be 22

        htime = check_htimes(@vm, 4)

        open?(htime)

        running_closed?(htime)

        expect(htime[8]).to be 19

        sleep 1

        cli_action("onevm resume #{@vm.id}")

        @vm.running?

        htime = check_htimes(@vm, 4)

        closed?(htime)

        running_closed?(htime)

        expect(htime[5]).to be < htime[1] # RETIME < ETIME

        expect(htime[8]).to be 19   #action suspend

        htime = check_htimes(@vm, 5)

        open?(htime)

        running_open?(htime)

        expect(htime[8]).to be 0
    end

    it 'should record nic attach actions and keep open records' do

        cli_action("onevm nic-attach #{@vm.id} --network #{@net_id}")

        htime = check_htimes(@vm, 5)

        closed?(htime)

        running_closed?(htime)

        expect(htime[8]).to be 23

        htime = check_htimes(@vm, 6)

        open?(htime)

        running_open?(htime)

        expect(htime[8]).to be 0

        cli_action("onevm poweroff #{@vm.id}")

        @vm.state?('POWEROFF')

        htime = check_htimes(@vm, 6)

        open?(htime)

        running_closed?(htime)

        cli_action("onevm nic-detach #{@vm.id} 0")

        htime = check_htimes(@vm, 6)

        closed?(htime)

        running_closed?(htime)

        expect(htime[8]).to be 24

        htime = check_htimes(@vm, 7)

        open?(htime)

        running_closed?(htime)

        expect(htime[8]).to be 19

        sleep 1

        cli_action("onevm resume #{@vm.id}")

        @vm.running?

        htime = check_htimes(@vm, 7)

        closed?(htime)

        running_closed?(htime)

        expect(htime[5]).to be < htime[1] # RETIME < ETIME

        expect(htime[8]).to be 19   #action suspend

        htime = check_htimes(@vm, 8)

        open?(htime)

        running_open?(htime)

        expect(htime[8]).to be 0
    end

    it 'should record stop/resume records' do
        cli_action("onevm stop #{@vm.id}")

        @vm.state?('STOPPED')

        htime = check_htimes(@vm, 8)

        closed?(htime)

        running_closed?(htime)

        epilog_closed?(htime)

        expect(htime[8]).to be 9

        cli_action("onevm resume #{@vm.id}")

        cli_action("onevm deploy #{@vm.id} #{@host_id}")

        @vm.running?

        htime = check_htimes(@vm, 9)

        open?(htime)

        prolog_closed?(htime)

        running_open?(htime)

        expect(htime[8]).to be 0
    end

    it 'should record undeploy/resume records' do
        cli_action("onevm undeploy #{@vm.id}")

        @vm.state?('UNDEPLOYED')

        htime = check_htimes(@vm, 9)

        closed?(htime)

        running_closed?(htime)

        epilog_closed?(htime)

        expect(htime[8]).to be 5

        cli_action("onevm resume #{@vm.id}")

        cli_action("onevm deploy #{@vm.id} #{@host_id}")

        @vm.running?

        htime = check_htimes(@vm, 10)

        open?(htime)

        prolog_closed?(htime)

        running_open?(htime)

        expect(htime[8]).to be 0
    end

    it 'should record migrate records' do
        cli_action("onevm migrate #{@vm.id} #{@host_id2}")

        @vm.running?

        htime = check_htimes(@vm, 10)

        closed?(htime)

        prolog_closed?(htime)

        running_closed?(htime)

        expect(htime[8]).to be 1

        htime = check_htimes(@vm, 11)

        open?(htime)

        prolog_closed?(htime)

        running_open?(htime)

        expect(htime[8]).to be 0
    end

    it 'should record live-migrate records' do
        cli_action("onevm migrate #{@vm.id} #{@host_id}")

        @vm.running?

        htime = check_htimes(@vm, 11)

        closed?(htime)

        prolog_closed?(htime)

        running_closed?(htime)

        expect(htime[8]).to be 1

        htime = check_htimes(@vm, 12)

        open?(htime)

        running_open?(htime)

        expect(htime[8]).to be 0
    end

    it 'should fail attaching nic and leave running open' do
        File.open('/tmp/opennebula_dummy_actions/attach_nic', 'w') do |file|
            file.write("0\n")
        end

        cli_action("onevm nic-attach #{@vm.id} --network #{@net_id}")

        @vm.running?

        htime = check_htimes(@vm, 12)

        closed?(htime)

        prolog_closed?(htime)

        running_closed?(htime)

        expect(htime[8]).to be 23 # nic-attach

        htime = check_htimes(@vm, 13)

        open?(htime)

        running_open?(htime)

        expect(htime[8]).to be 0
    end

    it 'should fail to deploy and open history on recover success' do
        File.open('/tmp/opennebula_dummy_actions/deploy', 'w') do |file|
            file.write("0\n")
        end

        cli_action("onevm undeploy #{@vm.id}")

        @vm.state?('UNDEPLOYED')

        cli_action("onevm deploy #{@vm.id} #{@host_id}")

        @vm.state?('BOOT_UNDEPLOY_FAILURE', 'RUNNING')

        htime = check_htimes(@vm, 14)

        closed?(htime)

        prolog_closed?(htime)

        running_closed?(htime)

        expect(htime[8]).to be 0

        cli_action("onevm recover --success #{@vm.id}")

        @vm.running?

        htime = check_htimes(@vm, 14)

        open?(htime)

        prolog_closed?(htime)

        running_open?(htime)
    end

    it 'should fail to deploy and close history on recover delete' do
        cli_action("onevm undeploy #{@vm.id}")

        @vm.state?('UNDEPLOYED')

        cli_action("onevm deploy #{@vm.id} #{@host_id}")

        @vm.state?('BOOT_UNDEPLOY_FAILURE', 'RUNNING')

        htime = check_htimes(@vm, 14)

        closed?(htime)

        prolog_closed?(htime)

        running_closed?(htime)

        expect(htime[8]).to be 5

        etime = htime[1]
        retime = htime[5]

        cli_action("onevm recover --delete #{@vm.id}")

        @vm.done?

        htime = check_htimes(@vm, 14)

        closed?(htime)

        prolog_closed?(htime)

        running_closed?(htime)

        expect(htime[1]).to be etime
        expect(htime[5]).to be retime
    end

    after(:all) do
        FileUtils.rm_r('/tmp/opennebula_dummy_actions')
    end
end
