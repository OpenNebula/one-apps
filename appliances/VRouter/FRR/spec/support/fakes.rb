# frozen_string_literal: true

require_relative '../../reloader'

# Records every call; `reload` outcomes are consumed in order (default true).
class FakeReloader
    attr_reader :calls

    def initialize(test: true, reload: [true], test_output: 'syntax error', reload_output: 'boom')
        @test          = test
        @reload        = reload.dup
        @test_output   = test_output
        @reload_output = reload_output
        @calls         = []
    end

    def test(path)
        @calls << [:test, path]
        Service::FRR::Reloader::Result.new(ok: @test, output: @test ? 'ok' : @test_output)
    end

    def reload(path)
        @calls << [:reload, path]
        ok = @reload.shift
        ok = true if ok.nil?
        Service::FRR::Reloader::Result.new(ok: ok, output: ok ? 'ok' : @reload_output)
    end

    def soft_refresh(commands)
        @calls << [:soft_refresh, commands]
        Service::FRR::Reloader::Result.new(ok: true, output: '')
    end

    def summary(command)
        @calls << [:summary, command]
        Service::FRR::Reloader::Result.new(ok: true, output: '{}')
    end
end

require_relative '../../applier'

class FakeApplier
    attr_reader :calls

    def initialize(statuses = [:applied])
        @statuses = statuses.dup
        @calls    = []
    end

    def call(attrs, ha_state:)
        @calls << [attrs, ha_state]
        status = @statuses.size > 1 ? @statuses.shift : @statuses.first
        Service::FRR::Applier::Result.new(status: status, message: '', config: nil)
    end
end

class FakeReporter
    attr_reader :results, :publishes

    def initialize
        @results   = []
        @publishes = 0
    end

    def apply_result(result) = @results << result

    def publish = @publishes += 1
end

class FakeOneGate
    attr_accessor :template

    def initialize(template)
        @template = template
    end

    def vm_show
        return nil if @template.nil?

        { 'VM' => { 'USER_TEMPLATE' => @template } }
    end
end
