shared_examples_for 'onedb purge-history' do
    it 'creates 3 VM' do
        1.upto(3) do
            id = cli_create('onevm create --name test --cpu 1 --memory 1')
            vm = VM.new(id)

            cli_action("onevm deploy #{id} #{@hostnames[-1]}")
            vm.running?

            @vms_history << vm
        end
    end

    it 'creates history records for the created VMs' do
        @vms_history.each do |vm|
            2.times do
                @hostnames.each do |hostname|
                    vm.migrate(hostname)
                    vm.running?
                end
            end

            sequences?(vm, 4)
        end
    end

    it 'purges just a single VM history' do
        single_vm = @vms_history[0]

        cmd = "onedb purge-history --id #{single_vm.id}"
        cli_action(cmd)

        sequences?(single_vm, 1)

        @vms_history[1..-1].each do |vm|
            sequences?(vm, 4)
        end
    end

    it 'purges multiple VM history' do
        cli_action('onedb purge-history')

        @vms_history[1..-1].each do |vm|
            sequences?(vm, 1)
        end
    end

    it 'deletes 3 VMs' do
        @vms_history.each do |vm|
            vm.terminate
        end
    end

    def sequences?(vm, amount)
        expect(vm.sequences).to eq(amount)
    end
end
