#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
require 'webrick'
require 'one-open-uri'
require 'digest/md5'

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe 'MarketPlace operations test' do
    prepend_before(:all) do
        @defaults = YAML.load_file('spec/functionality/market/defaults.yaml')
        @defaults_yaml=File.realpath(File.join(File.dirname(__FILE__), 'defaults.yaml'))
    end

    before(:all) do
        @one_test.stop_one

        @monitor_action = "#{ONE_VAR_LOCATION}/remotes/market/one/monitor"

        disabled_monitor_actions = {}
        disabled_monitor_actions = ["#{ONE_VAR_LOCATION}/remotes/market/linuxcontainers/monitor"]

        FileUtils.cp(@monitor_action, "#{@monitor_action}.orig")

        File.open(@monitor_action, File::CREAT|File::TRUNC|File::RDWR, 0o644) do |f|
            f.write("#!/bin/bash\n")
            f.write("cat /tmp/one_market.monitor\n")
        end

        disabled_monitor_actions.each do |v|
            File.open(v, File::CREAT|File::TRUNC|File::RDWR, 0o644) do |f|
                f.write("#!/bin/bash\n")
                f.write("exit 0\n")
            end
        end

        @one_test.start_one

        @mpid = -1
        @mpid_app = -1
        @iid = -1

        File.open('/tmp/one_market.monitor', 'w') do |file|
            file.write('
            APP="TkFNRT0iQ29yZU9TIGFscGhhIgpTT1VSQ0U9Imh0dHA6Ly9tYXJrZXRwbGFjZS5vcGVubmVidWxhLnN5c3RlbXMvL2FwcGxpYW5jZS81NzAxNTE4MDhmYjgxZDBkNmYwMDAwMDIvZG93bmxvYWQvMCIKSU1QT1JUX0lEPSI1NzAxNTE4MDhmYjgxZDBkNmYwMDAwMDIiCk9SSUdJTl9JRD0iLTEiClRZUEU9IklNQUdFIgpQVUJMSVNIRVI9IkNhcmxvcyBWYWxpZW50ZSIKRk9STUFUPSJxY293MiIKREVTQ1JJUFRJT049IkNvcmVPUyBhbHBoYSBpbWFnZSBmb3IgS1ZNIGhvc3RzIHVuZGVyIE9wZW5OZWJ1bGEuIgpWRVJTSU9OPSIxMDAwLjAuMCIKVEFHUz0iY29yZW9zIgpSRUdUSU1FPSIxNDU5NzA0MTkyIgpTSVpFPSIxMDI0MCIKTUQ1PSJkNWEzNjQ4MDkyZjE5ZjNiZDBlNGVmOTYyODM4OTUyMCIKQVBQVEVNUExBVEU2ND0iUkZKSlZrVlNQU0p4WTI5M01pSUtWRmxRUlQwaVQxTWlDZz09IgpWTVRFTVBMQVRFNjQ9IlZWTkZVbDlKVGxCVlZGTWdQU0JiSUZWVFJWSmZSRUZVUVNBZ1BTSk5mSFJsZUhSOFZYTmxjaUJrWVhSaElHWnZjaUJnWTJ4dmRXUXRZMjl1Wm1sbllDSmRDZ3BIVWtGUVNFbERVeUE5SUZzZ1ZGbFFSU0FnUFNKMmJtTWlMRXhKVTFSRlRpQWdQU0l3TGpBdU1DNHdJbDBLQ2tOUFRsUkZXRlFnUFNCYklGTkZWRjlJVDFOVVRrRk5SU0FnUFNJa1RrRk5SU0lzVTFOSVgxQlZRa3hKUTE5TFJWa2dJRDBpSkZWVFJWSmJVMU5JWDFCVlFreEpRMTlMUlZsZElpeE9SVlJYVDFKTElDQTlJbGxGVXlJc1ZWTkZVbDlFUVZSQklDQTlJaVJWVTBWU1gwUkJWRUVpWFFvS1RVVk5UMUpaSUQwZ0lqVXhNaUlLVDFNZ1BTQmJJRUZTUTBnZ0lEMGllRGcyWHpZMElsMEtDa05RVlNBOUlDSXhJZz09Igo="
            APP="TkFNRT0iRnJlZUJTRCAxMC4zIgpTT1VSQ0U9Imh0dHA6Ly9tYXJrZXRwbGFjZS5vcGVubmVidWxhLnN5c3RlbXMvL2FwcGxpYW5jZS9lYmI4MWFhZi0wNTUyLTQ3YzEtOTU3OS03MjNjYzg0YjhlNzQvZG93bmxvYWQvMCIKSU1QT1JUX0lEPSJlYmI4MWFhZi0wNTUyLTQ3YzEtOTU3OS03MjNjYzg0YjhlNzQiCk9SSUdJTl9JRD0iLTEiClRZUEU9IklNQUdFIgpQVUJMSVNIRVI9IlRyaXZhZ28gR21iSCIKRk9STUFUPSJxY293MiIKREVTQ1JJUFRJT049IkZyZWVCU0QgMTAuMyB3aXRoIGNvbnRleHR1YWxpemF0aW9uIgpWRVJTSU9OPSIxLjAiClRBR1M9ImZyZWVic2QiClJFR1RJTUU9IjE0ODY0MDg4NDciClNJWkU9IjIwNDgwIgpNRDU9IjhhNDlmMmRhYzRhZTM3ZTI1YjM2NjcxNmQzYTljNGNmIgpBUFBURU1QTEFURTY0PSJSRVZXWDFCU1JVWkpXRDBpZG1RaUNrUlNTVlpGVWowaWNXTnZkeklpQ2xSWlVFVTlJazlUSWdvPSIKVk1URU1QTEFURTY0PSJRMDlPVkVWWVZDQTlJRnNnVGtWVVYwOVNTeUFnUFNKWlJWTWlMRk5UU0Y5UVZVSk1TVU5mUzBWWklDQTlJaVJWVTBWU1cxTlRTRjlRVlVKTVNVTmZTMFZaWFNJc1UwVlVYMGhQVTFST1FVMUZJQ0E5SWlST1FVMUZJbDBLQ2tOUVZTQTlJQ0l4SWdwSFVrRlFTRWxEVXlBOUlGc2dURWxUVkVWT0lDQTlJakF1TUM0d0xqQWlMRlJaVUVVZ0lEMGlkbTVqSWwwS0NrMUZUVTlTV1NBOUlDSTNOamdpQ2s5VElEMGdXeUJCVWtOSUlDQTlJbmc0Tmw4Mk5DSmRDZ3BWVTBWU1gwbE9VRlZVVXlBOUlGc2dVMU5JWDFWVFJWSmZTMFZaSUNBOUlrMThkR1Y0ZEh4VFUwZ2dTMFZaT2lCQlpHUnBkR2x2Ym1Gc0lITnphQ0JyWlhrZ2RHOGdZV1JrSWwwSyIK"
            APP="TkFNRT0iVnlPUyAxLjEuNSBIZWxpdW0gNjQgYml0cyIKU09VUkNFPSJodHRwOi8vbWFya2V0cGxhY2Uub3Blbm5lYnVsYS5zeXN0ZW1zLy9hcHBsaWFuY2UvNTU0MTEzMjQ4ZmI4MWQ2YTk0MDAwMDAxL2Rvd25sb2FkLzAiCklNUE9SVF9JRD0iNTU0MTEzMjQ4ZmI4MWQ2YTk0MDAwMDAxIgpPUklHSU5fSUQ9Ii0xIgpUWVBFPSJJTUFHRSIKUFVCTElTSEVSPSJBcnRlbUlUIgpGT1JNQVQ9InJhdyIKREVTQ1JJUFRJT049IlRoaXMgaW1hZ2UgaGFzIGJlZW4gY3JlYXRlZCB1c2luZyBWeU9TIDEuMS41IElTTyBmb3IgNjQgYml0cyBzbyB5b3UgY2FuIGRlcGxveSBhIHZpcnR1YWwgcm91dGVyIGFuZCBmaXJld2FsbC4gDQoNClZ5T1MgaXMgYSBjb21tdW5pdHkgZm9yayBvZiBWeWF0dGEsIGEgTGludXgtYmFzZWQgbmV0d29yayBvcGVyYXRpbmcgc3lzdGVtIHRoYXQgcHJvdmlkZXMgc29mdHdhcmUtYmFzZWQgbmV0d29yayByb3V0aW5nLCBmaXJld2FsbCwgYW5kIFZQTiBmdW5jdGlvbmFsaXR5Lg0KDQpUaGlzIGltYWdlIHByb3ZpZGVzIGEgVnlPUyB2aXJ0dWFsIHJvdXRlci9maXJld2FsbCBvbmx5IGZvciBLVk0uIFdoZW4gYm9vdGluZyBzZWxlY3QgdGhlIGZpcnN0IG9wdGlvbiAoS1ZNKS4iClZFUlNJT049IjEuMS41LTEiClRBR1M9InJvdXRlciwgdnlvcyIKUkVHVElNRT0iMTQzMDMyODEwMCIKU0laRT0iMjAwMCIKTUQ1PSJhYmE4NzY1Mjk4ZmZjZjg3ODRmOGE2ZDJiMjY3ZWI3OSIKQVBQVEVNUExBVEU2ND0iUkZKSlZrVlNQU0p5WVhjaUNsUlpVRVU5SWs5VElnbz0iCg=="
        ')
        end

        market = File.expand_path '/var/tmp/'

        @info       = {}
        @info[:web] = Thread.new do
            @info[:server] = WEBrick::HTTPServer.new(
                :Port         => 8888,
                :DocumentRoot => market
            )

            @info[:server].start
        end

        @market_template = <<-EOF
            NAME = testmarket
            MARKET_MAD  = http
            BASE_URL = "http://localhost:8888"
            PUBLIC_DIR = "/var/tmp"
        EOF

        mads = 'TM_MAD=dummy'

        cli_update('onedatastore update system', mads, false)
        cli_update('onedatastore update default', mads, false)

        wait_loop do
            xml = cli_action_xml('onedatastore show -x 1')
            xml['FREE_MB'].to_i > 0
        end

        @iid = cli_create('oneimage create -d 1 --type OS'\
                          ' --name testimage1 --path /etc/passwd')

        wait_loop do
            xml = cli_action_xml("oneimage show -x #{@iid}")
            (xml['STATE'] == '1')
        end

        cli_create_user("userA", "passwdA")
    end

    after(:all) do
        FileUtils.cp("#{@monitor_action}.orig", @monitor_action)

        begin
            @info[:server].stop if @info[:server]

            if @info[:web]
                @info[:web].kill
                @info[:web].join
            end
        rescue StandardError
        end
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    #---------------------------------------------------------------------------
    # Private MarketPlace (http)
    #---------------------------------------------------------------------------

    it 'should create a MarketPlace using stdin template' do
        cmd = 'onemarket create'

        stdin_cmd = <<~BASH
            #{cmd} <<EOF
            #{@market_template}
            EOF
        BASH

        @mpid = cli_create(stdin_cmd)
        mpxml= cli_action_xml('onemarket show -x testmarket')
        expect(mpxml['NAME']).to eq('testmarket')
    end

    it 'should create a MarketPlace App' do
        @mpid_app = cli_create('onemarketapp create '\
                          ' --name testapp --image testimage1 -m testmarket ')
        wait_loop do
            xml = cli_action_xml('onemarketapp show testapp -x')
            (xml['STATE'] == '1')
        end
        mpaxml= cli_action_xml("onemarketapp show #{@mpid_app} -x")
        expect(mpaxml['NAME']).to eq('testapp')
    end

    it 'should create a MarketPlace App using file template' do
        cmd = 'onemarketapp create --marketplace testmarket'

        name = 'testapp_file'
        description = 'testing if this is a valid file template'
        template = <<~EOT
            NAME = "#{name}"
            DESCRIPTION = "#{description}"
            ORIGIN_ID = #{@iid}
            TYPE = image
        EOT

        @mpid_app = cli_create(cmd, template)
        wait_loop do
            xml = cli_action_xml("onemarketapp show #{name} -x")
            (xml['STATE'] == '1')
        end

        mpaxml= cli_action_xml("onemarketapp show #{@mpid_app} -x")
        expect(mpaxml['NAME']).to eq(name)
        expect(mpaxml['DESCRIPTION']).to eq(description)
    end

    it 'should create a MarketPlace App using stdin template' do
        cmd = 'onemarketapp create --marketplace testmarket'

        name = 'testapp_stdin'
        description = 'testing if this is a valid stdin template'
        template = <<~EOT
            NAME = "#{name}"
            DESCRIPTION = "#{description}"
            ORIGIN_ID = #{@iid}
            TYPE = image
        EOT

        stdin_cmd = <<~BASH
            #{cmd} <<EOF
            #{template}
            EOF
        BASH

        @mpid_app = cli_create(stdin_cmd)
        wait_loop do
            xml = cli_action_xml("onemarketapp show #{name} -x")
            (xml['STATE'] == '1')
        end

        mpaxml= cli_action_xml("onemarketapp show #{@mpid_app} -x")
        expect(mpaxml['NAME']).to eq(name)
        expect(mpaxml['DESCRIPTION']).to eq(description)
    end

    it 'should export a MarketPlace App' do
        @id_export = cli_action('onemarketapp export testapp testimgexport -d 1')
        img_xml = cli_action_xml('oneimage show testimgexport -x')
        digest_http = Digest::MD5.hexdigest(ONE_URI.open(img_xml['PATH']).read)
        digest_local = Digest::MD5.hexdigest(File.read('/etc/passwd'))
        expect(digest_http).to eq(digest_local)
    end

    it 'should change owner and group for App from private Marketplace' do
        cli_action('onemarketapp chown testapp userA')
        cli_action('onemarketapp chgrp testapp users')
    end

    it 'should create a MarketPlace App with same name, different user' do
        @mpid_app = cli_create('onemarketapp create '\
                          ' --name testapp --image testimage1 -m testmarket ')

        mpaxml= cli_action_xml("onemarketapp show #{@mpid_app} -x")
        expect(mpaxml['NAME']).to eq('testapp')
    end

    it 'should fail to delete MarketPlace with apps' do
        cli_action('onemarket delete testmarket', false)
    end

    it "should delete an existing MarketPlace and check that, now, it doesn't exist" do
        xml = cli_action_xml('onemarket show testmarket -x')

        app_ids = xml.retrieve_elements('MARKETPLACEAPPS/ID')

        app_ids.each {|app_id| cli_action("onemarketapp delete #{app_id}") }

        cli_action('onemarket delete testmarket')
    end

    #---------------------------------------------------------------------------
    # Public MarketPlace
    #---------------------------------------------------------------------------

    it 'should chmod Marketplace' do
        xml = cli_action_xml("onemarket show -x 0")

        expect(xml['PERMISSIONS/OWNER_U']).to eq('1')
        expect(xml['PERMISSIONS/OWNER_M']).to eq('1')
        expect(xml['PERMISSIONS/OWNER_A']).to eq('1')
        expect(xml['PERMISSIONS/GROUP_U']).to eq('1')
        expect(xml['PERMISSIONS/GROUP_M']).to eq('0')
        expect(xml['PERMISSIONS/GROUP_A']).to eq('0')
        expect(xml['PERMISSIONS/OTHER_U']).to eq('1')
        expect(xml['PERMISSIONS/OTHER_M']).to eq('0')
        expect(xml['PERMISSIONS/OTHER_A']).to eq('0')

        cli_action("onemarket chmod 0 766")

        xml = cli_action_xml("onemarket show -x 0")

        expect(xml['PERMISSIONS/OWNER_U']).to eq('1')
        expect(xml['PERMISSIONS/OWNER_M']).to eq('1')
        expect(xml['PERMISSIONS/OWNER_A']).to eq('1')
        expect(xml['PERMISSIONS/GROUP_U']).to eq('1')
        expect(xml['PERMISSIONS/GROUP_M']).to eq('1')
        expect(xml['PERMISSIONS/GROUP_A']).to eq('0')
        expect(xml['PERMISSIONS/OTHER_U']).to eq('1')
        expect(xml['PERMISSIONS/OTHER_M']).to eq('1')
        expect(xml['PERMISSIONS/OTHER_A']).to eq('0')
    end

    it 'should rename Marketplace' do
        xml = cli_action_xml("onemarket show -x 0")

        expect(xml['NAME']).to eq('OpenNebula Public')

        cli_action("onemarket rename 0 renamed")

        xml = cli_action_xml("onemarket show -x 0")

        expect(xml['NAME']).to eq('renamed')
    end

    it 'should update Marketplace' do
        xml = cli_action_xml("onemarket show -x 0")

        expect(xml['TEMPLATE/DESCRIPTION']).to eq('OpenNebula Systems MarketPlace')

        cli_update("onemarket update 0", 'DESCRIPTION="Update description"', true)

        xml = cli_action_xml("onemarket show -x 0")

        expect(xml['TEMPLATE/DESCRIPTION']).to eq('Update description')
    end

    it 'should disable Marketplace' do
        mpxml = cli_action_xml('onemarket show 0 -x')

        expect(mpxml['STATE'].to_i).to eq(0)
        expect(mpxml['MARKETPLACEAPPS/ID'].length).to be > 0

        cli_action('onemarket disable 0')

        mpxml = cli_action_xml('onemarket show 0 -x')

        expect(mpxml['STATE'].to_i).to eq(1)
        expect(mpxml['MARKETPLACEAPPS/ID']).to be_nil
    end

    it 'should enable Marketplace' do
        cli_action('onemarket enable 0')

        mpxml = cli_action_xml('onemarket show 0 -x')

        expect(mpxml['STATE'].to_i).to eq(0)
        expect(mpxml['MARKETPLACEAPPS/ID'].length).to be > 0
    end

    it 'should not change owner or group for App from public Marketplace' do
        mpxml = cli_action_xml('onemarket show 0 -x')

        app_id = mpxml['MARKETPLACEAPPS/ID[1]']

        cli_action("onemarketapp chown #{app_id} userA", false)
        cli_action("onemarketapp chgrp #{app_id} users", false)
    end

    it 'should delete a MarketPlace App' do
        File.open('/tmp/one_market.monitor',
                  'w') do |file|
            file.write('APP="TkFNRT0iRnJlZUJTRCAxMC4zIgpTT1VSQ0U9Imh0dHA6Ly9tYXJrZXRwbGFjZS5vcGVubmVidWxhLnN5c3RlbXMvL2FwcGxpYW5jZS9lYmI4MWFhZi0wNTUyLTQ3YzEtOTU3OS03MjNjYzg0YjhlNzQvZG93bmxvYWQvMCIKSU1QT1JUX0lEPSJlYmI4MWFhZi0wNTUyLTQ3YzEtOTU3OS03MjNjYzg0YjhlNzQiCk9SSUdJTl9JRD0iLTEiClRZUEU9IklNQUdFIgpQVUJMSVNIRVI9IlRyaXZhZ28gR21iSCIKRk9STUFUPSJxY293MiIKREVTQ1JJUFRJT049IkZyZWVCU0QgMTAuMyB3aXRoIGNvbnRleHR1YWxpemF0aW9uIgpWRVJTSU9OPSIxLjAiClRBR1M9ImZyZWVic2QiClJFR1RJTUU9IjE0ODY0MDg4NDciClNJWkU9IjIwNDgwIgpNRDU9IjhhNDlmMmRhYzRhZTM3ZTI1YjM2NjcxNmQzYTljNGNmIgpBUFBURU1QTEFURTY0PSJSRVZXWDFCU1JVWkpXRDBpZG1RaUNrUlNTVlpGVWowaWNXTnZkeklpQ2xSWlVFVTlJazlUSWdvPSIKVk1URU1QTEFURTY0PSJRMDlPVkVWWVZDQTlJRnNnVGtWVVYwOVNTeUFnUFNKWlJWTWlMRk5UU0Y5UVZVSk1TVU5mUzBWWklDQTlJaVJWVTBWU1cxTlRTRjlRVlVKTVNVTmZTMFZaWFNJc1UwVlVYMGhQVTFST1FVMUZJQ0E5SWlST1FVMUZJbDBLQ2tOUVZTQTlJQ0l4SWdwSFVrRlFTRWxEVXlBOUlGc2dURWxUVkVWT0lDQTlJakF1TUM0d0xqQWlMRlJaVUVVZ0lEMGlkbTVqSWwwS0NrMUZUVTlTV1NBOUlDSTNOamdpQ2s5VElEMGdXeUJCVWtOSUlDQTlJbmc0Tmw4Mk5DSmRDZ3BWVTBWU1gwbE9VRlZVVXlBOUlGc2dVMU5JWDFWVFJWSmZTMFZaSUNBOUlrMThkR1Y0ZEh4VFUwZ2dTMFZaT2lCQlpHUnBkR2x2Ym1Gc0lITnphQ0JyWlhrZ2RHOGdZV1JrSWwwSyIK"
            APP="TkFNRT0iVnlPUyAxLjEuNSBIZWxpdW0gNjQgYml0cyIKU09VUkNFPSJodHRwOi8vbWFya2V0cGxhY2Uub3Blbm5lYnVsYS5zeXN0ZW1zLy9hcHBsaWFuY2UvNTU0MTEzMjQ4ZmI4MWQ2YTk0MDAwMDAxL2Rvd25sb2FkLzAiCklNUE9SVF9JRD0iNTU0MTEzMjQ4ZmI4MWQ2YTk0MDAwMDAxIgpPUklHSU5fSUQ9Ii0xIgpUWVBFPSJJTUFHRSIKUFVCTElTSEVSPSJBcnRlbUlUIgpGT1JNQVQ9InJhdyIKREVTQ1JJUFRJT049IlRoaXMgaW1hZ2UgaGFzIGJlZW4gY3JlYXRlZCB1c2luZyBWeU9TIDEuMS41IElTTyBmb3IgNjQgYml0cyBzbyB5b3UgY2FuIGRlcGxveSBhIHZpcnR1YWwgcm91dGVyIGFuZCBmaXJld2FsbC4gDQoNClZ5T1MgaXMgYSBjb21tdW5pdHkgZm9yayBvZiBWeWF0dGEsIGEgTGludXgtYmFzZWQgbmV0d29yayBvcGVyYXRpbmcgc3lzdGVtIHRoYXQgcHJvdmlkZXMgc29mdHdhcmUtYmFzZWQgbmV0d29yayByb3V0aW5nLCBmaXJld2FsbCwgYW5kIFZQTiBmdW5jdGlvbmFsaXR5Lg0KDQpUaGlzIGltYWdlIHByb3ZpZGVzIGEgVnlPUyB2aXJ0dWFsIHJvdXRlci9maXJld2FsbCBvbmx5IGZvciBLVk0uIFdoZW4gYm9vdGluZyBzZWxlY3QgdGhlIGZpcnN0IG9wdGlvbiAoS1ZNKS4iClZFUlNJT049IjEuMS41LTEiClRBR1M9InJvdXRlciwgdnlvcyIKUkVHVElNRT0iMTQzMDMyODEwMCIKU0laRT0iMjAwMCIKTUQ1PSJhYmE4NzY1Mjk4ZmZjZjg3ODRmOGE2ZDJiMjY3ZWI3OSIKQVBQVEVNUExBVEU2ND0iUkZKSlZrVlNQU0p5WVhjaUNsUlpVRVU5SWs5VElnbz0iCg=="')
        end
        wait_loop(:success => 2, :timeout => 600) do
            mpxml_list = cli_action_xml('onemarketapp list -x')
            count = 0
            mpxml_list.each('/MARKETPLACEAPP_POOL/MARKETPLACEAPP') do |_a|
                count +=1
            end
            count
        end
    end

    it 'should delete Marketplace' do
        cli_action('onemarket delete 0')

        cli_action('onemarket show 0', false)
    end

end
