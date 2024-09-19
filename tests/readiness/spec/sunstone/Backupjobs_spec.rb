require 'init_functionality'
require 'sunstone_test'
require 'sunstone/BackupJobs'

RSpec.describe "Sunstone backupjob tab", :type => 'skip' do

    before(:all) do
        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        @sunstone_test = SunstoneTest.new(@auth)
        @sunstone_test.login
        @backupjob = Sunstone::Backupjobs.new(@sunstone_test)
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "should create a backupjob" do
        hash = {
            priority: "50",
            fsFreeze: "NONE",
            mode: "FULL",
            keepLast: "1", 
            backupVolatile: "YES"
        }
        name = "test"
        @backupjob.create(name, hash)

        @sunstone_test.wait_resource_create("backupjob", name)
        backupjob = cli_action_xml("onebackupjob show -x #{name}") rescue nil

        expect(backupjob['TEMPLATE/BACKUP_VOLATILE']).to eql hash[:backupVolatile]
        expect(backupjob['TEMPLATE/FS_FREEZE']).to eql hash[:fsFreeze]
        expect(backupjob['TEMPLATE/KEEP_LAST']).to eql hash[:keepLast]
        expect(backupjob['TEMPLATE/MODE']).to eql hash[:mode]
        expect(backupjob['PRIORITY']).to eql hash[:priority]
    end

    it "should delete a backupjobs" do
        name = "test"
        @backupjob.delete(name)

        @sunstone_test.wait_resource_delete("backupjob", name)
        xml = cli_action_xml("onebackupjob list -x") rescue nil
        if !xml.nil?
            expect(xml["BACKUPJOB[NAME=#{name}]"]).to be(nil)
        end
    end

end
