require 'init'
require 'lib/DiskResize'
require 'pry'

include DiskResize

def check_disk_filesystem(img_tmpl, filesystem, volatile)
    if volatile
        disk = Tempfile.new('volatile_disk')
        disk.write(img_tmpl)
        disk.close
        cli_action("onevm disk-attach #{@info[:vm_id]} "\
                   "--file #{disk.path}")
        disk.unlink
    else
        # Create the image
        img_id = cli_create('oneimage create -d 1', img_tmpl)
        wait_image_ready(10, img_id)
        # Attach the image to a VM to check the format
        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{img_id}")
    end

    @info[:vm].running?
    @info[:vm].reachable?
    @info[:vm].info

    # Check the format
    target = @info[:vm].xml["TEMPLATE/DISK[DISK_ID='#{@info[:disk_id]}']/TARGET"]
    cmd = @info[:vm].ssh("lsblk -f | grep '^#{target}'")

    # clean
    cli_action("onevm disk-detach #{@info[:vm_id]} #{@info[:disk_id]}")
    @info[:vm].running?
    @info[:vm].reachable?

    if filesystem.nil?
        expect(cmd.stdout.strip).to eq(target.strip)
    else
        expect(cmd.stdout.strip).to match(/#{filesystem}/)
    end
end

# Test the disk format and filesystem

RSpec.describe 'Disk format' do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        # Image info
        @info[:img_name] = 'format-test'
        @info[:disk_id] = 2

        # VM info
        @info[:vm_id] = cli_create("onetemplate instantiate --hold '#{@defaults[:template]}'")
        @info[:vm]    = VM.new(@info[:vm_id])

        # Datastore info
        @info[:tm_mad] = cli_action_xml("onedatastore show -x 0")['TM_MAD']
    end

    after(:each) do |test|
        if test.metadata[:clean]
            cli_action("oneimage delete #{@info[:img_name]}")
            wait_loop(:success => true) {
                cmd = cli_action("oneimage show #{@info[:img_name]} 2>/dev/null", nil)
                cmd.fail?
            }
        end

        if test.metadata[:clean_ds]
            [0, 1].each do |ds_id|
                xml_datastore = cli_action_xml("onedatastore show #{ds_id} -x", true)
                tmpl_elems = xml_datastore.retrieve_xmlelements("//TEMPLATE")[0].to_hash["TEMPLATE"]
                new_tmpl  = ""
                separator = ""
                tmpl_elems.each do |key, val|
                    new_tmpl << "#{key}=\"#{val}\"\n" if key != "DRIVER"
                    separator = ","
                end

                cli_update("onedatastore update #{ds_id}", new_tmpl, false)
            end
        end
    end

    after(:all) do
        @info[:vm].terminate_hard
    end

    it "deploys" do
        cli_action("onevm release #{@info[:vm_id]}")
        @info[:vm].running?
    end

    it "ssh and context" do
        @info[:vm].reachable?
    end


    ###########################################################################
    # Check filesystem for images
    ###########################################################################

    it 'creates a raw image with ext4 filesystem', :clean do
        img_tmpl = <<-EOF
            NAME   = #{@info[:img_name]}
            TYPE   = DATABLOCK
            SIZE   = 200
            FORMAT = raw
            FS     = ext4
        EOF

        check_disk_filesystem(img_tmpl, "ext4", false)
    end

    it 'creates a raw image without format', :clean do
        img_tmpl = <<-EOF
            NAME   = #{@info[:img_name]}
            TYPE   = DATABLOCK
            SIZE   = 200
            FORMAT = raw
        EOF

        check_disk_filesystem(img_tmpl, nil, false)
    end

    it 'creates a qcow2 image with ext4 filesystem', :clean do
        img_tmpl = <<-EOF
            NAME   = #{@info[:img_name]}
            TYPE   = DATABLOCK
            SIZE   = 200
            FORMAT = qcow2
            FS     = ext4
        EOF

        check_disk_filesystem(img_tmpl, "ext4", false)
    end

    it 'creates a qcow2 image without format', :clean do
        img_tmpl = <<-EOF
            NAME   = #{@info[:img_name]}
            TYPE   = DATABLOCK
            SIZE   = 200
            FORMAT = qcow2
        EOF

        check_disk_filesystem(img_tmpl, nil, false)
    end

    it 'check failure when creating image with invalid FS', :clean do
        img_tmpl = <<-EOF
            NAME   = #{@info[:img_name]}
            TYPE   = DATABLOCK
            SIZE   = 200
            FORMAT = qcow2
            FS     = unsupported
        EOF

        img_id = cli_create('oneimage create -d 1', img_tmpl)
        wait_loop(:success => "ERROR", :break => "READY", :timeout => 10) {
            xml = cli_action_xml("oneimage show -x #{img_id}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        }
    end

    ###########################################################################
    # Check filesystem for olatile disks
    ###########################################################################

    it 'creates a raw volatile disk with ext4 filesystem' do
        disk_tmpl = <<-EOF
            DISK = [
                TYPE   = fs,
                SIZE   = 200,
                FORMAT = raw,
                FS     = ext4
            ]
        EOF

        check_disk_filesystem(disk_tmpl, "ext4", true)
    end

    it 'creates a raw volatile disk without format' do
        disk_tmpl = <<-EOF
            DISK = [
                TYPE   = fs,
                SIZE   = 200,
                FORMAT = raw
            ]
        EOF

        check_disk_filesystem(disk_tmpl, nil, true)
    end

    it 'creates a qcow2 volatile disk with ext4 filesystem' do
        disk_tmpl = <<-EOF
            DISK = [
                TYPE   = fs,
                SIZE   = 200,
                FORMAT = qcow2,
                FS     = ext4
            ]
        EOF

        check_disk_filesystem(disk_tmpl, "ext4", true)
    end

    it 'creates a qcow2 volatile disk without format' do
        disk_tmpl = <<-EOF
            DISK = [
                TYPE   = fs,
                SIZE   = 200,
                FORMAT = qcow2
            ]
        EOF

        check_disk_filesystem(disk_tmpl, nil, true)
    end

    it 'check failure when attaching volatile disk with invalid FS' do
        img_tmpl = <<-EOF
            DISK = [
                TYPE   = FS,
                SIZE   = 200,
                FORMAT = raw,
                FS     = ext344]
        EOF

        disk = Tempfile.new('volatile_disk')
        disk.write(img_tmpl)
        disk.close
        cli_action("onevm disk-attach #{@info[:vm_id]} "\
                   "--file #{disk.path}")
        disk.unlink

        @info[:vm].running?
        @info[:vm].reachable?
        @info[:vm].info

        # Check disk number
        n_disk = @info[:vm].xml.retrieve_xmlelements("//DISK").size
        expect(n_disk.to_i).to eq(1)

    end

    ###########################################################################
    # Check FORMAT and DRIVER
    ###########################################################################

    it 'checks that format is forced when DRIVER is defined for DS (image)', :clean_ds do
        skip "Not applicable for #{@info[:tm_mad]}" if ['ceph', 'fs_lvm', 'fs_lvm_ssh'].include? @info[:tm_mad]

        img_tmpl = <<-EOF
            NAME   = #{@info[:img_name]}
            TYPE   = DATABLOCK
            SIZE   = 200
            FORMAT = raw
        EOF

        ds_mad_update = "DRIVER=qcow2\n"
        cli_update('onedatastore update 1', ds_mad_update, true)
        xml_datastore = cli_action_xml('onedatastore show 1 -x', true)
        expect(xml_datastore['TEMPLATE/DRIVER']).to eq('qcow2')

        # Create the image
        img_id = cli_create('oneimage create -d 1', img_tmpl)
        wait_image_ready(10, img_id)

        # Check the FORMAT and DRIVER attributes
        img_xml = cli_action_xml("oneimage show -x #{img_id}")
        expect(img_xml["//FORMAT"]).to eq("qcow2")
        expect(img_xml["//DRIVER"]).to eq("qcow2")
    end

    it 'checks that format is forced when DRIVER is defined for DS when cloning', :clean, :clean_ds do
        skip "Not applicable for #{@info[:tm_mad]}" if ['ceph', 'fs_lvm', 'fs_lvm_ssh'].include? @info[:tm_mad]

        ds_mad_update = "DRIVER=raw\n"
        cli_update('onedatastore update 1', ds_mad_update, true)
        xml_datastore = cli_action_xml('onedatastore show 1 -x', true)
        expect(xml_datastore['TEMPLATE/DRIVER']).to eq('raw')

        # Create the image
        img_id = cli_create("oneimage clone #{@info[:img_name]} clone-#{@info[:img_name]} -d 1")
        wait_image_ready(10, img_id)

        # Check the FORMAT and DRIVER attributes
        img_xml = cli_action_xml("oneimage show -x clone-#{@info[:img_name]}")
        cli_action("oneimage delete clone-#{@info[:img_name]}")

        expect(img_xml["//FORMAT"]).to eq("raw")
    end


    it 'checks that format is forced when DRIVER is defined for DS (system)', :clean_ds do
        skip "Not applicable for #{@info[:tm_mad]}" if ['ceph', 'fs_lvm', 'fs_lvm_ssh'].include? @info[:tm_mad]

        disk_tmpl = <<-EOF
            DISK = [
                TYPE   = fs,
                SIZE   = 200,
                FORMAT = raw
            ]
        EOF

        ds_mad_update = "DRIVER=qcow2\n"
        cli_update('onedatastore update 0', ds_mad_update, true)
        xml_datastore = cli_action_xml('onedatastore show 0 -x', true)
        expect(xml_datastore['TEMPLATE/DRIVER']).to eq('qcow2')

        # Create volatile disk
        disk = Tempfile.new('volatile_disk')
        disk.write(disk_tmpl)
        disk.close
        cli_action("onevm disk-attach #{@info[:vm_id]} "\
                   "--file #{disk.path}")
        disk.unlink

        @info[:vm].running?
        @info[:vm].reachable?
        @info[:vm].info

        fmt = @info[:vm].xml["TEMPLATE/DISK[DISK_ID='#{@info[:disk_id]}']/FORMAT"]
        driver = @info[:vm].xml["TEMPLATE/DISK[DISK_ID='#{@info[:disk_id]}']/DRIVER"]

        # clean
        cli_action("onevm disk-detach #{@info[:vm_id]} #{@info[:disk_id]}")
        @info[:vm].running?
        @info[:vm].reachable?


        # Check the FORMAT and DRIVER attributes
        expect(fmt).to eq("qcow2")
        expect(driver).to eq("qcow2")
    end

end
