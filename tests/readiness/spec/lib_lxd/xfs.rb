require 'socket'

shared_examples_for 'XFS_LX' do
    # -o suid on xfs container images
    it 'run several containers with XFS images at the same time' do
        # LVM is skipped because of this https://github.com/OpenNebula/one/issues/5802
        skip unless @defaults[:template_xfs] || Socket.gethostname.include?('lvm')

        vms = []
        cmd = "onetemplate instantiate #{@defaults[:template_xfs]}"

        2.times do
            vms << VM.new(cli_create(cmd))
        end

        vms.each do |vm|
            vm.running?
        end

        # rubocop:disable Style/CombinableLoops
        vms.each do |vm|
            vm.terminate_hard
        end
        # rubocop:enable Style/CombinableLoops
    end
end
