require 'init_functionality'
require 'nokogiri'

NUMBER_CONTEXT = 21

def check_alias_context(alias_id)
    vm_xml = Nokogiri::XML(cli_action("onevm show #{@vm_id} -x").stdout)
    ret = 0

    vm_xml.xpath('//TEMPLATE/CONTEXT').children.each do |x|
        ret += 1 if x.name =~ /ETH0_ALIAS#{alias_id}/
    end

    ret
end

def check_nic_context(nic_id)
    vm_xml = Nokogiri::XML(cli_action("onevm show #{@vm_id} -x").stdout)
    ret = 0

    vm_xml.xpath('//TEMPLATE/CONTEXT').children.each do |x|
        ret += 1 if x.name =~ /ETH#{nic_id}_/
    end

    ret
end

def check_leases
    vnet_xml = Nokogiri::XML(cli_action("onevnet show #{@vnet_id} -x").stdout)

    vnet_xml.xpath('//LEASES/LEASE').size
end

def check_quotas
    user_xml = Nokogiri::XML(cli_action('oneuser show testing_alias -x').stdout)

    user_xml.xpath('//NETWORK_QUOTA/NETWORK/LEASES_USED').text.to_i
end

def check_vm_xml(nic)
    vm_xml = Nokogiri::XML(cli_action("onevm show #{@vm_id} -x").stdout)

    if nic
        vm_xml.xpath('//NIC').size
    else
        vm_xml.xpath('//NIC_ALIAS').size
    end
end

def create_file(content)
    file = Tempfile.new('alias')
    file << content
    file.flush
    file.close

    file
end

describe 'NIC alias' do
    prepend_before(:all) do
        @defaults_yaml = File.join(File.dirname(__FILE__), 'defaults.yaml')
    end

    before(:all) do
        @user_id = cli_create('oneuser create testing_alias testing_alias')

        @vnet_id = cli_create('onevnet create', <<-EOT)
            NAME = "alias_n1"
            VN_MAD = "dummy"
            BRIDGE = "dummy"
            AR = [
               TYPE = "IP4",
               IP = "10.0.0.1",
               SIZE = "4"
            ]
        EOT

        file = create_file(<<-EOT)
            NETWORK = [
                ID = "#{@vnet_id}",
                LEASES = "3"
            ]
        EOT

        cli_action("oneuser quota #{@user_id} #{file.path}")

        file.unlink

        cli_action("onevnet chown #{@vnet_id} testing_alias")

        template = cli_create('onetemplate create', <<-EOT)
            NAME = "testing_alias"
            CONTEXT = [
              NETWORK = "yes",
              TOKEN = "yes"
            ]
            CPU  = "1"
            MEMORY = "1024"
            NIC = [
              NAME = "net1",
              NETWORK = "alias_n1"
            ]
            NIC_ALIAS = [
              PARENT = "net1",
              NETWORK = "alias_n1"
            ]
            NIC_ALIAS = [
              PARENT = "net1",
              NETWORK = "alias_n1"
            ]
        EOT

        cli_action("onetemplate chown #{template} testing_alias")

        @host_id = cli_create('onehost create localhost -i dummy -v dummy')

        @vm_id = cli_create("onetemplate instantiate #{template} --user testing_alias --password testing_alias")
        @vm = VM.new(@vm_id)

        cli_action("onevm deploy #{@vm_id} #{@host_id}")
        @vm.running?
    end

    it 'Check vm context' do
        expect(check_nic_context(0)).to eq(3 * NUMBER_CONTEXT)
        expect(check_alias_context(0)).to eq(NUMBER_CONTEXT)
        expect(check_alias_context(1)).to eq(NUMBER_CONTEXT)
    end

    it 'Check vm XML' do
        expect(check_vm_xml(true)).to eq(1)
        expect(check_vm_xml(false)).to eq(2)
    end

    it 'Check user quotas' do
        expect(check_quotas).to eq(3)
    end

    it 'Check alias takes a lease from the vnet' do
        expect(check_leases).to eq(3)
    end

    it 'Try to excced the quota limit with an alias' do
        file = create_file(<<-EOT)
            NIC_ALIAS = [
                PARENT = "net1",
                NETWORK = "alias_n1"
            ]
        EOT

        cli_action("onevm nic-attach #{@vm_id} --file #{file.path} --user testing_alias --password testing_alias", false)

        file.unlink
    end

    it 'Detach an alias' do
        cli_action("onevm nic-detach #{@vm_id} 1 --user testing_alias --password testing_alias")
        @vm.running?
    end

    it 'Check quotas after detach an alias' do
        expect(check_quotas).to eq(2)
    end

    it 'Check vm context after detach an alias' do
        expect(check_nic_context(0)).to eq(2 * NUMBER_CONTEXT)
        expect(check_alias_context(0)).to eq(0)
    end

    it 'Check vm XML after detach an alias' do
        expect(check_vm_xml(true)).to eq(1)
        expect(check_vm_xml(false)).to eq(1)
    end

    it 'Check alias is released after detach an alias' do
        expect(check_leases).to eq(2)
    end

    it 'Attach an alias' do
        file = create_file(<<-EOT)
            NIC_ALIAS = [
                PARENT = "net1",
                NETWORK = "alias_n1"
            ]
        EOT

        cli_action("onevm nic-attach #{@vm_id} --file #{file.path} --user testing_alias --password testing_alias")
        @vm.running?

        file.unlink
    end

    it 'Check quotas after attach an alias' do
        expect(check_quotas).to eq(3)
    end

    it 'Check vm context after attach an alias' do
        expect(check_nic_context(0)).to eq(3 * NUMBER_CONTEXT)
        expect(check_alias_context(2)).to eq(NUMBER_CONTEXT)
    end

    it 'Check vm XML after attach an alias' do
        expect(check_vm_xml(true)).to eq(1)
        expect(check_vm_xml(false)).to eq(2)
    end

    it 'Check alias take a lease from the vnet after ataching' do
        expect(check_leases).to eq(3)
    end

    it 'Detach a NIC with alias' do
        cli_action("onevm nic-detach #{@vm_id} 0 --user testing_alias --password testing_alias")
        @vm.running?
    end

    it 'Check quotas after detach' do
        expect(check_quotas).to eq(0)
    end

    it 'Check vm context after detach' do
        expect(check_nic_context(0)).to eq(0)
        expect(check_alias_context(1)).to eq(0)
        expect(check_alias_context(3)).to eq(0)
    end

    it 'Check vm XML after detach' do
        expect(check_vm_xml(true)).to eq(0)
        expect(check_vm_xml(false)).to eq(0)
    end

    it 'Check alias leases are released from the vnet' do
        expect(check_leases).to eq(0)
    end

    it 'Attach NIC without name' do
        file = create_file(<<-EOT)
            NIC = [
                NETWORK = "alias_n1"
            ]
        EOT

        cli_action("onevm nic-attach #{@vm_id} --file #{file.path} --user testing_alias --password testing_alias")
        @vm.running?

        file.unlink
    end

    it 'Attach NIC alias to generated name' do
        file = create_file(<<-EOT)
            NIC_ALIAS = [
                PARENT = "NIC0",
                NETWORK = "alias_n1"
            ]
        EOT

        cli_action("onevm nic-attach #{@vm_id} --file #{file.path} --user testing_alias --password testing_alias")
        @vm.running?

        file.unlink
    end

    it 'Check alias take a lease from the vnet after ataching bis' do
        expect(check_leases).to eq(2)
    end

    it 'Detach a NIC with alias bis' do
        cli_action("onevm nic-detach #{@vm_id} 0 --user testing_alias --password testing_alias")
    end

    it 'Check alias leases are released from the vnet bis' do
        expect(check_leases).to eq(0)
    end

    it 'Attach a NIC' do
        file = create_file(<<-EOT)
            NIC = [
                NETWORK = "alias_n1"
            ]
        EOT

        cli_action("onevm nic-attach #{@vm_id} --file #{file.path} --user testing_alias --password testing_alias")
        @vm.running?

        file.unlink
    end

    it 'Check nic context' do
        expect(check_nic_context(0)).to eq(NUMBER_CONTEXT)
    end

    it 'Detach a NIC' do
        cli_action("onevm nic-detach #{@vm_id} 0 --user testing_alias --password testing_alias")
        @vm.running?
    end

    it 'Check nic context' do
        expect(check_nic_context(0)).to eq(0)
    end
end
