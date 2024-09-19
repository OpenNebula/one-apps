shared_examples_for 'GenericMarket' do |market_id|
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

        # Get image list
        if @info[:vcenter]
            @info[:ds] = DSDriver.get(@info[:ds_id])
            @info[:ds].fs_snap(@defaults[:vcenter_datastore_host],
                               @defaults[:vcenter_datastore_path])
        else
            @info[:image_list] = DSDriver.get(@info[:ds_id]).image_list
        end

        @info[:prefix] = @info[:vm].xml[
            'TEMPLATE/DISK[DISK_ID="0"]/DEV_PREFIX'
        ]

        # Used when importing to marketplace
        @info[:app_id]    = []
        @info[:delete_id] = []

        # Create datablock
        @info[:db_id] = cli_create(
            "oneimage create -d #{@info[:ds_id]} " \
            '--name testing_db ' \
            '--size 12 ' \
            '--type DATABLOCK'
        )

        # Start marketplace webserver
        market      = cli_action_xml("onemarket show #{market_id} -x")
        @info[:web] = Thread.new do
            server = WEBrick::HTTPServer.new(
                :BindAddress => '127.0.0.1',
                :Port => market['//TEMPLATE/BASE_URL'].split(':')[2].to_i,
                :DocumentRoot => market['//TEMPLATE/PUBLIC_DIR']
            )
            server.start
        end
    end

    ############################################################################
    # Create Image
    ############################################################################

    it 'oneimage create' do
        if @info[:vcenter]
            @info[:managed_img_name] = "mkt_#{@info[:vm_id]}"

            @info[:img_id] = cli_create(
                "oneimage create --name mkt_#{@info[:vm_id]} " \
                '--size 100 ' \
                '--type datablock ' \
                "-d #{@info[:ds_id]} " \
                '--prefix sd'
            )

            wait_loop(:success => 'READY', :break => 'ERROR') do
                xml = cli_action_xml("oneimage show -x #{@info[:img_id]}")
                Image::IMAGE_STATES[xml['STATE'].to_i]
            end
        else
            data_file = Tempfile.new('one-readiness')
            data_file.close

            SafeExec.run(
                'dd iflag=fullblock status=none ' \
                "if=/dev/urandom of=#{data_file.path} bs=1M count=12"
            )

            @info[:img_id] = cli_create(
                'oneimage create ' \
                "--name mkt_#{@info[:vm_id]} " \
                "--path #{data_file.path} " \
                "--prefix #{@info[:prefix]} " \
                "-d #{@info[:ds_id]}"
            )

            wait_loop(:success => 'READY', :break => 'ERROR') do
                xml = cli_action_xml("oneimage show -x #{@info[:img_id]}")
                Image::IMAGE_STATES[xml['STATE'].to_i]
            end

            @info[:md5] =
                SafeExec.run("md5sum #{data_file.path}").stdout.split.first

            data_file.unlink
        end
    end

    it 'monitor market' do
        market = []

        wait_loop do
            market = cli_action_xml("onemarket show -x #{market_id}")
            market['TOTAL_MB'].to_i != 0
        end

        total = market['TOTAL_MB'].to_i
        free  = market['FREE_MB'].to_i
        used  = market['USED_MB'].to_i

        expect(total).to be > 0
        expect(free+used).to eq(total)
    end

    it 'marketapp create' do
        if @info[:vcenter]
            @info[:mktapp_id] = cli_create(
                'onemarketapp create -m Test_Market ' \
                "--image \"#{@info[:managed_img_name]}\" " \
                "--name \"#{@info[:managed_img_name]}\""
            )
        else
            marketapp_template = <<-EOF.gsub(/^        /, '')
            NAME="mkt_#{@info[:vm_id]}"
            ORIGIN_ID=#{@info[:img_id]}
            TYPE=image
            EOF

            marketapp_template_file = TempTemplate.new(marketapp_template)
            marketapp_cmd = "onemarketapp create #{marketapp_template_file.path} " \
                            "-m #{market_id}"

            @info[:mktapp_id] = cli_create(marketapp_cmd)

            marketapp_template_file.unlink
        end

        wait_loop(:success => 'READY', :break => 'ERROR') do
            xml = cli_action_xml("onemarketapp show -x #{@info[:mktapp_id]}")
            MarketPlaceApp::MARKETPLACEAPP_STATES[xml['STATE'].to_i]
        end
    end

    it 'onemarketapp export' do
        cmd = cli_action("onemarketapp export #{@info[:mktapp_id]} " <<
                         "mkt_import_#{@info[:mktapp_id]} -d #{@info[:ds_id]}")

        ids = cmd.stdout.scan(/ID: (-?\d+)/).flatten

        expect(ids.length).to eq(1)
        expect(ids[0].to_i).to be >= -1

        @info[:img_import_id] = ids[0]

        wait_loop(:success => 'READY', :break => 'ERROR') do
            xml = cli_action_xml("oneimage show -x #{@info[:img_import_id]}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        end
    end

    it 'image sizes match' do
        img        = cli_action_xml("oneimage show -x #{@info[:img_id]}")
        img_import = cli_action_xml("oneimage show -x #{@info[:img_import_id]}")

        expect(img['SIZE']).to eq(img_import['SIZE'])
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

    it 'attach created image' do
        cli_action(
            "onevm disk-attach #{@info[:vm_id]} " \
            "--image #{@info[:img_id]} " \
            "--prefix #{@info[:prefix]}"
        )

        @info[:vm].state?('POWEROFF')
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

    it 'images match' do
        skip 'Only for KVM' if @info[:vcenter]

        target_created = @info[:vm].xml[
            "TEMPLATE/DISK[IMAGE_ID='#{@info[:img_id]}']/TARGET"
        ]
        target_imported = @info[:vm].xml[
            "TEMPLATE/DISK[IMAGE_ID='#{@info[:img_import_id]}']/TARGET"
        ]

        md5_created  = @info[:vm].ssh("md5sum /dev/#{target_created}")
        md5_imported = @info[:vm].ssh("md5sum /dev/#{target_imported}")

        md5_created  = md5_created.stdout.strip.split[0]
        md5_imported = md5_imported.stdout.strip.split[0]

        expect(md5_created).to eq(md5_imported)
        expect(md5_created.length).to eq 32
        expect(md5_created).to eq(@info[:md5])
    end

    ############################################################################
    # Import VM
    ############################################################################

    it 'attach datablock' do
        @info[:vm].safe_poweroff

        cli_action("onevm disk-attach #{@info[:vm_id]} --image #{@info[:db_id]}")

        @info[:vm].state?('POWEROFF')
        @info[:vm].resume
        @info[:vm].running?
        @info[:vm].reachable?
    end

    it 'modify content' do
        target = @info[:vm]['TEMPLATE/DISK[2]/TARGET']
        @info[:vm].ssh("echo testing > /dev/#{target}; sync")
        @info[:vm].ssh('echo testing > /root/testing; sync')
    end

    it 'import VM into marketplace' do
        @info[:vm].safe_poweroff

        cmd = cli_action_timeout(
            "onemarketapp vm import #{@info[:vm_id]} " \
            "--market #{market_id} " \
            '--yes',
            true,
            480
        ).stdout

        @info[:delete_id] << cmd.match(/delete (-?\d+)/)[1]

        apps = cmd.scan(/ID: (-?\d+)/).flatten
        apps.each do |app|
            wait_loop(:success => 'READY', :break => 'ERROR') do
                xml = cli_action_xml("onemarketapp show -x #{app}")
                MarketPlaceApp::MARKETPLACEAPP_STATES[xml['STATE'].to_i]
            end
        end

        @info[:app_id] << apps[-1]
    end

    ############################################################################
    ############################################################################

    it 'terminate vm' do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?

        # Datablock is no longer needed, delete it
        cli_action("oneimage delete #{@info[:db_id]}")

        wait_loop(:success => true) do
            cmd = cli_action("oneimage show #{@info[:db_id]} 2>/dev/null", nil)
            cmd.fail?
        end
    end

    it 'remove images' do
        cli_action("oneimage delete #{@info[:img_id]},#{@info[:img_import_id]}")

        wait_loop(:success => true) do
            cmd = cli_action("oneimage show #{@info[:img_id]} 2>/dev/null", nil)
            cmd.fail?
        end

        wait_loop(:success => true) do
            cmd = cli_action(
                "oneimage show #{@info[:img_import_id]} 2>/dev/null", nil
            )
            cmd.fail?
        end
    end

    it 'remove app' do
        cli_action("onemarketapp delete #{@info[:mktapp_id]}")
        wait_loop(:success => true) do
            cmd = cli_action(
                "onemarketapp show #{@info[:mktapp_id]} 2>/dev/null", nil
            )
            cmd.fail?
        end
    end

    ############################################################################
    # Export VM
    ############################################################################

    it 'export VM template' do
        cmd = cli_action(
            "onemarketapp export #{@info[:app_id].shift} 'alpine_2' -d 1"
        ).stdout

        apps = cmd.scan(/ID: (-?\d+)/).flatten
        apps[0..-2].each do |app|
            wait_loop(:success => 'READY', :break => 'ERROR') do
                xml = cli_action_xml("oneimage show -x #{app}")
                Image::IMAGE_STATES[xml['STATE'].to_i]
            end
        end

        # Add NIC requirements
        t = cli_action_xml('onetemplate show alpine_2 -x')
        t = t.to_hash

        t['VMTEMPLATE']['TEMPLATE']['NIC']['SCHED_REQUIREMENTS'] = 'ID=\"0\"'

        t = TemplateParser.template_like_str(t['VMTEMPLATE']['TEMPLATE'])

        cli_update('onetemplate update alpine_2', t, false)
    end

    it 'create VM [EXPORTED]' do
        @info[:vm_id] = cli_create('onetemplate instantiate alpine_2')
        @info[:vm]    = VM.new(@info[:vm_id])
    end

    it 'deploy [EXPORTED]' do
        @info[:vm].running?
    end

    it 'ssh and context [EXPORTED]' do
        @info[:vm].get_ip
        @info[:vm].reachable?
    end

    it 'check content [EXPORTED]' do
        target = @info[:vm]['TEMPLATE/DISK[2]/TARGET']
        cmd    = @info[:vm].ssh("head -n1 /dev/#{target}")

        expect(cmd.stdout.strip).to eq('testing')

        cmd = @info[:vm].ssh('ls /root/testing')
        expect(cmd.stdout.strip).to eq('/root/testing')
    end

    it 'terminate VM [EXPORTED]' do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    ############################################################################
    # Import VM template
    ############################################################################

    it 'import VM template into marketplace' do
        cmd = cli_action_timeout(
            'onemarketapp vm-template import alpine_2 ' \
            "--market #{market_id} " \
            '--yes',
            true,
            480
        ).stdout

        apps = cmd.scan(/ID: (-?\d+)/).flatten
        apps.each do |app|
            wait_loop(:success => 'READY', :break => 'ERROR') do
                xml = cli_action_xml("onemarketapp show -x #{app}")
                MarketPlaceApp::MARKETPLACEAPP_STATES[xml['STATE'].to_i]
            end
        end

        @info[:app_id] << apps[-1]

        cli_action('onetemplate delete alpine_2 --recursive')
    end

    ############################################################################
    # Export VM template
    ############################################################################

    it 'export VM template' do
        cmd = cli_action(
            "onemarketapp export #{@info[:app_id].shift} 'alpine_3' -d 1"
        ).stdout

        apps = cmd.scan(/ID: (-?\d+)/).flatten
        apps[0..-2].each do |app|
            wait_loop(:success => 'READY', :break => 'ERROR') do
                xml = cli_action_xml("oneimage show -x #{app}")
                Image::IMAGE_STATES[xml['STATE'].to_i]
            end
        end

        # Add NIC requirements
        t = cli_action_xml('onetemplate show alpine_3 -x')
        t = t.to_hash

        t['VMTEMPLATE']['TEMPLATE']['NIC']['SCHED_REQUIREMENTS'] = 'ID=\"0\"'

        t = TemplateParser.template_like_str(t['VMTEMPLATE']['TEMPLATE'])

        cli_update('onetemplate update alpine_3', t, false)
    end

    it 'create VM [EXPORTED]' do
        @info[:vm_id] = cli_create('onetemplate instantiate alpine_3')
        @info[:vm]    = VM.new(@info[:vm_id])
    end

    it 'deploy [EXPORTED]' do
        @info[:vm].running?
    end

    it 'ssh and context [EXPORTED]' do
        @info[:vm].get_ip
        @info[:vm].reachable?
    end

    it 'check content [EXPORTED]' do
        target = @info[:vm]['TEMPLATE/DISK[2]/TARGET']
        cmd    = @info[:vm].ssh("head -n1 /dev/#{target}")

        expect(cmd.stdout.strip).to eq('testing')

        cmd = @info[:vm].ssh('ls /root/testing')
        expect(cmd.stdout.strip).to eq('/root/testing')
    end

    it 'terminate VM [EXPORTED]' do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    ############################################################################
    # Import service template
    ############################################################################

    # TODO: implement tests for it

    ############################################################################
    # Export service template
    ############################################################################

    # TODO: implement tests for it

    ############################################################################
    ############################################################################

    it 'remove images and templates' do
        t1 = cli_action_xml('onetemplate show alpine_3 -x')
        t2 = cli_action_xml("onetemplate show #{@info[:delete_id].first} -x")

        cli_action('onetemplate delete alpine_3 --recursive')
        cli_action("onetemplate delete #{@info[:delete_id].first} --recursive")

        t1.retrieve_elements('//DISK/IMAGE_ID').each do |disk|
            wait_loop(:success => true) do
                cmd = cli_action(
                    "oneimage show #{disk.strip} 2>/dev/null", nil
                )
                cmd.fail?
            end
        end

        t2.retrieve_elements('//DISK/IMAGE_ID').each do |disk|
            wait_loop(:success => true) do
                cmd = cli_action(
                    "oneimage show #{disk.strip} 2>/dev/null", nil
                )
                cmd.fail?
            end
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

    after(:all) do
        @info[:web].kill
        @info[:web].join
    end
end
