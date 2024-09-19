module CLITester

# DSDriver should only be used in the following manner:
#   DSDriver.get(@ds_id)
# which returns a child class that implements:
# - image_list
#   returns: array image list
#
# Add the new child classes to the self.get method
class DSDriver
    include RSpec::Matchers

    attr_accessor :xml
    attr_reader   :id

    def initialize(id, xml=nil)
        @id = id

        if xml.nil?
            info
        else
            @xml = xml
        end
    end

    def info
        @xml = cli_action_xml("onedatastore show #{@id} -x")
    end

    def ds_mad
        @xml["DS_MAD"]
    end

    def self.get(id)
        ds_classes = {
            :ceph  => CephDSDriver,
            :fs => FSDSDriver,
            :vcenter => VCenterDSDriver
        }

        ds = self.new(id)
        ds_classes[ds.ds_mad.to_sym].new(id, ds.xml)
    end
end

class CephDSDriver < DSDriver
    def initialize(id, xml=nil)
      super(id, xml)

      @user = @xml['TEMPLATE/CEPH_USER']
      @rbd  = @user ? "rbd --id #{@user}" : "rbd"
    end

    def image_list
        cmd = cli_action("ssh #{HOST_SSH_OPTS} #{get_host} #{@rbd} ls one", nil)
        return cmd.stdout
    end

private

    def get_host
        @xml['TEMPLATE/BRIDGE_LIST'].split(" ").sample
    end
end

class FSDSDriver < DSDriver
    def image_list
        cmd = cli_action("find /var/lib/one/datastores/#{@id} -type f", nil)
        return cmd.stdout
    end
end

class VCenterDSDriver < DSDriver
    def fs_snap(user, host, directory)
        @user       = user
        @host       = host
        @dir        = directory
        @snap       = image_list(user, host, directory)
    end

    def unchanged?(wait=30)
        raise 'datastore checkpoint not defined!' unless @snap
        sleep(wait)

        expect(image_list(@user, @host, @dir)).to eq(@snap)
    end

    def image_list(user, host, directory)
        cmd = cli_action("ssh #{user}@#{host} find #{directory} -type f -iname '\\*.vmdk' -o -iname '\\*.iso'", true)
        return cmd.stdout
    end
end

# end module CLITester
end
