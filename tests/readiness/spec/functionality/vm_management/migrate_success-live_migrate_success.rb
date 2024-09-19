
require 'init_functionality'

require 'base64'
require 'zlib'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
DUMMY_ACTIONS_DIR = "/tmp/opennebula_dummy_actions"

def hist(xml, var, previous = false)
    prev = (previous ? '-1' : '')
    str = "HISTORY_RECORDS/HISTORY[last()#{prev}]"
    val = xml["#{str}/#{var}"]

    if val.match(/^\d+$/)
        val.to_i
    else
        val
    end
end

def used_vnc_ports(id)
    query  = "select map from cluster_vnc_bitmap where id=#{id}"
    zmap64 = ""

    wait_loop {
      zmap64 = `sqlite3 "#{ONE_VAR_LOCATION}/one.db" "#{query}"`
      $?.success?
    }
    map    = Zlib::Inflate.inflate(Base64.decode64(zmap64.chomp))

    ports  = []

    map.length.times{ |i| ports << 65535 - i if map[i] == '1' }

    ports
end

describe "VirtualMachine migrate/live_migrate operation test" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do
        @ds0 = cli_create("onedatastore create", "NAME = ds0\nTYPE=SYSTEM_DS\nTM_MAD=dummy")

        cli_update("onedatastore update system", "TM_MAD=dummy", false)
        cli_update("onedatastore update default", "TM_MAD=dummy\nDS_MAD=dummy", false)

        wait_loop() {
            xml = cli_action_xml("onedatastore show -x default")
            xml['FREE_MB'].to_i > 0
        }

        @host_blue = cli_create("onehost create blue --im dummy --vm dummy")
        cli_action("onehost show #{@host_blue}")

        @host_red = cli_create("onehost create red --im dummy --vm dummy")
        cli_action("onehost show #{@host_red}")

        @vm_id = cli_create("onevm create", <<-EOT)
            NAME = "test"
            MEMORY = "1"
            CPU    = "1"
            GRAPHICS = [TYPE = "vnc", LISTEN  = "0.0.0.0", PORT = "1234"]
        EOT
        @vm = VM.new(@vm_id)

        cli_action("onevm deploy #{@vm_id} blue")
        @vm.running?

        # Separate cluster for VNC migration
        @cluster = cli_create("onecluster create cluster")
        cli_action("onecluster adddatastore #{@cluster} 0")
        cli_action("onecluster adddatastore #{@cluster} 1")
        cli_action("onecluster adddatastore #{@cluster} 2")
        cli_action("onecluster adddatastore #{@cluster} #{@ds0}")

        @host_yellow = cli_create("onehost create yellow --im dummy --vm dummy --cluster #{@cluster}")
        cli_action("onehost show #{@host_yellow}")

        `echo "success" > #{DUMMY_ACTIONS_DIR}/save`
    end

    after(:all) do
        `echo "success" > #{DUMMY_ACTIONS_DIR}/save`
        `echo "success" > #{DUMMY_ACTIONS_DIR}/cancel`
        `echo "success" > #{DUMMY_ACTIONS_DIR}/shutdown`
        `echo "success" > #{DUMMY_ACTIONS_DIR}/migrate`
    end

    it "should migrate a running VirtualMachine and then, check its state" <<
        " and history" do

        cli_action("onevm migrate #{@vm_id} red")

        @vm.running?

        xml = @vm.info

        expect(hist(xml, "ACTION")).to eq 0 # NONE

        expect(hist(xml, "ACTION", true)).to eq 1 # MIGRATE

        expect(xml['HISTORY_RECORDS/HISTORY[last()]/STIME'].to_i).to be > 0
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/ETIME'].to_i).to eql(0)
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/PSTIME'].to_i).to be > 0
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/PETIME'].to_i).to be >=
            xml['HISTORY_RECORDS/HISTORY[last()]/PSTIME'].to_i
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/RSTIME'].to_i).to be > 0
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/RETIME'].to_i).to eql(0)
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/ESTIME'].to_i).to eql(0)
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/EETIME'].to_i).to eql(0)

        expect(hist(xml, "SEQ")).to eq 1
        expect(hist(xml, "HOSTNAME")).to eq "red"
        expect(hist(xml, "HID")).to eq @host_red
    end

    it "should migrate with poff option a running VirtualMachine and then, check its state" <<
        " and history" do

        cli_action("onevm migrate #{@vm_id} blue --poff")

        @vm.running?

        xml = @vm.info

        expect(hist(xml, "ACTION")).to eq 0 # NONE

        expect(hist(xml, "ACTION", true)).to eq 48 # POFF_MIGRATE

        expect(xml['HISTORY_RECORDS/HISTORY[last()]/STIME'].to_i).to be > 0
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/ETIME'].to_i).to eql(0)
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/PSTIME'].to_i).to be > 0
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/PETIME'].to_i).to be >=
            xml['HISTORY_RECORDS/HISTORY[last()]/PSTIME'].to_i
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/RSTIME'].to_i).to be > 0
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/RETIME'].to_i).to eql(0)
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/ESTIME'].to_i).to eql(0)
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/EETIME'].to_i).to eql(0)

        expect(hist(xml, "SEQ")).to eq 2
        expect(hist(xml, "HOSTNAME")).to eq "blue"
        expect(hist(xml, "HID")).to eq @host_blue
    end

    it "should migrate with poff-hard option a running VirtualMachine and then, check its state" <<
        " and history" do

        cli_action("onevm migrate #{@vm_id} red --poff-hard")

        @vm.running?

        xml = @vm.info

        expect(hist(xml, "ACTION")).to eq 0 # NONE

        expect(hist(xml, "ACTION", true)).to eq 49 # HARD_POFF_MIGRATE

        expect(xml['HISTORY_RECORDS/HISTORY[last()]/STIME'].to_i).to  be > 0
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/ETIME'].to_i).to  eql(0)
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/PSTIME'].to_i).to be > 0
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/PETIME'].to_i).to be >=
            xml['HISTORY_RECORDS/HISTORY[last()]/PSTIME'].to_i
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/RSTIME'].to_i).to be > 0
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/RETIME'].to_i).to eql(0)
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/ESTIME'].to_i).to eql(0)
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/EETIME'].to_i).to eql(0)

        expect(hist(xml, "SEQ")).to eq 3
        expect(hist(xml, "HOSTNAME")).to eq "red"
        expect(hist(xml, "HID")).to eq @host_red
    end

    it "should migrate with poff option a running VirtualMachine and then, check its state" <<
        " and history with shutdown failure" do
        `echo "failure" > #{DUMMY_ACTIONS_DIR}/shutdown`

        cli_action("onevm migrate #{@vm_id} blue --poff")

        @vm.running?

        xml = @vm.info

        expect(hist(xml, "ACTION")).to eq 0 # NONE

        expect(hist(xml, "ACTION", true)).to eq 48 # POFF_MIGRATE

        expect(xml['HISTORY_RECORDS/HISTORY[last()]/STIME'].to_i).to  be > 0
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/ETIME'].to_i).to  eql(0)
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/PSTIME'].to_i).to eql(0)
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/PETIME'].to_i).to be >=
            xml['HISTORY_RECORDS/HISTORY[last()]/PSTIME'].to_i
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/RSTIME'].to_i).to be > 0
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/RETIME'].to_i).to eql(0)
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/ESTIME'].to_i).to eql(0)
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/EETIME'].to_i).to eql(0)

        expect(hist(xml, "SEQ")).to eq 5
        expect(hist(xml, "HOSTNAME")).to eq "red"
        expect(hist(xml, "HID")).to eq @host_red

        `echo "success" > #{DUMMY_ACTIONS_DIR}/shutdown`
    end

    it "should migrate with poff option a running VirtualMachine and then, check its state" <<
        " and history with shutdown failure" do
        `echo "failure" > #{DUMMY_ACTIONS_DIR}/cancel`

        cli_action("onevm migrate #{@vm_id} blue --poff-hard")

        @vm.running?

        xml = @vm.info

        expect(hist(xml, "ACTION")).to eq 0 # NONE

        expect(hist(xml, "ACTION", true)).to eq 49 # POFF_MIGRATE_HARD

        expect(xml['HISTORY_RECORDS/HISTORY[last()]/STIME'].to_i).to  be > 0
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/ETIME'].to_i).to  eql(0)
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/PSTIME'].to_i).to eql(0)
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/PETIME'].to_i).to be >=
            xml['HISTORY_RECORDS/HISTORY[last()]/PSTIME'].to_i
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/RSTIME'].to_i).to be > 0
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/RETIME'].to_i).to eql(0)
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/ESTIME'].to_i).to eql(0)
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/EETIME'].to_i).to eql(0)

        expect(hist(xml, "SEQ")).to eq 7
        expect(hist(xml, "HOSTNAME")).to eq "red"
        expect(hist(xml, "HID")).to eq @host_red

        `echo "success" > #{DUMMY_ACTIONS_DIR}/cancel`
    end

    it "should live_migrate a running VirtualMachine and then, check its" <<
        " state and history" do

        cli_action("onevm migrate --live #{@vm_id} blue")

        @vm.running?

        xml = @vm.info

        expect(hist(xml, "ACTION", true)).to eq 2 # LIVE-MIGRATE

        expect(xml['HISTORY_RECORDS/HISTORY[last()]/STIME'].to_i).to be > 0
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/ETIME'].to_i).to eql 0
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/PSTIME'].to_i).to eql 0
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/PETIME'].to_i).to eql 0
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/RSTIME'].to_i).to be > 0
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/RETIME'].to_i).to eql(0)
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/ESTIME'].to_i).to eql(0)
        expect(xml['HISTORY_RECORDS/HISTORY[last()]/EETIME'].to_i).to eql(0)

        expect(hist(xml, "SEQ")).to eq 8
        expect(hist(xml, "HOSTNAME")).to eq "blue"
        expect(hist(xml, "HID")).to eq @host_blue
    end

    it "should enforce capacity check before migration" do
        id = cli_create("onevm create --name testvm2 --cpu 100 --memory 1")
        vm = VM.new(id)

        cli_action("onevm deploy testvm2 blue")

        vm.running?

        cli_action("onevm migrate -e testvm2 red", false)
    end

    it "should migrate to the same host but different datastore" do
        id = cli_create("onevm create --name testvm_same_host --cpu 100 --memory 1")
        vm = VM.new(id)

        cli_action("onevm deploy testvm_same_host blue system")

        vm.running?

        hostxml = cli_action_xml("onehost show -x blue")

        num_vms = hostxml['HOST_SHARE/RUNNING_VMS'].to_i
        host_cpu = hostxml["HOST_SHARE/CPU_USAGE"].to_i
        host_mem = hostxml["HOST_SHARE/MEM_USAGE"].to_i

        cli_action("onevm migrate testvm_same_host blue #{@ds0}")

        vm.running?

        hostxml_2 = cli_action_xml("onehost show -x blue")

        xml = vm.info
        dsid = hist(xml, "DS_ID")
        expect(dsid.to_i).to eql(@ds0.to_i)

        expect(hostxml_2['HOST_SHARE/RUNNING_VMS'].to_i).to eql(num_vms)
        expect(hostxml_2['HOST_SHARE/CPU_USAGE'].to_i).to eql(host_cpu)
        expect(hostxml_2['HOST_SHARE/MEM_USAGE'].to_i).to eql(host_mem)
    end

    it "should migrate poweroff vm to the same host but different datastore" do
        id = cli_create("onevm create --name testvm_same_host_poweroff --cpu 100 --memory 1")
        vm = VM.new(id)

        cli_action("onevm deploy testvm_same_host_poweroff blue system")

        vm.running?
        vm.safe_poweroff
        vm.state?("POWEROFF")

        hostxml = cli_action_xml("onehost show -x blue")

        num_vms = hostxml['HOST_SHARE/RUNNING_VMS'].to_i
        host_cpu = hostxml["HOST_SHARE/CPU_USAGE"].to_i
        host_mem = hostxml["HOST_SHARE/MEM_USAGE"].to_i

        cli_action("onevm migrate testvm_same_host_poweroff blue #{@ds0}")

        vm.state?("POWEROFF")

        xml = vm.info
        dsid = hist(xml, "DS_ID")
        expect(dsid.to_i).to eql(@ds0.to_i)

        hostxml_2 = cli_action_xml("onehost show -x blue")

        expect(hostxml_2['HOST_SHARE/RUNNING_VMS'].to_i).to eql(num_vms)
        expect(hostxml_2['HOST_SHARE/CPU_USAGE'].to_i).to eql(host_cpu)
        expect(hostxml_2['HOST_SHARE/MEM_USAGE'].to_i).to eql(host_mem)
    end

    it "should migrate running vm to the same host but different datastore with failure" do
        `echo "failure" > #{DUMMY_ACTIONS_DIR}/save`

        id = cli_create("onevm create --name testvm_same_host_fail --cpu 100 --memory 1")
        vm = VM.new(id)

        cli_action("onevm deploy testvm_same_host_fail blue system")

        vm.running?

        hostxml = cli_action_xml("onehost show -x blue")

        num_vms = hostxml['HOST_SHARE/RUNNING_VMS'].to_i
        host_cpu = hostxml["HOST_SHARE/CPU_USAGE"].to_i
        host_mem = hostxml["HOST_SHARE/MEM_USAGE"].to_i

        cli_action("onevm migrate testvm_same_host_fail blue #{@ds0}")

        vm.running?

        hostxml_2 = cli_action_xml("onehost show -x blue")

        expect(hostxml_2['HOST_SHARE/RUNNING_VMS'].to_i).to eql(num_vms)
        expect(hostxml_2['HOST_SHARE/CPU_USAGE'].to_i).to eql(host_cpu)
        expect(hostxml_2['HOST_SHARE/MEM_USAGE'].to_i).to eql(host_mem)
    end

    it "should live migrate vm to another cluster and clean vnc ports" do
        skip("Do not test on non-sqlite backends") unless @one_test.is_sqlite?

        default_ports = used_vnc_ports(0)
        cluster_ports = used_vnc_ports(@cluster)

        expect(default_ports).to contain_exactly(1234)
        expect(cluster_ports).to match_array []

        cli_action("onevm migrate --live #{@vm_id} yellow")

        @vm.running?

        default_ports = used_vnc_ports(0)
        cluster_ports = used_vnc_ports(@cluster)

        expect(default_ports).to match_array []
        expect(cluster_ports).to contain_exactly(1234)

        cli_action("onevm migrate --live #{@vm_id} blue")

        @vm.running?

        default_ports = used_vnc_ports(0)
        cluster_ports = used_vnc_ports(@cluster)

        expect(default_ports).to contain_exactly(1234)
        expect(cluster_ports).to match_array []

        `echo "failure" > #{DUMMY_ACTIONS_DIR}/migrate`

        cli_action("onevm migrate --live #{@vm_id} yellow")

        @vm.running?

        default_ports = used_vnc_ports(0)
        cluster_ports = used_vnc_ports(@cluster)

        expect(default_ports).to contain_exactly(1234)
        expect(cluster_ports).to match_array []
    end

    it "should migrate vm to another cluster and clean vnc ports" do
        skip("Do not test on non-sqlite backends") unless @one_test.is_sqlite?

        #NOTE: oned uses the same logic to track resource usage for all migration
        #types, only one is needed to be tested (save, poweroff, poweroff hard)
        `echo "success" > #{DUMMY_ACTIONS_DIR}/save`

        cli_action("onevm migrate #{@vm_id} yellow")

        @vm.running?

        default_ports = used_vnc_ports(0)
        cluster_ports = used_vnc_ports(@cluster)

        expect(default_ports).to match_array []
        expect(cluster_ports).to contain_exactly(5900) #new port selected

        cli_action("onevm migrate #{@vm_id} blue")

        @vm.running?

        default_ports = used_vnc_ports(0)
        cluster_ports = used_vnc_ports(@cluster)

        expect(default_ports).to contain_exactly(5900)
        expect(cluster_ports).to match_array []

        `echo "failure" > #{DUMMY_ACTIONS_DIR}/save`

        cli_action("onevm migrate #{@vm_id} yellow")

        @vm.running?

        default_ports = used_vnc_ports(0)
        cluster_ports = used_vnc_ports(@cluster)

        expect(default_ports).to contain_exactly(5900)
        expect(cluster_ports).to match_array []
    end

    it "should migrate from poff to another cluster and clean vnc ports" do
        skip("Do not test on non-sqlite backends") unless @one_test.is_sqlite?

        #NOTE: oned frees resources, no matter if boot fails or succeeds

        cli_action("onevm poweroff #{@vm_id}")

        @vm.state?('POWEROFF')

        cli_action("onevm migrate #{@vm_id} yellow")

        @vm.state?('POWEROFF')

        default_ports = used_vnc_ports(0)
        cluster_ports = used_vnc_ports(@cluster)

        expect(default_ports).to match_array []
        expect(cluster_ports).to contain_exactly(5900) #new port selected

        cli_action("onevm migrate #{@vm_id} blue")

        @vm.state?('POWEROFF')

        default_ports = used_vnc_ports(0)
        cluster_ports = used_vnc_ports(@cluster)

        expect(default_ports).to contain_exactly(5900)
        expect(cluster_ports).to match_array []
    end
end
