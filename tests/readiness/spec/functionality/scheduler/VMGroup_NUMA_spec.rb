
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Scheduling requirements tests" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults_affinity.yaml')
    end

    def build_template(cpu, group, role)
        template = <<-EOF
            NAME = testvm
            VCPU  = #{cpu}
            MEMORY = 1
            TOPOLOGY = [ PIN_POLICY = "thread" ]
            VMGROUP = [ VMGROUP_NAME="#{group}" , ROLE="#{role}" ]
        EOF
    end

    def vm_with_group(cpu, group, role)
        vmid = cli_create("onevm create --hold", build_template(cpu, group, role))
        vm   = VM.new(vmid)

        return vmid, vm
    end

    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        ids = []
        5.times { |i|
            ids << cli_create("onehost create host#{i} --im dummy --vm dummy")
        }

        ids.each { |i|
            cli_update("onehost update #{i}", "PIN_POLICY = PINNED", true)
            host = Host.new(i)
            host.monitored?
        }

        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update("onedatastore update system", mads, false)
        cli_update("onedatastore update default", mads, false)
    end

    after(:all) do
        5.times { |i|
            cli_action("onehost delete host#{i}")
        }
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should allocate VMs considering VM-VM intra-role affinity rules" do
        template = <<-EOF
            NAME = vm-vm
            ROLE = [ NAME="aff", POLICY="AFFINED" ]
            ROLE = [ NAME="anti", POLICY="ANTI_AFFINED" ]
        EOF

        cli_create("onevmgroup create", template)

        ids = []
        vms = []

        4.times { |i|
            vmid, vm = vm_with_group("2", "vm-vm", "aff")

            ids[i] = vmid
            vms[i] = vm
        }

        @one_test.stop_sched()
        ids.each { |i|
            cli_action("onevm release #{i}")
        }

        @one_test.start_sched()

        vms[0].running?

        the_host = vms[0].hostname

        vms.each { |v|
            v.running?

            expect(v.hostname).to eq(the_host)

            v.terminate_hard
        }

        ids = []
        vms = []

        4.times { |i|
            vmid, vm = vm_with_group("2", "vm-vm", "anti")

            ids[i] = vmid
            vms[i] = vm
        }

        @one_test.stop_sched()
        ids.each { |i|
            cli_action("onevm release #{i}")
        }
        @one_test.start_sched()

        vms.each { |v|
            v.running?
        }

        hostnames = {}

        vms.each { |v|
            expect(hostnames[v.hostname]).to be_nil

            hostnames[v.hostname] = 1

            v.terminate_hard
        }
    end

    it "should allocate VMs considering VM-VM inter-role affinity rules" do
        template = <<-EOF
            NAME = vm-vm-inter
            ROLE = [ NAME="a1" ]
            ROLE = [ NAME="a2" ]
            ROLE = [ NAME="a3" ]
            ROLE = [ NAME="a4" ]
            ROLE = [ NAME="a5" ]

            AFFINED = "a1, a4"
            AFFINED = "a2, a3"
            AFFINED = "a4, a5"
        EOF

        cli_create("onevmgroup create", template)

        ids = []
        vms = []

        5.times { |i|
            vmid, vm = vm_with_group("2", "vm-vm-inter", "a#{i+1}")

            ids[i] = vmid
            vms[i] = vm
        }

        @one_test.stop_sched()
        ids.each { |i|
            cli_action("onevm release #{i}")
        }
        @one_test.start_sched()

        vms.each { |v|
            v.running?
        }

        expect(vms[0].hostname).to eq(vms[3].hostname)
        expect(vms[0].hostname).to eq(vms[4].hostname)
        expect(vms[0].hostname).not_to eq(vms[1].hostname)
        expect(vms[0].hostname).not_to eq(vms[2].hostname)


        expect(vms[1].hostname).to eq(vms[2].hostname)

        vms.each { |v|
            v.terminate_hard
        }
    end

    it "should allocate VMs considering VM-VM inter-role anti-affinity rules" do
        template = <<-EOF
            NAME = a-vm-vm-inter
            ROLE = [ NAME="a1" ]
            ROLE = [ NAME="a2" ]
            ROLE = [ NAME="a3" ]
            ROLE = [ NAME="a4" ]
            ROLE = [ NAME="a5" ]

            ANTI_AFFINED = "a1, a4, a5"
            ANTI_AFFINED = "a2, a3"
            ANTI_AFFINED = "a4, a5"
        EOF

        cli_create("onevmgroup create", template)

        ids = []
        vms = []

        5.times { |i|
            vmid, vm = vm_with_group("2", "a-vm-vm-inter", "a#{i+1}")

            ids[i] = vmid
            vms[i] = vm
        }

        @one_test.stop_sched()
        ids.each { |i|
            cli_action("onevm release #{i}")
        }
        @one_test.start_sched()

        vms.each { |v|
            v.running?
        }

        expect(vms[0].hostname).not_to eq(vms[3].hostname)
        expect(vms[0].hostname).not_to eq(vms[4].hostname)
        expect(vms[3].hostname).not_to eq(vms[4].hostname)

        expect(vms[1].hostname).not_to eq(vms[2].hostname)

        vms.each { |v|
            v.terminate_hard
        }
    end
end

