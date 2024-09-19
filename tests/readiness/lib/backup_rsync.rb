require 'datastore'

module CLITester

    #
    # Rsync backup datastore used to abstract CLI operations on the datastore itself and
    # to perform rsync administrative commands.
    #
    class RSyncDS < Datastore

        #
        # Creates a new rsync backup datastore and distributes SSH keys
        #
        # @param [String] name Datastore name
        # @param [String] host hostname/IP to use as sftp server
        # @param [String] extra arguments for the rsync command
        #
        # @return [RSyncDS] RSync backup datastore CLITester object
        #
        def self.create(name, host, rsync_args = '-aS')
            template = generate_template(name, host, rsync_args)
            super(template)
        end

        #
        # Creates a new rsync slow (--bwlimit=1) backup datastore and distributes SSH keys
        #
        # @param [String] name Datastore name
        # @param [String] host hostname/IP to use as sftp server
        #
        # @return [RSyncDS] RSync backup datastore CLITester object
        #
        def self.create_slow(name, host)
            self.create(name, host, '-aS --bwlimit=1')
        end

        def self.generate_template(name, host, rsync_args = '-aS')
            <<~EOT
                #{super(name, 'BACKUP_DS', 'rsync', '-')}
                RSYNC_HOST = #{host}
                RSYNC_USER = "oneadmin"
                RSYNC_IONICE = "6"
                RSYNC_NICE   = "19"
                RSYNC_ARGS   = "#{rsync_args}"
            EOT
        end

    end

end
