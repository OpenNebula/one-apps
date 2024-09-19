module CLITester
require 'json'

# methods
class OneFlowService
    include RSpec::Matchers

    attr_accessor :id

    def initialize(id)
        @id    = id

        json
    end

    def info
        cmd = SafeExec.run("oneflow show --json #{@id}")
        @str = cmd.stdout
    end

    def json(refresh=true)
        info if refresh
        @json = JSON.parse(@str)
    end

    def get_role(role_name)
        @json["DOCUMENT"]["TEMPLATE"]["BODY"]["roles"].each do |role|
            return role if role["name"] == role_name
        end
    end

    def get_role_vm_ids(role)
        return get_role(role)['nodes'].map do |node|
            node["vm_info"]["VM"]["ID"]
        end
    end

end
# end module CLITester
end
