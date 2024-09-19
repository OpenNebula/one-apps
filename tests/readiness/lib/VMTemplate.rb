require 'oneobject'
require 'VM'

module CLITester

    class VMTemplate < OneObject

        def self.onecmd
            'onetemplate'
        end

        #
        # Instantiates a VM template and validates VM RUNNING status
        #
        # @param [Bool] ssh Validate VM SSH access from the FE
        # @param [String] options custom CLI arguments
        #
        # @return [CLITester::VM]
        #
        def instantiate(ssh = false, options = '')
            vm = VM.instantiate(@id, ssh, options)
            vm.running?
            vm.reachable? if ssh

            vm
        end

        def delete(recursive = false, options = '')
            args = options
            args << ' --recursive' if recursive
            super(args)
        end

    end

end
