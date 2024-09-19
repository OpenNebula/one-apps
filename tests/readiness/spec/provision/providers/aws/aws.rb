RSpec.shared_examples_for 'aws_provision' do |hypervisor, type, instance|
    provider_path = '/usr/share/one/oneprovision/edge-clusters/' \
                    "#{type}/providers/aws/aws-us-east-1.yml"

    inputs = 'aws_ami_image=default,' <<
             "aws_root_size=100," <<
             "aws_instance_type=#{instance}," <<
             'number_hosts=2,' <<
             'number_public_ips=2,' <<
             'dns=1.1.1.1,' <<
             "one_hypervisor=#{hypervisor}"

    before(:all) do
        @info = {}
    end

    it_behaves_like 'provision', hypervisor, type, provider_path, inputs

    it_behaves_like 'aws_tf'

    it_behaves_like 'cleanup'
end
