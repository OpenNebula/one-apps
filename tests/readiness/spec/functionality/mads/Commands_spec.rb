require 'init_functionality'

require 'CommandManager'

#-------------------------------------------------------------------------------

shared_examples_for "GenericCommand" do |custom_class, host|
    # purpose of this example is mainly to eat the error output from SSH:
    # Warning: Permanently added 'localhost' (ECDSA) to the list of known hosts.
    it "runs without error" do
        args = ['echo']
        args << host if host
        lc = custom_class.new(*args)
        rc = lc.run

        expect(rc).to eq(0)
        expect(lc.get_error_message).to eq("-")
    end

    it "reads large stdout" do
        args = ['dd if=/dev/urandom bs=1 count=100000 status=none | base64']
        args << host if host
        lc = custom_class.new(*args)
        rc = lc.run

        expect(rc).to eq(0)
        expect(lc.get_error_message).to eq("-")
        expect(lc.stdout.length).to be >= 100000
        expect(lc.stderr).to be_empty
    end

    it "reads large stderr" do
        args = ['dd if=/dev/urandom bs=1 count=100000 status=none | base64 >&2']
        args << host if host
        lc = custom_class.new(*args)
        rc = lc.run

        expect(rc).to eq(0)
        expect(lc.get_error_message).not_to eq("-")
        expect(lc.stdout).to be_empty
        expect(lc.stderr.length).to be >= 100000
    end

    it "reads large stdout and stderr" do
        args = ['dd if=/dev/urandom bs=1 count=100000 status=none | base64 | tee /dev/stderr']
        args << host if host
        lc = custom_class.new(*args)
        rc = lc.run

        expect(rc).to eq(0)
        expect(lc.get_error_message).not_to eq("-")
        expect(lc.stdout.length).to be >= 100000
        expect(lc.stderr.length).to be >= 100000
        expect(lc.stdout).to eq(lc.stderr)
    end

    it "gets no stdin" do
        args = ['cat -']
        args << host if host
        lc = custom_class.new(*args)
        rc = lc.run

        expect(rc).to eq(0)
        expect(lc.get_error_message).to eq("-")
        expect(lc.stdout).to be_empty
        expect(lc.stderr).to be_empty
    end

    it "gets stdin and outputs stdin" do
        args = ["cat -"]
        args << host if host
        lc = custom_class.new(*args, nil, 'WeLoveONE')
        rc = lc.run

        expect(rc).to eq(0)
        expect(lc.get_error_message).to eq("-")
        expect(lc.stdout).to eq('WeLoveONE')
        expect(lc.stderr).to be_empty
    end

    it "should run within given timeout" do
        args = ["echo 1; echo 2"]
        args << host if host
        lc = custom_class.new(*args, nil, nil, 2)
        rc = lc.run

        expect(rc).to eq(0)
        expect(lc.get_error_message).to eq("-")
        expect(lc.stdout).to eq("1\n2\n")
        expect(lc.stderr).to be_empty
    end

    it "should timeout" do
        ts = Time.now

        sleep_t = "#{Random.rand(300..600)}.123456789"
        args = ["echo 1; sleep #{sleep_t}; echo 2"]
        args << host if host
        lc = custom_class.new(*args, nil, nil, 1)
        rc = lc.run

        expect(rc).to eq(255)
        expect(lc.get_error_message).to eq("Timeout executing echo 1; sleep #{sleep_t}; echo 2")
        expect(lc.stdout).to be_nil
        expect(Time.now-ts).to be < 3

        # check no sleep process is running on background
        args = ["ps -Ao cmd"]
        args << host if host
        lc = custom_class.new(*args, nil, nil, 1)
        rc = lc.run

        expect(rc).to eq(0)
        expect(lc.stdout.length).to be > 200
        expect(lc.stdout).not_to match(/sleep #{sleep_t}/)
    end

    it "should not timeout with nil and 0" do
        [nil, 0].each do |timeout|
            args = ["echo 1; sleep 2; echo 2"]
            args << host if host
            lc = custom_class.new(*args, nil, nil, timeout)
            rc = lc.run

            expect(rc).to eq(0)
            expect(lc.get_error_message).to eq("-")
            expect(lc.stdout).to eq("1\n2\n")
            expect(lc.stderr).to be_empty
        end
    end

    it "exits with custom code" do
        args = [host ? 'exit 111' : '/bin/bash -c "exit 111"']
        args << host if host
        lc = custom_class.new(*args)
        rc = lc.run

        expect(rc).to eq(111)
        expect(lc.get_error_message).to eq("-")
        expect(lc.stdout).to be_empty
        expect(lc.stderr).to be_empty
    end

    it "exits with custom code within timeout" do
        args = [host ? 'exit 111' : '/bin/bash -c "exit 111"']
        args << host if host
        lc = custom_class.new(*args, nil, nil, 1)
        rc = lc.run

        expect(rc).to eq(111)
        expect(lc.get_error_message).to eq("-")
        expect(lc.stdout).to be_empty
        expect(lc.stderr).to be_empty
    end

    it "doesn't exit with custom code on connection error" do
        if host
            ssh_err = "Could not resolve hostname somenonexistinghost.example"
            args = [host ? 'exit 111' : '/bin/bash -c "exit 111"']
            args << 'SomeNonExistingHost.example'
            lc = custom_class.new(*args)
            rc = lc.run

            expect(rc).not_to eq(0)
            expect(rc).not_to eq(111)
            expect(lc.get_error_message).to include(ssh_err)
            expect(lc.stdout).to be_empty
            expect(lc.stderr).not_to be_empty
        else
           skip "Unsupported on local command"
        end
    end
end

#-------------------------------------------------------------------------------

RSpec.describe "Command runners" do
    before(:all) do
    end

    context "LocalCommand" do
        include_examples 'GenericCommand', LocalCommand
    end

    context "SSHCommand" do
        include_examples 'GenericCommand', SSHCommand, 'localhost'
    end
end
