shared_examples_for 'OneSysMarket' do |_|
    # MD5s of the ttylinux image and raw block device
    TTY_APP_MD5 = 'b8ccdc63fb9d72ed12547fb1499c8b73'
    TTY_DEV_MD5 = '113dab4a332eec852dd0cdd17c11b066'

    # VMTEMPLATE name
    VMTEMPLATE = 'Custom via netboot.xyz'

    before(:all) do
        # Used to pass info accross tests
        @info     = {}
        @defaults = RSpec.configuration.defaults

        # Check if tests are vcenter or not
        @info[:vcenter] = !@defaults[:vcenter].nil?

        @info[:vm_id] = cli_create(
            "onetemplate instantiate --hold '#{@defaults[:template]}'"
        )
        @info[:vm] = VM.new(@info[:vm_id])

        if @info[:vcenter]
            @info[:ds_id] = cli_action_xml(
                'onedatastore list -x'
            )["DATASTORE[NAME = '#{@defaults[:datastore]}(IMG)']/ID"]
        else
            @info[:ds_id] = @info[:vm].xml[
                'TEMPLATE/DISK[DISK_ID="0"]/DATASTORE_ID'
            ]
        end

        @info[:prefix] = @info[:vm].xml[
            'TEMPLATE/DISK[DISK_ID="0"]/DEV_PREFIX'
        ]

        if (driver = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DRIVER'])
            @info[:datablock_opts] = "--format #{driver}"
        else
            @info[:datablock_opts] = ''
        end

        # Get image list
        if @info[:vcenter]
            @info[:ds] = DSDriver.get(@info[:ds_id])
            @info[:ds].fs_snap(@defaults[:vcenter_datastore_host],
                               @defaults[:vcenter_datastore_path])
        else
            @info[:image_list] = DSDriver.get(@info[:ds_id]).image_list
        end

        # It's an upgrade microenv from v512, read appliances again
        if @defaults[:flavours].is_a?(Array) && \
                @defaults[:flavours].include?('v512')

            cli_action('onemarket disable "OpenNebula Public"')
            sleep 1
            cli_action('onemarket enable "OpenNebula Public"')

            wait_loop do
                SafeExec.run("onemarketapp show '#{VMTEMPLATE}'").success?
            end
        end
    end

    it 'onemarketapp export' do
        # Fix error: (invalid byte sequence in US-ASCII)
        Encoding.default_external = Encoding::UTF_8
        Encoding.default_internal = Encoding::UTF_8

        marketapp_pool = cli_action_xml('onemarketapp list -x')

        ttylinux_app_id = -1
        marketapp_pool.each('/MARKETPLACEAPP_POOL/MARKETPLACEAPP') do |app|
            if app['MD5'] == TTY_APP_MD5
                ttylinux_app_id = app['ID'].to_i
                break
            end
        end

        expect(ttylinux_app_id).to be >= 0

        @info[:mktapp_id] = ttylinux_app_id

        cmd = cli_action(
            "onemarketapp export #{@info[:mktapp_id]} " \
            "mkt_import_#{@info[:vm_id]}_#{@info[:mktapp_id]} " \
            "-d #{@info[:ds_id]}"
        )

        ids = cmd.stdout.scan(/ID: (-?\d+)/).flatten

        expect(ids.length).to eq(2)
        expect(ids[0].to_i).to be >= -1

        @info[:img_import_id] = ids[0]

        wait_loop(:success => 'READY', :break => 'ERROR') do
            xml = cli_action_xml("oneimage show -x #{@info[:img_import_id]}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        end
    end

    ############################################################################
    # Create VM, Poweroff safely and Attach images
    ############################################################################

    it 'deploys' do
        cli_action("onevm release #{@info[:vm_id]}")
        @info[:vm].running?
    end

    it 'ssh and context' do
        @info[:vm].reachable?
    end

    it 'poweroff' do
        @info[:vm].safe_poweroff
    end

    it 'attach imported image' do
        cli_action(
            "onevm disk-attach #{@info[:vm_id]} " \
            "--image #{@info[:img_import_id]} " \
            "--prefix #{@info[:prefix]}"
        )

        @info[:vm].state?('POWEROFF')
    end

    it 'resume' do
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it 'image md5 is correct' do
        target_imported = @info[:vm].xml[
            "TEMPLATE/DISK[IMAGE_ID='#{@info[:img_import_id]}']/TARGET"
        ]

        md5_imported = @info[:vm].ssh("md5sum /dev/#{target_imported}")
        md5_imported = md5_imported.stdout.strip.split[0]

        expect(md5_imported).to eq(TTY_DEV_MD5)
    end

    it 'terminate vm' do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    it 'remove images' do
        cli_action("oneimage delete #{@info[:img_import_id]}")

        wait_loop(:success => true) do
            cmd = cli_action(
                "oneimage show #{@info[:img_import_id]} 2>/dev/null", nil
            )
            cmd.fail?
        end
    end

    it 'datastore contents are unchanged' do
        if @info[:vcenter]
            @info[:ds].unchanged?
        else
            wait_loop(:timeout => 30) do
                DSDriver.get(@info[:ds_id]).image_list == @info[:image_list]
            end

            expect(DSDriver.get(@info[:ds_id]).image_list).to eq(@info[:image_list])
        end
    end

    it 'export VM template from marketplace' do
        cmd = cli_action(
            "onemarketapp export '#{VMTEMPLATE}' " \
            "testing_template -d #{@info[:ds_id]}"
        )

        # Check exported IDs
        ids = cmd.stdout.scan(/ID: (-?\d+)/).flatten

        expect(ids.length).to eq(3)
        expect(Integer(ids[0])).to be >= -1
        expect(Integer(ids[1])).to be >= -1
        expect(Integer(ids[2])).to be >= -1

        # Wait until images are ready
        wait_loop(:success => 'READY', :break => 'ERROR') do
            xml = cli_action_xml("oneimage show -x #{ids[0]}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        end

        wait_loop(:success => 'READY', :break => 'ERROR') do
            xml = cli_action_xml("oneimage show -x #{ids[1]}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        end

        # Check template exists
        cli_action("onetemplate show #{ids[2]}")

        # Check VM template
        template = cli_action_xml("onetemplate show -x #{ids[2]}")
        disks    = template.retrieve_xmlelements('//DISK')

        expect(disks.size).to eq(2)
        expect(disks[0]['IMAGE_ID']).to eq(ids[0])
        expect(disks[1]['IMAGE_ID']).to eq(ids[1])

        # Delete exported objects
        cli_action("onetemplate delete #{ids[2]} --recursive")
    end

    it 'check context packages appliance size' do
        skip 'Not on upgrade microenvs' if @defaults[:microenv] == 'kvm-ssh-upgrade'

        app = cli_action_xml("onemarketapp show 'Contextualization Packages' -x")

        # context packages ISO should be ~ 1-2MB
        expect(app['//SIZE'].to_i).to be >= 1
        expect(app['//SIZE'].to_i).to be <= 3
    end
end
