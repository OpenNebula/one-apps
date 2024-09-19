require 'securerandom'

module CLITester

    # Basic OpenNebula object definition with common actions, queries and XML handling capabilities
    # Use as a parent class for other OpenNebula objects
    class OneObject

        include RSpec::Matchers

        attr_reader :id

        def initialize(id)
            @id = id
            @defaults = RSpec.configuration.defaults

            info
        end

        def [](key)
            @xml[key]
        end

        def xml(refresh = true)
            info if refresh
            @xml
        end

        def self.onecmd
            raise 'implement in child class'
        end

        def self.random_name(kinda_name = '')
            new_name = "#{name}_#{kinda_name}_#{SecureRandom.uuid}"
            new_name.slice!('CLITester::')
            new_name
        end

        ######

        # Actions

        #
        # Returns the list of objects in the pool
        #
        # @return [Array] Existing objects
        #
        def self.list(options = '')
            cmd = "#{onecmd} list --no-header -l ID #{options}"
            SafeExec.run(cmd).stdout.split("\n")
        end

        def chown(user = 'oneadmin', group = 'oneadmin')
            cli_action("#{self.class.onecmd} chown #{@id} #{user} #{group}")
            info
        end

        def rename(name)
            cli_action("#{self.class.onecmd} rename #{@id} #{name}")
            info
        end

        def delete(options = '')
            cli_action("#{self.class.onecmd} delete #{@id} #{options}")
        end

        #
        # Used to check expected failure when deleting the object
        #
        # @return [SafeExec] onedatastore delete command execution
        #
        def delete_fail
            cli_action("#{self.class.onecmd} delete #{@id}", false)
        end

        # Info

        def name
            @xml['NAME']
        end

        def ownership
            permissions = @xml.retrieve_xmlelements('PERMISSIONS')[0]

            {
                :uid    => @xml['UID'],
                :gid    => @xml['GID'],
                :user   => @xml['UNAME'],
                :group  => @xml['GNAME'],
                :permissions => {
                    :owner => {
                        :use    => permissions['OWNER_U'],
                        :manage => permissions['OWNER_M'],
                        :admin  => permissions['OWNER_A']
                    },
                    :group => {
                        :use    => permissions['GROUP_U'],
                        :manage => permissions['GROUP_M'],
                        :admin  => permissions['GROUP_A']
                    },
                    :other => {
                        :use    => permissions['OTHER_U'],
                        :manage => permissions['OTHER_M'],
                        :admin  => permissions['OTHER_A']
                    }

                }

            }
        end

        def deleted?(timeout = 60)
            wait_loop(:success => true, :break => 'ERROR', :timeout => timeout) do
                cmd = cli_action("#{self.class.onecmd} show #{@id}", nil, true)
                cmd.fail?
            end
        end

        private

        def info
            @xml = cli_action_xml("#{self.class.onecmd} show -x #{@id}")
        end

    end

end
