require 'open3'

module CLITester
# methods

class SafeExec
    include RSpec::Matchers

    attr_reader :status, :stdout, :stderr

    def self.run(cmd, timeout = DEFAULT_EXEC_TIMEOUT, try=1, quiet=false)
        e = self.new(cmd, timeout, quiet)
        while ( !e.success? && try > 0 ) do
            e.run!
            try -= 1
            !e.success? && try > 0 && sleep(1)
        end
        e
    end

    def initialize(cmd, timeout = DEFAULT_EXEC_TIMEOUT, quiet = false)
        @cmd = cmd
        @timeout = timeout
        @defaults = RSpec.configuration.defaults
        @debug = @defaults[:debug]
        @quiet = quiet

        @status = nil
        @stdout = nil
        @stderr = nil
    end

    def run!
        puts "RUN (#{Time.now}): #{@cmd}" if @debug

        begin
            stdout = ""
            stderr = ""
            status = 0
            out    = nil
            err    = nil

            Timeout::timeout(@timeout) {
                stdin, stdout, stderr, wait_thr = Open3.popen3(@cmd)

                out = Thread.new do
                    ret = stdout.read
                    stdout.close unless stdout.closed?
                    ret
                end

                err = Thread.new do
                    ret = stderr.read
                    stderr.close unless stderr.closed?
                    ret
                end

                status = wait_thr.value

                stdin.close unless stdin.closed?
            }

            @status = status.exitstatus
            @stdout = out.value if out
            @stderr = err.value if err
        rescue Timeout::Error
            timeout_msg = "Timeout Reached for: '#{@cmd}'"
            STDERR.puts timeout_msg unless @quiet
            @status = -1
            @stderr = timeout_msg
        end

        if fail? && !@stderr.empty?
            STDERR.puts @stderr unless @quiet
        end

        pp @status if @debug
    end

    def success?
        @status == 0
    end

    def fail?
        !success?
    end

    def exitstatus
        @status
    end

    def expect_success
        expect(success?).to be(true), "Expected success for: #{@cmd}\n#{@stderr}"
    end

    def expect_fail
        expect(fail?).to be(true), "Expected fail for: #{@cmd}\n#{@stderr}"
    end
end

# end module CLITester
end
