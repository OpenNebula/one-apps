require 'datastore'
require 'json'

module CLITester

    #
    # Restic backup datastore used to abstract CLI operations on the datastore itself and
    # to perform restic administrative commands mostly related to the bound restic repo
    #
    class ResticDS < Datastore

        # path of the restic binary shipped with the enterprise edition
        RESTIC = '/var/lib/one/remotes/datastore/restic/restic'

        attr_reader :repo

        #
        # Creates a new restic backup datastore and initializes its associated sftp repo
        #
        # @param [String] name Datastore name
        # @param [String] host hostname/IP to use as sftp server
        # @param [String] download/upload speed limit passed to restic command, (-1) means no limit
        #
        # @return [ResticDS] Restic backup datastore CLITester object
        #
        def self.create(name, host, bwlimit = -1)
            template = generate_template(name, host, bwlimit)
            datastore = super(template)

            datastore
        end

        #
        # Creates a new slow (bwlimit=1) restic backup datastore and initializes its associated sftp repo
        #
        # @param [String] name Datastore name
        # @param [String] host hostname/IP to use as sftp server
        #
        # @return [ResticDS] Restic backup datastore CLITester object
        #
        def self.create_slow(name, host)
            self.create(name, host, 1)
        end

        def self.generate_template(name, host, bwlimit = -1)
            <<~EOT
                #{super(name, 'BACKUP_DS', 'restic', '-')}
                RESTIC_SFTP_SERVER=#{host}
                RESTIC_PASSWORD="opennebula"
                RESTIC_MAX_RIOPS="1000"
                RESTIC_MAX_WIOPS="1000"
                RESTIC_CPU_QUOTA="60"
                RESTIC_BWLIMIT="#{bwlimit}"
            EOT
        end

        #
        # Checks if the restic ee-tools binary exists
        #
        # @return [Bool]
        #
        def self.binary?
            return true if File.exist?(RESTIC)

            false
        end

        def sftp_server
            @xml['TEMPLATE']['RESTIC_SFTP_SERVER']
        end

    end

end
