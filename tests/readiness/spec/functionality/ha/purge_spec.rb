require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Logdb purge test" do

    prepend_before(:all) do
        @defaults_yaml=File.realpath(File.join(File.dirname(__FILE__),'defaults.yaml'))
        @defaults_raft = YAML::load(File.read("spec/functionality/ha/oned.extra.yaml"))
    end

    before(:all) do
        cli_action("onezone server-add 0 --name server-0 --rpc http://localhost:2633/RPC2")

        @one_test.stop_one

        `sed 's/SERVER_ID=\"-1\",/SERVER_ID=\"0\",/g' #{ONE_ETC_LOCATION}/oned.conf > /tmp/oned.conf.tmp \
         && cat /tmp/oned.conf.tmp > #{ONE_ETC_LOCATION}/oned.conf`

        @one_test.start_one

        wait_loop(:success => true) {
            `onezone show 0 | grep leader -c`.to_i == 1
        }
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------
    it "check purged records" do

        wait_loop(:success => true) {
            `grep "Purging obsolete LogDB" /var/log/one/oned.log -c`.to_i >= 0
        }

        10.times do |i|
            cli_action("onegroup create group#{i}")
        end

        wait_loop(:success => true) {
            `grep "Purging obsolete LogDB" /var/log/one/oned.log -c`.to_i >= 2
        }

        log_records = `grep "Purging obsolete LogDB" /var/log/one/oned.log -m 2`

        lines = log_records.split "\n"

        expect(lines.size).to  eq(2)

        lines.each do |line|
            purged_records = line.scan(/records\: (\d+)/)[0][0]

            if purged_records.to_i == 0
                records_idxs = line.scan(/(\d+)\,(\d+)/)[1]
                expect(records_idxs[1].to_i - records_idxs[0].to_i).to be < (@defaults_raft["RAFT"]["LOG_RETENTION"].to_i)
            elsif
                records_idxs = line.scan(/(\d+)\,(\d+)/)[1]
                expect(records_idxs[1].to_i - records_idxs[0].to_i).to be >=(@defaults_raft["RAFT"]["LOG_RETENTION"].to_i - 1)
            end
        end
    end
end
