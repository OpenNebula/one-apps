require 'base64'
require 'zlib'

def select_res(rs, type)
    rs.select {|r| r['type'] == type }
end

RSpec.shared_examples_for 'aws_tf_hci' do
    before(:each) do
        fail 'Previous required test failed'  if $continue == 'fail'
        skip 'Previous required test skipped' if $continue == 'skip'
    end

    it 'check TF resources size' do
        tf = @info[:provision]['DOCUMENT']['TEMPLATE']['BODY']['tf']['state']
        tf = Zlib::Inflate.inflate(Base64.decode64(tf))
        tf = JSON.parse(tf)

        vpc = select_res(tf['resources'], 'aws_vpc').first

        @info[:tf]  = tf
        @info[:vpc] = vpc['instances'][0]['attributes']['id']

        expect(tf['resources'].size).to eq(22)
    end

    it 'check TF hosts' do
        hosts = select_res(@info[:tf]['resources'], 'aws_instance')

        expect(hosts.size).to eq(3)
        expect(hosts[0]['name']).to start_with('device_')
        expect(hosts[1]['name']).to start_with('device_')
    end

    it 'check TF gateway' do
        gw = select_res(@info[:tf]['resources'], 'aws_internet_gateway').first
        expect(gw['name']).to start_with('device_')
        expect(gw['instances'][0]['attributes']['vpc_id']).to eq(@info[:vpc])
    end

    it 'check TF route' do
        route = select_res(@info[:tf]['resources'], 'aws_route').first
        expect(route['name']).to start_with('device_')
        expect(route['instances'][0]['attributes']['destination_cidr_block']).to eq('0.0.0.0/0')
    end

    it 'check TF subnet 1' do
        subnet = select_res(@info[:tf]['resources'], 'aws_subnet').first

        expect(subnet['name']).to start_with('device_')
        expect(subnet['instances'][0]['attributes']['cidr_block']).to eq('10.0.0.0/16')
        expect(subnet['instances'][0]['attributes']['vpc_id']).to eq(@info[:vpc])
    end

    it 'check TF subnet 2' do
        subnet = select_res(@info[:tf]['resources'], 'aws_subnet')[1]

        expect(subnet['name']).to start_with('device_')
        expect(subnet['name']).to end_with('_ceph')
        expect(subnet['instances'][0]['attributes']['cidr_block']).to eq('10.1.0.0/16')
        expect(subnet['instances'][0]['attributes']['vpc_id']).to eq(@info[:vpc])
    end

    it 'check TF VPC' do
        vpc = select_res(@info[:tf]['resources'], 'aws_vpc').first
        expect(vpc['name']).to start_with('device_')
        expect(vpc['instances'][0]['attributes']['cidr_block']).to eq('10.0.0.0/16')
    end
end
