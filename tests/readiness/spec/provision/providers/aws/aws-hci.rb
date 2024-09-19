RSpec.shared_examples_for 'aws_hci_provision' do |hypervisor, type, instance|
    provider_path = '/usr/share/one/oneprovision/edge-clusters/' \
                    "#{type}/providers/aws/aws-us-east-1.yml"

    inputs = 'aws_ami_image=default,' <<
             "aws_instance_type=#{instance}," <<
             "aws_root_size=100," <<
             'number_ceph_full_hosts=3,' <<
             'number_ceph_osd_hosts=0,' <<
             'number_ceph_client_hosts=0,' <<
             'number_public_ips=3,' <<
             'dns=1.1.1.1,' <<
             "ceph_disk_size=100," <<
             "one_hypervisor=#{hypervisor}"

    before(:all) do
        @info = {}
    end

    it_behaves_like 'provision_hci', hypervisor, type, provider_path, inputs

    it_behaves_like 'aws_tf_hci'

    it_behaves_like 'cleanup'
end
