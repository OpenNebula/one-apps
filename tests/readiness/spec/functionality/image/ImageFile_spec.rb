#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------
#ENV['DEFAULTS']=File.join(File.dirname(__FILE__),'defaults.yaml')

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "File images operations test" do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        mads = "TM_MAD=dummy\nDS_MAD=dummy"

        cli_update("onedatastore update system", mads, false)
        cli_update("onedatastore update default", mads, false)
        cli_update("onedatastore update files", mads, false)

        wait_loop do
            xml = cli_action_xml("onedatastore show -x default")
            xml['FREE_MB'].to_i > 0
        end

        @fds_id = 2
        @ids_id = 1
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "should create Images, of different types" do
        img_id1 = cli_create("oneimage create -d #{@fds_id} --path /etc/passwd"\
                             " --type kernel --name a_kernel")
        img_id2 = cli_create("oneimage create -d #{@ids_id} --path /etc/passwd"\
                             " --type os --name a_os")
        img_id3 = cli_create("oneimage create -d #{@ids_id} --path /etc/passwd"\
                             " --type datablock --name a_datablock --size 1M"\
                             " --name db")
        img_id4 = cli_create("oneimage create -d #{@fds_id} --path /etc/passwd"\
                             " --type ramdisk --name a_ramdisk")
        img_id5 = cli_create("oneimage create -d #{@fds_id} --path /etc/passwd"\
                             " --type context --name a_context")

        expect(img_id1).to eq(0)
        expect(img_id2).to eq(1)
        expect(img_id3).to eq(2)
        expect(img_id4).to eq(3)
        expect(img_id5).to eq(4)
    end

    it "should only allow you to create images on suitable datastores" do
        cli_create("oneimage create -d #{@fds_id} --path /etc/passwd"\
                   " --type os --name a_os2", nil, false)
        cli_create("oneimage create -d #{@fds_id} --path /etc/passwd"\
                   " --type cdrom --name a_cd2", nil, false)
        cli_create("oneimage create -d #{@fds_id} --path /etc/passwd"\
                   " --type datablock --name a_data2", nil, false)
        cli_create("oneimage create -d #{@ids_id} --path /etc/passwd"\
                   " --type kernel --name a_file2", nil, false)
        cli_create("oneimage create -d #{@ids_id} --path /etc/passwd"\
                   " --type ramdisk --name a_file4", nil, false)
        cli_create("oneimage create -d #{@ids_id} --path /etc/passwd"\
                   " --type context --name a_file3", nil, false)
    end

    it "should not allow you to use file images as DISKs" do
        cli_create("onevm create --cpu 1 --memory 128 --disk 0", nil, false)
        cli_create("onevm create --cpu 1 --memory 128 --disk 4", nil, false)
        cli_create("onevm create --cpu 1 --memory 128 --disk 3", nil, false)
    end

    it "should not allow you to use regular images as files in VM templates" do
        tt = <<-EOF
            NAME = test1
            CPU  = 1
            MEMORY = 128
            OS     = [ KERNEL_DS = "$FILE[IMAGE_ID=1]" ]
        EOF

        cli_create('onevm create', tt, false)

        tt = <<-EOF
            NAME = test1
            CPU  = 1
            MEMORY = 128
            OS     = [ KERNEL_DS = "$FILE[IMAGE_ID=4]" ]
        EOF

        cli_create('onevm create', tt, false)

        tt = <<-EOF
            NAME = test1
            CPU  = 1
            MEMORY = 128
            OS     = [ KERNEL_DS = "$FILE[IMAGE_ID=3]" ]
        EOF

        cli_create('onevm create', tt, false)
    end


    it "should not allow you to clone file images" do
        cli_create("oneimage clone 0 a_file3", nil, false)
    end

    it "should generate VM templates using Image files" do
        tt = <<-EOF
            NAME = test1
            CPU  = 1
            MEMORY = 128

        EOF

        tt1 = tt + "OS=[ KERNEL_DS=\"$NOT_A_VAR\" ]"

        tt2 = tt + "OS=[ KERNEL_DS=\"$FILE[BAD=SYNTAX IN DILE]\" ]"

        tt3 = tt + "OS=[ KERNEL_DS=\"$FILE[IMAGE_ID=0]\" ]"

        tt4 = tt + "OS=[ KERNEL_DS=\"$FILE[IMAGE=\\\"a_kernel\\\"]\" ]"

        tt5 = tt + "OS=[ KERNEL_DS=\"$FILE[IMAGE=\\\"a_kernel\\\", IMAGE_UID=0]\" ]"

        tt6 = tt + "OS=[ KERNEL_DS=\"$FILE[IMAGE=\\\"a_kernel\\\", IMAGE_UID=10]\"]"

        tt8 = tt + "OS=[ INITRD_DS=\"$FILE[IMAGE=\\\"a_ramdisk\\\"]\"]"

        tt7 = tt + "CONTEXT=[ FILES_DS=\"$FILE[IMAGE=\\\"a_context\\\"]"\
                                           " $FILE[IMAGE_ID=4]\"]"

        cli_create('onevm create', tt1, false)

        cli_create('onevm create', tt2, false)

        cli_create('onevm create', tt6, false)

        vm1 = cli_create('onevm create', tt3)

        vm_xml = cli_action_xml("onevm show #{vm1} -x")

        expect(vm_xml["TEMPLATE/OS/KERNEL_DS_SOURCE"]).to eq("dummy_path")
        expect(vm_xml["TEMPLATE/OS/KERNEL_DS_DSID"]).to eq("2")
        expect(vm_xml["TEMPLATE/OS/KERNEL_DS_ID"]).to eq("0")

        vm2 = cli_create('onevm create', tt4)

        vm_xml = cli_action_xml("onevm show #{vm2} -x")

        expect(vm_xml["TEMPLATE/OS/KERNEL_DS_SOURCE"]).to eq("dummy_path")
        expect(vm_xml["TEMPLATE/OS/KERNEL_DS_DSID"]).to eq("2")
        expect(vm_xml["TEMPLATE/OS/KERNEL_DS_ID"]).to eq("0")

        vm3 = cli_create('onevm create', tt5)

        vm_xml = cli_action_xml("onevm show #{vm3} -x")

        expect(vm_xml["TEMPLATE/OS/KERNEL_DS_SOURCE"]).to eq("dummy_path")
        expect(vm_xml["TEMPLATE/OS/KERNEL_DS_DSID"]).to eq("2")
        expect(vm_xml["TEMPLATE/OS/KERNEL_DS_ID"]).to eq("0")

        vm4 = cli_create('onevm create', tt7)

        vm_xml = cli_action_xml("onevm show #{vm4} -x")

        img_files = "dummy_path:'a_context' dummy_path:'a_context' "

        expect(vm_xml["TEMPLATE/CONTEXT/FILES_DS"]).to eq(img_files)

        vm5 = cli_create('onevm create', tt8)

        vm_xml = cli_action_xml("onevm show #{vm5} -x")

        expect(vm_xml["TEMPLATE/OS/INITRD_DS_SOURCE"]).to eq("dummy_path")
        expect(vm_xml["TEMPLATE/OS/INITRD_DS_DSID"]).to eq("2")
        expect(vm_xml["TEMPLATE/OS/INITRD_DS_ID"]).to eq("3")
    end
end

