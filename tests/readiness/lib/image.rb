require 'oneobject'

module CLITester
    # TODO: Use Image name and specify OpenNebula::Image on the tests that use bare Image

    class CLIImage < OneObject

        def self.onecmd
            'oneimage'
        end

        # Actions

        def self.create(name = random_name, datastore = 1, options = '')
            cmd = "#{onecmd} create --name '#{name}' -d '#{datastore}' #{options}"

            new(cli_create_lite(cmd))
        end

        #
        # Returns the list of images in the pool
        #
        # @return [Array] Existing image entries
        #
        def self.list(options = '')
            cmd = "#{onecmd} list --no-header #{options}"
            SafeExec.run(cmd).stdout.split("\n")
        end

        #
        # Restores an image. Image must be backup type
        #
        # @param [String] datastore id or name
        #
        # @return [Array] id of template and id of image
        #
        def restore(datastore = 1, options = '')
            cmd = cli_action("#{self.class.onecmd} restore #{@id} -d #{datastore} #{options}")

            # "VM Template: 19\nImages: 92\n"
            ids = cmd.stdout.split("\n")

            template_id = ids[0].split(':')[1].strip
            image_id    = ids[1].split(':')[1].split unless ids[1].nil?

            [template_id, image_id].flatten.compact
        end

        def delete
            cli_action("#{self.class.onecmd} delete #{@id}")
        end

        def deleted_no_fail?(timeout)
            timeout_reached = false
            t_start         = Time.now

            while Time.now - t_start < timeout do
                cmd = cli_action("oneimage show #{@id}", nil, true)

                return true if cmd.fail?

                sleep 1
            end

            timeout_reached
        end

        # Info

        def source
            @xml['SOURCE']
        end

        def format
            @xml['FORMAT']
        end

        def backup_increments
            @xml['BACKUP_INCREMENTS']
        end

        # IMAGE_TYPES=%w{OS CDROM DATABLOCK KERNEL RAMDISK CONTEXT BACKUP}
        def type
            OpenNebula::Image::IMAGE_TYPES[@xml['TYPE'].to_i]
        end

        def backup?
            type == 'BACKUP'
        end

        def persistent?
            @xml['PERSISTENT'] == 1
        end

        def size_m
            "#{@xml['SIZE']}M"
        end

        alias size size_m

        def ready?
            state?('READY')
        end

        def used?
            state?('USED')
        end

        def error?
            state?('ERROR', :break_cond => 'READY')
        end

        # IMAGE_STATES=%w{
        # INIT READY USED DISABLED LOCKED ERROR CLONE DELETE USED_PERS LOCKED_USED LOCKED_USED_PERS
        # }
        def state
            info
            OpenNebula::Image::IMAGE_STATES[@xml['STATE'].to_i]
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
