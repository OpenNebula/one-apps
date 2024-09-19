shared_examples_for 'S3' do |market_id|
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
    end

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

    it 'terminate vm' do
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].done?
    end

    it 'remove images and templates' do
        cli_action("oneimage delete #{@info[:img_import_id]}")

        wait_loop(:success => true) do
            cmd = cli_action(
                "oneimage show #{@info[:img_import_id]} 2>/dev/null", nil
            )
            cmd.fail?
        end

        cli_action("oneimage delete #{@info[:img_id]}")

        wait_loop(:success => true) do
            cmd = cli_action(
                "oneimage show #{@info[:img_id]} 2>/dev/null", nil
            )
            cmd.fail?
        end

        cli_action("onetemplate delete \"#{@info[:new_template_name]}\"")
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
end
