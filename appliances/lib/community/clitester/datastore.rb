require 'tempfile'
require 'oneobject'

module CLITester

    #
    # OpenNebula datastore object used to abstract CLI operations on the datastore.
    # For specialized datastores that require OS level operations, a child class should be created
    # to handle these operations and the special parameters of the datastore definition
    #
    class Datastore < OneObject

        #
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
            datastore = new(cli_create_lite(cmd))

            file.unlink

            datastore
        end

        #
        # OpenNebula minimal datastore template format. Extend in more advanced datastores
        #
        # @param [String] name Datastore name
        # @param [String] type Purpose of the datastore: backup/System/Image/File
        # @param [String] ds_mad Datastore driver
        # @param [String] tm_mad Transfer Manager driver
        #
        # @return [String] Datastore template definition
        #
        def self.generate_template(name, type, ds_mad, tm_mad)
            <<~EOT
                NAME="#{name}"
                DS_MAD=#{ds_mad}
                TM_MAD=#{tm_mad}
                TYPE=#{type}
            EOT
        end

        def self.onecmd
            'onedatastore'
        end

        def delete
            super
            fs_remove
        end

        def fs_remove
            FileUtils.remove_dir(path)
        rescue StandardError
        end

        def drivers
            [@xml['DS_MAD'], @xml['TM_MAD']]
        end

        #
        # Filesystem location of the datastore
        #
        # @return [String] Path
        #
        def path
            @xml['BASE_PATH']
        end

        def image?
            type == 'IMAGE'
        end

        def system?
            type == 'SYSTEM'
        end

        def file?
            type == 'FILE'
        end

        def backup?
            type == 'BACKUP'
        end

        def usage_m
            {
                :total 	=> @xml['TOTAL_MB'],
                :free 	=> @xml['FREE_MB'],
                :used 	=> @xml['USED_MB']
            }
        end

        alias usage usage_m

        # DATASTORE_TYPES=%w[IMAGE SYSTEM FILE BACKUP]
        def type
            OpenNebula::Datastore::DATASTORE_TYPES[@xml['TYPE'].to_i]
        end

    end

end
