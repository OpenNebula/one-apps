require 'init_functionality'
require_relative './purge_history'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

describe 'onedb toolset tests' do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    before(:all) do
        cli_update('onedatastore update system', 'TM_MAD=dummy', false)
        cli_update('onedatastore update default', "TM_MAD=dummy\nDS_MAD=dummy", false)
        wait_loop do
            xml = cli_action_xml('onedatastore show -x default')
            xml['FREE_MB'].to_i > 0
        end

        @vms_history = []
        @hostnames = ['red', 'blue']
        @hostnames.each do |hostname|
            id = cli_create("onehost create #{hostname} --im dummy --vm dummy")
            cli_action("onehost show #{id}")
        end

        @vm_id = cli_create('onevm create --name test --cpu 1 --memory 1')
        @vm = VM.new(@vm_id)

        cli_action("onevm deploy #{@vm_id} blue")
        @vm.running?

        @vms = []
    end

    it 'should change the a body value with an xpath expression' do
        xml = @vm.info

        expect(xml['NAME']).to eq('test')

        cli_action("onedb change-body vm --id 0 '/VM/NAME' 'new_test'")

        xml = @vm.info

        expect(xml['NAME']).to eq('new_test')
    end

    it 'should change the a body value with an xpath expression' do
        vm_id1 = cli_create('onevm create --name test1 --cpu 1 --memory 1')
        vm_id2 = cli_create('onevm create --name test2 --cpu 2 --memory 2')
        vm_id3 = cli_create('onevm create --name test3 --cpu 3 --memory 3')

        vm1 = VM.new(vm_id1)
        vm2 = VM.new(vm_id2)
        vm3 = VM.new(vm_id3)

        xml2 = vm2.info

        expect(xml2['NAME']).to eq('test2')
        expect(xml2['TEMPLATE/CPU']).to eq('2')

        cli_action("onedb change-body vm --expr NAME=test2 '/VM/TEMPLATE/CPU' 9")

        xml2 = vm2.info

        expect(xml2['NAME']).to eq('test2')
        expect(xml2['TEMPLATE/CPU']).to eq('9')

        xml3 = vm3.info

        expect(xml3['NAME']).to eq('test3')
        expect(xml3['TEMPLATE/CPU']).to eq('3')

        cli_action("onedb change-body vm --expr NAME=test3 '/VM/TEMPLATE/AUTOMATIC_REQUIREMENTS' --delete")

        xml2 = vm3.info

        expect(xml2['TEMPLATE/AUTOMATIC_REQUIREMENTS']).to be_nil
    end

    include_examples 'onedb purge-history'

    it 'should purge VMs in DONE' do
        cli_action('onevm show 0')
        cli_action('onevm show 1')
        cli_action('onevm show 2')
        cli_action('onevm show 3')
        cli_action('onevm terminate 0..3')
        cli_action('onevm show 0')
        cli_action('onevm show 1')
        cli_action('onevm show 2')
        cli_action('onevm show 3')

        cli_action('onedb purge-done')
        cli_action('onevm show 0', false)
        cli_action('onevm show 1', false)
        cli_action('onevm show 2', false)
        cli_action('onevm show 3', false)
    end

    it "should run 'oned -i'" do
        # NOTE: keep this as last test in this package

        @one_test.stop_one

        cli_action('oned -i')
    end
end
