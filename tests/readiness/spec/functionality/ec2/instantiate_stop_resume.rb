require 'init_functionality'
require 'one-open-uri'
require 'yaml'
require 'aws-sdk-ec2'

AUTHPATH="/tmp/auth.yaml"
RSpec.describe "instantiate/suspend/resume Amazon EC2 Integration tests" do

    def ec2_init(opts)
        Aws.config.merge!(opts)

        ec2 = Aws::EC2::Resource.new
    end

    def clean_machines
        raise "ec2 not defined" unless @ec2

        @ec2.instances.each do |vm|
            vm.terminate if vm.key_name == @defaults[:ec2_keypair]
        end
    end

    #---------------------------------------------------------------------------
    # Defines test configuration and start OpenNebula
    #---------------------------------------------------------------------------
    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do
        open(AUTHPATH, 'w') do |file|
            file.write(ONE_URI.open(@defaults[:credentials_url]).read)
        end

        begin
            EC2_CONF = YAML::load(File.read(AUTHPATH))
        rescue Exception => e
            raise "Unable to read '#{AUTHPATH}'. Invalid YAML syntax:\n" + e.message
        end

        opts = {:access_key_id => EC2_CONF['access'], :secret_access_key => EC2_CONF['secret'], :region => EC2_CONF['region'] }
        @ec2 = ec2_init(opts)

        template = <<-EOF
            EC2_ACCESS="#{EC2_CONF['access']}"
            EC2_SECRET="#{EC2_CONF['secret']}"
            REGION_NAME="#{EC2_CONF['region']}"
            CAPACITY=[M1_SMALL="5"]
        EOF

        file = Tempfile.new('ec2-host')
        file << template
        file.flush
        file.close

        @info = {}
        @info[:host_id] = cli_create("onehost create ec2 -t ec2 #{file.path} --im ec2 --vm ec2")
        @info[:host] = Host.new @info[:host_id]
    end

    it "monitors host" do
        expect(@info[:host].monitored?).to eq("MONITORED")
    end

    ###

    it "deploys VM" do
        template = <<-EOF
            NAME="EC2VM_TEST"
            CPU="0.1"
            MEMORY="256"
            PUBLIC_CLOUD=[
                AMI="#{@defaults[:ec2_ami]}",
                INSTANCETYPE="#{@defaults[:ec2_instancetype]}",
                KEYPAIR="#{@defaults[:ec2_keypair]}",
                TYPE="ec2" ]
            SCHED_REQUIREMENTS="PUBLIC_CLOUD=YES"
        EOF

        @info[:tpl_id] = cli_create("onetemplate create", template)

        @info[:vm_id] = cli_create("onetemplate instantiate #{@info[:tpl_id]}")
        @info[:vm] = VM.new(@info[:vm_id])
        @info[:vm].state?("RUNNING",/FAIL|^POWEROFF|UNKNOWN/)
    end

    it "suspends VM" do
        cli_action("onevm suspend #{@info[:vm_id]}")
        @info[:vm].state?("SUSPENDED",/FAIL|^FAILURE|UNKNOWN/)
    end

    it "resumes VM" do
        cli_action("onevm resume #{@info[:vm_id]}")
        @info[:vm].state?("RUNNING",/FAIL|^FAILURE|UNKNOWN/)
    end

    it "monitors VM" do
        @ip = @info[:vm].wait_monitoring_info("AWS_PUBLIC_IP_ADDRESS")
    end

    it "terminates VM" do
        @info[:vm].running?
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].state?("DONE",/FAIL|FAILURE|UNKNOWN/)
        cli_action("onetemplate delete #{@info[:tpl_id]}")
    end

    ###

    it "deploys VM with CONTEXT" do
        template = <<-EOF
            NAME="EC2VM_TEST_2"
            CPU="0.1"
            MEMORY="256"
            CONTEXT = [
                USERNAME = "$UNAME",
                SSH_PUBLIC_KEY = "$USER[SSH_PUBLIC_KEY]" ]
            PUBLIC_CLOUD=[
                AMI="#{@defaults[:ec2_ami]}",
                INSTANCETYPE="#{@defaults[:ec2_instancetype]}",
                KEYPAIR="#{@defaults[:ec2_keypair]}",
                TYPE="ec2" ]
            SCHED_REQUIREMENTS="PUBLIC_CLOUD=YES"
        EOF

        @info[:tpl_id] = cli_create("onetemplate create", template)

        @info[:vm_id] = cli_create("onetemplate instantiate #{@info[:tpl_id]}")
        @info[:vm] = VM.new(@info[:vm_id])
        @info[:vm].state?("RUNNING",/FAIL|^POWEROFF|UNKNOWN/)
    end

    it "monitors VM" do
        @ip = @info[:vm].wait_monitoring_info("AWS_PUBLIC_IP_ADDRESS")
    end

    it "terminates VM" do
        @info[:vm].running?
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].state?("DONE",/FAIL|FAILURE|UNKNOWN/)
        cli_action("onetemplate delete #{@info[:tpl_id]}")
    end

    ###

    it "deploys VM with custom USERDATA" do
        template = <<-EOF
            NAME="EC2VM_TEST_3"
            CPU="0.1"
            MEMORY="256"
            PUBLIC_CLOUD=[
                AMI="#{@defaults[:ec2_ami]}",
                INSTANCETYPE="#{@defaults[:ec2_instancetype]}",
                KEYPAIR="#{@defaults[:ec2_keypair]}",
                USERDATA="#{@defaults[:ec2_userdata]}",
                TYPE="ec2" ]
            SCHED_REQUIREMENTS="PUBLIC_CLOUD=YES"
        EOF

        @info[:tpl_id] = cli_create("onetemplate create", template)

        @info[:vm_id] = cli_create("onetemplate instantiate #{@info[:tpl_id]}")
        @info[:vm] = VM.new(@info[:vm_id])
        @info[:vm].state?("RUNNING",/FAIL|^POWEROFF|UNKNOWN/)
    end

    it "monitors VM" do
        @ip = @info[:vm].wait_monitoring_info("AWS_PUBLIC_IP_ADDRESS")
    end

    it "terminates VM" do
        @info[:vm].running?
        cli_action("onevm terminate --hard #{@info[:vm_id]}")
        @info[:vm].state?("DONE",/FAIL|FAILURE|UNKNOWN/)
        cli_action("onetemplate delete #{@info[:tpl_id]}")
    end

    after(:all) do
        clean_machines
    end
end
