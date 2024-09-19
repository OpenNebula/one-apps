
#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
require 'VN'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

describe "VirtualMachine CONTEXT section test" do

    prepend_before(:all) do
        @defaults_yaml = File.join(File.dirname(__FILE__), 'defaults.yaml')
    end

    before(:all) do
        cli_update("onedatastore update system", "TM_MAD=dummy", false)
        cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)
        wait_loop() {
            xml = cli_action_xml("onedatastore show -x default")
            xml['FREE_MB'].to_i > 0
        }

        @tmp_file = Tempfile.new('one')
        tmp_file_path = @tmp_file.path

        cli_create("onehost create host01 --vm dummy --im dummy")

        @image = cli_create("oneimage create --name testimage --type OS " <<
                            "--target hda --path #{tmp_file_path} -d default")
    end

    it "should allocate a VirtualMachine that specifies a CONTEXT section" do
        vm_id = cli_create("onevm create", <<-EOT)
            CPU=1
            MEMORY=1
            DISK=[IMAGE_ID=#{@image}]
            CONTEXT=[
                HOSTNAME=mainhost,
                TARGET=hdb ]
        EOT
        vm = VM.new(vm_id)

        xml = vm.info
        expect(xml['TEMPLATE/CONTEXT/HOSTNAME']).to eq "mainhost"
    end

    it "should allocate a VirtualMachine that specifies a CONTEXT section" <<
        " that defines an attribute using a template variable" do

        vm_id = cli_create("onevm create", <<-EOT)
            CPU=1
            MEMORY=1
            DISK=[IMAGE_ID=#{@image}]
            CONTEXT=[
                IP_GEN="10.0.0.$VMID",
                TARGET=hdb ]
        EOT
        vm = VM.new(vm_id)

        xml = vm.info
        expect(xml['TEMPLATE/CONTEXT/IP_GEN']).to eq "10.0.0.#{vm_id}"
    end

    it "should allocate a VirtualMachine that specifies a CONTEXT section" <<
        " that defines an attribute using a template multiple value variable" do

        vm_id = cli_create("onevm create", <<-EOT)
            CPU=1
            MEMORY=1
            DISK=[IMAGE_ID=#{@image}]
            CONTEXT=[
                TEST1="$DISK[IMAGE_ID]",
                TARGET=hdb ]
        EOT
        vm = VM.new(vm_id)

        xml = vm.info
        expect(xml['TEMPLATE/CONTEXT/TEST1']).to eq "#{@image}"
    end

    it "should allocate a VirtualMachine that specifies a CONTEXT section" <<
        " that defines an attribute using a template multiple value variable" <<
        " setting one atribute to discern between multiple variables" do

        image = cli_create("oneimage create --name secimage --type CDROM " <<
                           "--target hdc --path #{@tmp_file.path} -d default")

        # This test crashes oned
        #
        # vm_id = cli_create("onevm create", <<-EOT)
        #     CPU=1
        #     MEMORY=256
        #     DISK=[IMAGE_ID=#{image}]
        #     DISK=[IMAGE_ID=#{@image}]
        #     CONTEXT=[
        #         TEST2="$DISK[IMAGE_ID,TYPE=\\"CDROM\\"]",
        #         TARGET=hdb ]
        # EOT
        # vm = VM.new(vm_id)

        # xml = vm.info
        # expect(xml['TEMPLATE/CONTEXT/TEST2']).to eq "#{image}"
    end

    it "should allocate a VirtualMachine that specifies a CONTEXT section" <<
        " that defines an attribute using a VirtualNetwork value variable" do

        vnet = VN.create(<<-EOT)
            NAME = "network"
            AR = [
                TYPE = "IP4",
                IP = "10.0.0.1",
                SIZE = "200" ]
            BRIDGE = "eth0"
            NETWORK_ADDRESS = "10.0.0.0"
            GATEWAY = "10.0.0.1"
            VN_MAD = "dummy"
        EOT
        vnet.ready?

        vm_id = cli_create("onevm create", <<-EOT)
            CPU=1
            MEMORY=1
            DISK=[IMAGE_ID=#{@image}]
            NIC=[NETWORK_ID=#{vnet.id}]
            CONTEXT=[
                TEST3="$NETWORK[GATEWAY, NETWORK_ID=#{vnet.id}]",
                TARGET=hdb ]
        EOT
        vm = VM.new(vm_id)

        xml = vm.info
        expect(xml['TEMPLATE/CONTEXT/TEST3']).to eq "10.0.0.1"
    end

    it "should allocate a VirtualMachine that specifies a CONTEXT section" <<
        " usign VNET, NIC and CONTEXT ETH_* overwrites" do
        vnet = VN.create(<<-EOT)
            NAME = "network_context"
            AR = [
                TYPE = "IP4",
                IP = "10.0.0.1",
                SIZE = "200",
                GATEWAY = "AR_GW" ]
            BRIDGE = "eth0"
            NETWORK_ADDRESS = "10.0.0.0"
            GATEWAY = "NET_GW"
            DNS = "NET_DNS"
            VN_MAD = "dummy"
        EOT
        vnet.ready?

        vm_id = cli_create("onevm create", <<-EOT)
            CPU=1
            MEMORY=1
            DISK=[IMAGE_ID=#{@image}]
            NIC=[NETWORK_ID=#{vnet.id}]
            NIC=[NETWORK_ID=#{vnet.id},DNS=NIC_DNS]
            NIC=[NETWORK_ID=#{vnet.id}]
            CONTEXT=[
                NETWORK=YES,
                ETH2_DNS=CONTEXT_DNS,
                TEST3="$NETWORK[GATEWAY, NETWORK_ID=#{vnet.id}]",
                TARGET=hdb ]
        EOT
        vm = VM.new(vm_id)

        xml = vm.info
        expect(xml['TEMPLATE/CONTEXT/ETH0_GATEWAY']).to eq "AR_GW"
        expect(xml['TEMPLATE/CONTEXT/ETH0_DNS']).to eq "NET_DNS"
        expect(xml['TEMPLATE/CONTEXT/ETH1_DNS']).to eq "NIC_DNS"
        expect(xml['TEMPLATE/CONTEXT/ETH2_DNS']).to eq "NET_DNS"
    end

    it "should get all ETH_* variables for IP and IP6 vnets" do
        vnet = VN.create(<<-EOT)
            NAME = "network_context_full"
            AR = [
                TYPE = "IP4_6",
                IP = "10.0.0.1",
                NETWORK_MASK="255.0.0.0",
                NETWORK_ADDRESS="10.0.0.0",
                GLOBAL_PREFIX = "2001:0:0:a::",
                ULA_PREFIX = "fd00:0:0:b::",
                SIZE = "200",
                GATEWAY6 = "fe80::1",
                SEARCH_DOMAIN = "test",
                GUEST_MTU = 1500,
                VLAN_ID = "22" ]
            BRIDGE = "eth0"
            GATEWAY = "NET_GW"
            DNS = "NET_DNS"
            VN_MAD = "dummy"
        EOT
        vnet.ready?

        vm_id = cli_create("onevm create", <<-EOT)
            CPU=1
            MEMORY=1
            DISK=[IMAGE_ID=#{@image}]
            NIC=[NETWORK_ID=#{vnet.id}]
            CONTEXT=[ NETWORK=YES ]
        EOT
        vm = VM.new(vm_id)

        xml = vm.info

        ip   = xml['TEMPLATE/NIC/IP']
        mac  = xml['TEMPLATE/NIC/MAC']
        ip6  =  xml['TEMPLATE/NIC/IP6_GLOBAL']
        ip6u =  xml['TEMPLATE/NIC/IP6_ULA']

        expect(xml['TEMPLATE/CONTEXT/ETH0_IP']).to eq ip
        expect(xml['TEMPLATE/CONTEXT/ETH0_MAC']).to eq mac
        expect(xml['TEMPLATE/CONTEXT/ETH0_MASK']).to eq "255.0.0.0"
        expect(xml['TEMPLATE/CONTEXT/ETH0_NETWORK']).to eq "10.0.0.0"
        expect(xml['TEMPLATE/CONTEXT/ETH0_GATEWAY']).to eq "NET_GW"
        expect(xml['TEMPLATE/CONTEXT/ETH0_DNS']).to eq "NET_DNS"
        expect(xml['TEMPLATE/CONTEXT/ETH0_SEARCH_DOMAIN']).to eq "test"
        expect(xml['TEMPLATE/CONTEXT/ETH0_MTU']).to eq "1500"
        expect(xml['TEMPLATE/CONTEXT/ETH0_VLAN_ID']).to eq "22"


        expect(xml['TEMPLATE/CONTEXT/ETH0_IP6']).to eq ip6
        expect(xml['TEMPLATE/CONTEXT/ETH0_IP6_ULA']).to eq ip6u
        expect(xml['TEMPLATE/CONTEXT/ETH0_IP6_GATEWAY']).to eq "fe80::1"
    end

    it "should get all ETH_* variables for IP6 static vnets" do
        vnet = VN.create(<<-EOT)
            NAME = "network_context_full6"
            AR = [
                TYPE = "IP6_STATIC",
                IP6 = "2001:0:0:a::1",
                SIZE = "200",
                PREFIX_LENGTH=48,
                GATEWAY6 = "fe80::1",
                VLAN_ID = "22" ]
            BRIDGE = "eth0"
            GATEWAY = "NET_GW"
            DNS = "NET_DNS"
            VN_MAD = "dummy"
        EOT
        vnet.ready?

        vm_id = cli_create("onevm create", <<-EOT)
            CPU=1
            MEMORY=1
            DISK=[IMAGE_ID=#{@image}]
            NIC=[NETWORK_ID=#{vnet.id}]
            CONTEXT=[ NETWORK=YES ]
        EOT

        vm = VM.new(vm_id)

        xml = vm.info

        mac  = xml['TEMPLATE/NIC/MAC']
        ip6  = xml['TEMPLATE/NIC/IP6']

        expect(xml['TEMPLATE/CONTEXT/ETH0_MAC']).to eq mac

        expect(xml['TEMPLATE/CONTEXT/ETH0_IP6']).to eq ip6
        expect(xml['TEMPLATE/CONTEXT/ETH0_IP6_ULA']).to eq ""
        expect(xml['TEMPLATE/CONTEXT/ETH0_IP6_PREFIX_LENGTH']).to eq "48"
    end

    it "should allocate a VirtualMachine that specifies a CONTEXT section" <<
        " and check \$ works well" do

        vm_id = cli_create("onevm create", <<-EOT)
            CPU=1
            MEMORY=1
            CONTEXT=[
                aa=aa,
                TARGET=hdb,
                TAG1=STR\\$,
                TAG2=\\$STR,
                TAG3=STR1\\$1STR,
                TAG4=$STR,
                TAG5=STR1$STR ]

        EOT

        vm = VM.new(vm_id)

        xml = vm.info

        expect(xml['TEMPLATE/CONTEXT/TAG1']).to eq "STR\\$"
        expect(xml['TEMPLATE/CONTEXT/TAG2']).to eq "\\$STR"
        expect(xml['TEMPLATE/CONTEXT/TAG3']).to eq "STR1\\$1STR"
        expect(xml['TEMPLATE/CONTEXT/TAG4']).to eq ""
        expect(xml['TEMPLATE/CONTEXT/TAG5']).to eq "STR1"

        cli_action("onevm deploy #{vm_id} 0")

        vm = VM.new(vm_id)
        vm.running?

        cli_action("onevm poweroff --hard #{vm_id}")

        vm.state? 'POWEROFF'

        expect(xml['TEMPLATE/CONTEXT/TAG1']).to eq "STR\\$"
        expect(xml['TEMPLATE/CONTEXT/TAG2']).to eq "\\$STR"
        expect(xml['TEMPLATE/CONTEXT/TAG3']).to eq "STR1\\$1STR"
        expect(xml['TEMPLATE/CONTEXT/TAG4']).to eq ""
        expect(xml['TEMPLATE/CONTEXT/TAG5']).to eq "STR1"

    end

    it "should try to allocate a VirtualMachine that specifies a bad CONTEXT section" <<
    " and fails" do
        template = <<-EOT
        CPU=1
        MEMORY=1
        CONTEXT=[
            aa=aa,
            TARGET=hdb,
            TAG6=STR$
        ]
        EOT

        cli_create("onevm create", template, false)
    end

    it "should allocate a VirtualMachine that specifies a CONTEXT section" <<
        " with ETH*_METRIC using VNET *AND* NIC 'METRIC' attributes" do
        vnet0 = VN.create(<<-EOT)
            NAME = "metric_context0"
            AR = [
                TYPE = "IP4",
                IP = "10.0.0.100",
                SIZE = "100",
                GATEWAY = "AR0_GW" ]
            BRIDGE = "eth0"
            NETWORK_ADDRESS = "10.0.0.0"
            GATEWAY = "NET0_GW"
            DNS = "NET0_DNS"
            VN_MAD = "dummy"
        EOT
        vnet1 = VN.create(<<-EOT)
            NAME = "metric_context1"
            AR = [
                TYPE = "IP4",
                IP = "10.0.1.100",
                SIZE = "100",
                GATEWAY = "AR1_GW",
                METRIC = "100" ]
            BRIDGE = "eth1"
            NETWORK_ADDRESS = "10.0.1.0"
            GATEWAY = "NET1_GW"
            DNS = "NET1_DNS"
            VN_MAD = "dummy"
        EOT
        vnet2 = VN.create(<<-EOT)
            NAME = "metric_context2"
            AR = [
                TYPE = "IP4",
                IP = "10.0.2.100",
                SIZE = "100",
                GATEWAY = "AR2_GW" ]
            BRIDGE = "eth2"
            NETWORK_ADDRESS = "10.0.2.0"
            GATEWAY = "NET2_GW"
            DNS = "NET2_DNS"
            METRIC = "200"
            VN_MAD = "dummy"
        EOT
        vnet2.ready?

        vm_id = cli_create("onevm create", <<-EOT)
            CPU=1
            MEMORY=1
            DISK=[IMAGE_ID=#{@image}]
            NIC=[NETWORK_ID=#{vnet0.id}]
            NIC=[NETWORK_ID=#{vnet1.id}]
            NIC=[NETWORK_ID=#{vnet2.id}]
            NIC=[NETWORK_ID=#{vnet0.id},METRIC=0]
            NIC=[NETWORK_ID=#{vnet1.id},METRIC=111]
            NIC=[NETWORK_ID=#{vnet2.id},METRIC=222]
            CONTEXT=[
                NETWORK=YES,
                TARGET=hdb ]
        EOT
        vm = VM.new(vm_id)

        xml = vm.info
        #STDERR.puts xml.template_like_str("TEMPLATE", true)

        expect(xml['TEMPLATE/CONTEXT/ETH0_METRIC']).to eq ""
        expect(xml['TEMPLATE/CONTEXT/ETH1_METRIC']).to eq "100"
        expect(xml['TEMPLATE/CONTEXT/ETH2_METRIC']).to eq "200"
        expect(xml['TEMPLATE/CONTEXT/ETH3_METRIC']).to eq "0"
        expect(xml['TEMPLATE/CONTEXT/ETH4_METRIC']).to eq "111"
        expect(xml['TEMPLATE/CONTEXT/ETH5_METRIC']).to eq "222"
    end

    it "should fail to update ETH values in context" do
        vnet = VN.create(<<-EOT)
            NAME = "network_fail_update"
            AR = [
                TYPE = "IP4",
                IP = "10.0.10.1",
                SIZE = "10" ]
            BRIDGE = "eth0"
            NETWORK_ADDRESS = "10.0.10.0"
            GATEWAY = "10.0.10.1"
            VN_MAD = "dummy"
        EOT
        vnet.ready?

        vm_id = cli_create("onevm create", <<-EOT)
            CPU = 1
            MEMORY = 1
            DISK = [ IMAGE_ID=#{@image} ]
            NIC = [ NETWORK_ID=#{vnet.id} ]
            CONTEXT = [
                NETWORK = YES,
                TEETH1_A = "aaa"
            ]
        EOT
        vm = VM.new(vm_id)

        xml = vm.info

        expect(xml['TEMPLATE/CONTEXT/ETH0_IP']).to eq "10.0.10.1"
        expect(xml['TEMPLATE/CONTEXT/ETH0_GATEWAY']).to eq "10.0.10.1"
        expect(xml['TEMPLATE/CONTEXT/ETH0_METHOD']).to eq ""
        expect(xml['TEMPLATE/CONTEXT/ETH0_NEW']).to be_nil
        expect(xml['TEMPLATE/CONTEXT/TEETH1_A']).to eq "aaa"

        # Should update Context variable with name similar to ETHx_y
        cli_update("onevm updateconf #{vm.id}", <<-EOT, false)
            CONTEXT = [
                NETWORK = YES,
                TEETH1_A = "bbb"
            ]
            EOT

        xml = vm.info

        # ETH0_* values should not change
        expect(xml['TEMPLATE/CONTEXT/ETH0_IP']).to eq "10.0.10.1"
        expect(xml['TEMPLATE/CONTEXT/ETH0_GATEWAY']).to eq "10.0.10.1"
        expect(xml['TEMPLATE/CONTEXT/ETH0_METHOD']).to eq ""
        expect(xml['TEMPLATE/CONTEXT/TEETH1_A']).to eq "bbb"

        # Should fail to update Context ETHx_y values
        cli_update("onevm updateconf #{vm.id}", <<-EOT, false, false)
            CONTEXT = [
                NETWORK=YES,
                ETH0_IP = "1.2.3.4"
            ]
            EOT
        cli_update("onevm updateconf #{vm.id}", <<-EOT, true, false)
            CONTEXT = [
                ETH0_METHOD = "should_fail"
            ]
            EOT
        cli_update("onevm updateconf #{vm.id}", <<-EOT, true, false)
            CONTEXT = [
                ETH0_NEW = "should_fail"
            ]
            EOT

        xml = vm.info

        # Double check values are not changed
        expect(xml['TEMPLATE/CONTEXT/ETH0_IP']).to eq "10.0.10.1"
        expect(xml['TEMPLATE/CONTEXT/ETH0_GATEWAY']).to eq "10.0.10.1"
        expect(xml['TEMPLATE/CONTEXT/ETH0_METHOD']).to eq ""
        expect(xml['TEMPLATE/CONTEXT/ETH0_NEW']).to be_nil
        expect(xml['TEMPLATE/CONTEXT/TEETH1_A']).to eq "bbb"
    end

    it "should allocate a VM with CONTEXT/FILES in SAFE_DIRS" do
        FileUtils.mkdir_p('/var/lib/one/tmp')

        Tempfile.create('context_file', '/var/lib/one/tmp') do |f|
            path = "/tmp/../var/lib/one/tmp/#{File.basename(f.path)}"
            vm_id = cli_create("onevm create", <<-EOT)
                CPU=1
                MEMORY=1
                DISK=[IMAGE_ID=#{@image}]
                CONTEXT=[
                    FILES="#{path}",
                    TARGET=hdb ]
            EOT
            vm = VM.new(vm_id)

            cli_action("onevm deploy #{vm_id} host01")
            vm.running?

            xml = vm.info
            expect(xml['TEMPLATE/CONTEXT/FILES']).to eq path
        end
    end

    it "should allocate a VM with CONTEXT/FILES outside RESTRICTED_DIRS" do
        Tempfile.create('context_file', '/tmp') do |f|
            path = "/var/../tmp/#{File.basename(f.path)}"
            vm_id = cli_create("onevm create", <<-EOT)
                CPU=1
                MEMORY=1
                DISK=[IMAGE_ID=#{@image}]
                CONTEXT=[
                    FILES="#{path}",
                    TARGET=hdb ]
            EOT
            vm = VM.new(vm_id)

            cli_action("onevm deploy #{vm_id} host01")
            vm.running?

            xml = vm.info
            expect(xml['TEMPLATE/CONTEXT/FILES']).to eq path
        end
    end

    it "should fail to allocate a VM with CONTEXT/FILES in RESTRICTED_DIRS" do
        Tempfile.create('context_file', '/var/lib/one') do |f|
            path = "/tmp/../var/lib/one/#{File.basename(f.path)}"
            vm_id = cli_create("onevm create", <<-EOT)
                CPU=1
                MEMORY=1
                DISK=[IMAGE_ID=#{@image}]
                CONTEXT=[
                    FILES="#{path}",
                    TARGET=hdb ]
            EOT
            vm = VM.new(vm_id)

            cli_action("onevm deploy #{vm_id} host01")
            vm.state?('BOOT_FAILURE', 'RUNNING')

            xml = vm.info
            expect(xml['TEMPLATE/CONTEXT/FILES']).to eq path
            expect(xml['USER_TEMPLATE/ERROR']).not_to be_nil
        end
    end

    it "RESTRICTED_DIRS for CONTEXT/FILES should follow symlinks" do
        Tempfile.create('context_file', '/var/lib/one') do |f|
            basename = File.basename(f.path)
            File.symlink(f.path, "/tmp/#{basename}")
            path = "/tmp/#{basename}"
            vm_id = cli_create("onevm create", <<-EOT)
                CPU=1
                MEMORY=1
                DISK=[IMAGE_ID=#{@image}]
                CONTEXT=[
                    FILES="#{path}",
                    TARGET=hdb ]
            EOT
            vm = VM.new(vm_id)

            cli_action("onevm deploy #{vm_id} host01")
            vm.state?('BOOT_FAILURE', 'RUNNING')

            xml = vm.info
            expect(xml['TEMPLATE/CONTEXT/FILES']).to eq path
            expect(xml['USER_TEMPLATE/ERROR']).not_to be_nil
        end
    end

end
