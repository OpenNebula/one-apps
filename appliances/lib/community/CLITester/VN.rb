require 'oneobject'

module CLITester

    class VN < OneObject

        def self.onecmd
            'onevnet'
        end

        # Actions

        # Creates a new datastore in OpenNebula using a template defintion
        #
        # @param [String] template OpenNebula template definition
        #
        # @return [Datastore] Datastore CLITester object
        #
        def self.create(template)
            file = Tempfile.new('ds_template')
            file.write(template)
            file.close

            cmd = "#{onecmd} create #{file.path}"
            vnet = new(cli_create_lite(cmd))

            file.unlink

            vnet
        end

        def delete
            cli_action("#{self.class.onecmd} delete #{@id}")
        end

        # Info

        def ready?
            state?('READY')
        end

        def error?
            state?('ERROR', :break_cond => 'READY')
        end

        # VN_STATES=%w{
        # INIT READY LOCK_CREATE LOCK_DELETE DONE ERROR UPDATE_FAILURE
        # }
        def state
            info
            OpenNebula::VirtualNetwork::VN_STATES[@xml['STATE'].to_i]
        end

        def state?(state_target, break_cond = 'ERROR')
            args = {
                :success => state_target,
                :break => break_cond,
                :resource_ref => @id,
                :resource_type => self.class
            }

            wait_loop(args) { state }
        end
    end

end
