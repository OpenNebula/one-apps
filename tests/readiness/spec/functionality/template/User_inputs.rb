require 'init_functionality'

RSpec.describe 'Template user inputs' do
    before(:all) do
        template = <<-EOF
            CONTEXT = [
              INPUT = "$INPUT",
              ONE_PASSWORD = "$INPUT",
              NETWORK = "YES",
              SSH_PUBLIC_KEY = "$USER[SSH_PUBLIC_KEY]" ]
            CPU = "0.1"
            GRAPHICS = [
              LISTEN = "0.0.0.0",
              TYPE = "VNC" ]
            INPUTS_ORDER = "INPUT"
            MEMORY = "65536"
            MEMORY_UNIT_COST = "MB"
            NAME = "test"
            MIMO_CONTEXT = "$INPUT"
            OS = [
              BOOT = "" ]
            USER_INPUTS = [
              INPUT = "O|password|Input something" ]
            VCPU = "1"
        EOF

        @template_id = cli_create('onetemplate create', template)
    end

    it 'should instantiate template' do
        vm = cli_create(
            "onetemplate instantiate #{@template_id} " \
            '--user-inputs INPUT=some'
        )
        vm = cli_action_xml("onevm show #{vm} -x --decrypt")

        expect(vm['//CONTEXT/INPUT']).to eq('some')
        expect(vm['//CONTEXT/ONE_PASSWORD']).to eq('some')
    end
end
