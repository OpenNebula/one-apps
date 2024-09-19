
require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

describe "Monitoring encryption test" do
    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        src_file = File.join(File.dirname(__FILE__), 'monitord_example.extra.conf')
        @dst_file = File.join(File.dirname(__FILE__), 'monitord.extra.conf')
        pub_file = File.join(File.dirname(__FILE__), 'monitor_key.pub.pem')
        pri_file = File.join(File.dirname(__FILE__), 'monitor_key')

        # Read monitor_example.conf
        text = File.read(src_file)

        # Write paths to public and private key
        text.gsub!(/PUBKEY  = ""/, "PUBKEY  = \"#{pub_file}\"")
        text.gsub!(/PRIKEY  = ""/, "PRIKEY  = \"#{pri_file}\"")

        # Save as monitord.extra.conf, which is used in defaults_monitor.yaml
        File.open(@dst_file, "w") { |file| file.write(text) }

        @defaults_yaml=File.join(File.dirname(__FILE__), 'defaults_monitor.yaml')
    end

    before(:all) do
        cli_create("onehost create host01 --im dummy --vm dummy")

        @vm_id = cli_create("onevm create --name testvm --cpu 1 --memory 1")
        @vm = VM.new(@vm_id)

        cli_action("onevm deploy #{@vm_id} host01")
        @vm.running?
    end

    after(:all) do
        cli_action("onevm recover --delete #{@vm_id}")
        cli_action("onehost delete host01");

        File.delete(@dst_file);
    end

    it "should check the host SYSTEM_HOST message" do
        host = Host.new("host01")
        host.monitored?

        fields = %w(HOST_SHARE/TOTAL_MEM
            HOST_SHARE/TOTAL_CPU)

        fields.each do |field|
            expect(host[field]).to_not eql(nil)
        end
    end

    it "should check the host MONITOR_HOST message" do
        host = Host.new("host01")
        host.monitored?

        wait_loop do
            xml = host.info
            not xml["MONITORING/CAPACITY/FREE_CPU"].nil?
        end

        fields = %w(MONITORING/CAPACITY/FREE_CPU
            MONITORING/CAPACITY/FREE_MEMORY
            MONITORING/CAPACITY/USED_MEMORY
            MONITORING/CAPACITY/USED_CPU
            MONITORING/SYSTEM/NETRX
            MONITORING/SYSTEM/NETTX)

        fields.each do |field|
            expect(host[field]).to_not eql(nil)
        end
    end

    it "should check the host MONITOR_VM message" do
        @vm.wait_monitoring_info("CPU")

        xml = @vm.info
        expect(xml["MONITORING/MEMORY"]).not_to eql nil
    end

    it "should check the host STATE_VM message" do
        @vm.running?

        cli_action("onevm poweroff #{@vm_id}")

        @vm.stopped?
    end

end