require 'init_functionality'
require 'yaml'

RSpec.describe 'User inputs' do
    before(:all) do
        provider_path = '/usr/share/one/oneprovision/edge-clusters/' \
                        'onprem/providers/onprem/onprem.yml'

        cli_action("oneprovider create #{provider_path}")
    end

    it '[DEFAULT] should create provision using default values' do
        id = cli_create(
            'oneprovision create spec/provision/user_inputs/templates/0.yaml ' \
            '--skip-provision --batch --fail-cleanup'
        )

        pr = cli_action_json("oneprovision show #{id} -j")
        pr = pr['DOCUMENT']['TEMPLATE']['BODY']['provision']

        # Count user input
        expect(pr['infrastructure']['hosts'].size).to eq(2)

        # User inputs
        vnet = pr['infrastructure']['networks'][0]['id']
        vnet = cli_action_xml("onevnet show #{vnet} -x")

        expect(vnet['//TEMPLATE/T']).to eq('This is a text')
        expect(vnet['//TEMPLATE/B']).to eq('NO')
        expect(vnet['//TEMPLATE/P']).to eq('1234')
        expect(vnet['//TEMPLATE/L']).to eq('OPT 2')

        cli_action("oneprovision delete #{id}")
    end

    it '[CLI] should create provision using CLI values' do
        id = cli_create(
            'oneprovision create spec/provision/user_inputs/templates/0.yaml ' \
            '--user-inputs "text=test,bool=YES,password=5678,count=1,list=OPT 1" ' \
            '--skip-provision --batch --fail-cleanup'
        )

        pr = cli_action_json("oneprovision show #{id} -j")
        pr = pr['DOCUMENT']['TEMPLATE']['BODY']['provision']

        # Count user input
        expect(pr['infrastructure']['hosts'].size).to eq(1)

        # User inputs
        vnet = pr['infrastructure']['networks'][0]['id']
        vnet = cli_action_xml("onevnet show #{vnet} -x")

        expect(vnet['//TEMPLATE/T']).to eq('test')
        expect(vnet['//TEMPLATE/B']).to eq('YES')
        expect(vnet['//TEMPLATE/P']).to eq('5678')
        expect(vnet['//TEMPLATE/L']).to eq('OPT 1')

        cli_action("oneprovision delete #{id}")
    end

    it 'should fail as list does not have options' do
        cli_action(
            'oneprovision validate spec/provision/user_inputs/templates/1.yaml',
            false
        )
    end

    it 'should fail as range does not have max and min values' do
        cli_action(
            'oneprovision validate spec/provision/user_inputs/templates/2.yaml',
            false
        )
    end
end
