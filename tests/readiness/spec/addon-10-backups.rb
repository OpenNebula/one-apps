require 'init'
require 'webrick'

describe "Backups_addon" do
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}

        @info[:vm_id] = cli_create("onetemplate instantiate '#{@defaults[:template]}'")
        @info[:vm]    = VM.new(@info[:vm_id])

        # Start marketplace webserver
        @info[:web] = Thread.new {
            server = WEBrick::HTTPServer.new(
                :BindAddress => '127.0.0.1',
                :Port => 8000,
                :DocumentRoot => '/var/tmp'
            )
            server.start
        }

        #creating HTTP marketplace
        #TODO: HTTP should be running before creating a marketplace,
        # otherwise we lose one monitoring cycle and have to wait long
        # time for monitoring
        file = Tempfile.new('market.conf')
        file << "Name = Test_Market\n"
        file << "MARKET_MAD = http\n"
        file << "BASE_URL = \"http://localhost:8000/\"\n"
        file << "PUBLIC_DIR = \"/var/tmp\""
        file.flush
        file.close

        output = cli_action("onemarket create " + file.path)
        @info[:market_id] = output.stdout.scan(/ID: (-?\d+)/).flatten[0]
    end

    it "should poweroff the VM" do
        @info[:vm].state?("RUNNING")
        @info[:vm].reachable?
        @info[:vm].safe_poweroff
        @info[:vm].state?("POWEROFF")
    end

    it "should create persistent image" do
        @info[:ds_id] = @info[:vm].xml['TEMPLATE/DISK[DISK_ID="0"]/DATASTORE_ID']
        cmd = "oneimage create --name pers-datablock-#{@info[:vm_id]} " <<
              "--size 100 --type datablock " <<
              "-d #{@info[:ds_id]} --persistent"

        img_id = cli_create(cmd)

        wait_loop(:success => "READY", :break => "ERROR") {
            xml = cli_action_xml("oneimage show -x #{img_id}")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        }

        @info[:pimg_id]       = img_id
    end

    it "should attach persistent image" do
        disk_count_before = 0
        @info[:vm].xml.each("TEMPLATE/DISK"){ disk_count_before += 1 }

        cli_action("onevm disk-attach #{@info[:vm_id]} "\
                   "--image #{@info[:pimg_id]}")

        @info[:vm].state?('POWEROFF')

        disk_count = 0
        @info[:vm].xml.each("TEMPLATE/DISK"){ disk_count += 1 }
        expect(disk_count - disk_count_before).to eq(1)
        @info[:persistent_disk_id] = disk_count
    end

    #For vCenter, it is necessary to restart VM so changes are applied
    it "should turn on and off" do
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].state?("RUNNING")
        @info[:vm].reachable?
        @info[:vm].safe_poweroff
        @info[:vm].state?("POWEROFF")
    end

    it "should backup disks" do
        system("ruby /var/lib/one/backup_disk.rb --vm #{@info[:vm_id]} --disk 0 --market #{@info[:market_id]}")
        system("ruby /var/lib/one/backup_disk.rb --vm #{@info[:vm_id]} --disk #{@info[:persistent_disk_id]} --market #{@info[:market_id]}")
    end

    it "should check if backup from non-persistent disk was succesful" do
        marketapp_pool = cli_action_xml('onemarketapp list -x')
        @info[:non_pers_app_id] = -1

        marketapp_pool.each('/MARKETPLACEAPP_POOL/MARKETPLACEAPP') do |app|
            if app['NAME'].include? "#{@defaults[:template]}-#{@info[:vm_id]}_disk_0"
                @info[:non_pers_app_id] = app['ID'].to_i
                break
            end
        end
        expect(@info[:non_pers_app_id]).to be >= 0
    end

    it "should check if backup from persistent disk was succesful" do
        marketapp_pool = cli_action_xml('onemarketapp list -x')
        @info[:pers_app_id] = -1

        marketapp_pool.each('/MARKETPLACEAPP_POOL/MARKETPLACEAPP') do |app|
            if app['NAME'].include? "#{@defaults[:template]}-#{@info[:vm_id]}_disk_#{@info[:persistent_disk_id]}"
                @info[:pers_app_id] = app['ID'].to_i
                break
            end
        end
        expect(@info[:pers_app_id]).to be >= 0
    end

    after(:all) do
        system("onemarketapp delete #{@info[:pers_app_id]}")
        system("onemarketapp delete #{@info[:non_pers_app_id]}")
        system("onemarket delete #{@info[:market_id]}")
        @info[:web].kill
        @info[:web].join

        @info[:vm].terminate
        @info[:vm].done?
        @info[:vm] = nil

        cli_action("oneimage delete #{@info[:pimg_id]}")
        wait_loop(:success => true) {
            cmd = cli_action("oneimage show #{@info[:pimg_id]} 2>/dev/null", nil)
            cmd.fail?
        }
    end
end


