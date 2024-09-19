require 'aws-sdk-ec2'

# AWS
class AWS

    def initialize(access, secret)
        @aws = Aws::EC2::Resource.new(
            :access_key_id     => access,
            :secret_access_key => secret,
            :region            => 'us-east-1'
        )
    end

    def delete_devices
        # True means there are no instances
        ret = true

        @aws.instances({ :filters => [:name   => 'instance-state-name',
                         :values  => ['running']] }).each do |instance|
            ret = false
            instance.terminate
        end

        # Wait until the instances are gone otherwise
        # you can't delete network intefaces later
        while @aws.instances({ :filters => [:name   => 'instance-state-name',
                               :values  => ['shutting-down']] }).count > 0

            puts "Shutting down instances..."
            sleep 10
        end

        ret
    end

    def delete_net
        # True means there are no instances
        ret = true

        @aws.client.describe_addresses[:addresses].each do |i|
            next unless i[:network_interface_id].nil? # IP is assigned

            ret = false
            ip  = @aws.client.describe_addresses(
                { :filters => [{ :name   => 'public-ip',
                                 :values => [i[:public_ip]] }] }
            ).addresses[0]

            @aws.client.release_address(
                { :allocation_id => ip[:allocation_id] }
            )
        end

        @aws.client.describe_vpcs(
            { :filters => [{ :name   => 'is-default',
                             :values => ['false'] },
                           { :name   => 'tag:Name',
                             :values => ['aws-*cluster_vpc'] }] } # could be aws-cluster_vpc
                                                                  # or aws-hci-cluster_vpc

        ).vpcs.each do |vpc|
            ret = false
            delete_vpc(vpc.vpc_id)
        end

        ret
    end

    private

    def delete_vpc(vpc_id)
        # network interfaces
        nics = @aws.client.describe_network_interfaces().network_interfaces

        nics.each do |nic|
            @aws.client.delete_network_interface(
                { :network_interface_id => nic.network_interface_id }
            )
        end

        sgroups = @aws.client.describe_security_groups(
            { :filters => [{ :name => 'vpc-id', :values => [vpc_id] }] }
        ).security_groups

        sgroups.each do |sg|
            next if sg.group_name == 'default'

            @aws.client.delete_security_group({ :group_id => sg.group_id })
        end

        # subnets
        subnets = @aws.client.describe_subnets(
            { :filters => [{ :name => 'vpc-id', :values => [vpc_id] }] }
        ).subnets

        subnets.each do |sn|
            @aws.client.delete_subnet({ :subnet_id => sn.subnet_id })
        end

        # internet gateways
        igateways = @aws.client.describe_internet_gateways(
            { :filters => [
                { :name   => 'attachment.vpc-id',
                  :values => [vpc_id] }
            ] }
        ).internet_gateways

        igateways.each do |igt|
            # detach
            @aws.client.detach_internet_gateway(
                { :internet_gateway_id => igt.internet_gateway_id,
                  :vpc_id              => vpc_id }
            )

            # delete
            @aws.client.delete_internet_gateway(
                { :internet_gateway_id => igt.internet_gateway_id }
            )
        end

        # the VPC itself
        @aws.client.delete_vpc({ :vpc_id => vpc_id, :dry_run => false })
    end

end
