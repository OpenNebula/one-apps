require 'init_functionality'
require 'yaml'

RSpec.describe 'Template syntax' do
    before(:all) do
        provider_path = '/usr/share/one/oneprovision/edge-clusters/' \
                        'onprem/providers/onprem/onprem.yml'

        cli_action("oneprovider create #{provider_path}")

        @info = {}
    end

    DIR = 'spec/provision/template_syntax/templates'

    it 'should validate the template' do
        cli_action("oneprovision validate #{DIR}/0.yaml")
    end

    it 'should validate the template with index' do
        cli_action("oneprovision validate #{DIR}/1.yaml")
    end

    it 'should fail validate due to non-existing key' do
        cli_action("oneprovision validate #{DIR}/2.yaml", false)
    end

    it 'should fail validate due to non-existing object' do
        cli_action("oneprovision validate #{DIR}/3.yaml", false)
    end

    it 'should fail validate due to invalid character' do
        cli_action("oneprovision validate #{DIR}/4.yaml", false)
    end

    it 'should evaluate template' do
        @info[:id] = cli_create(
            "oneprovision create #{DIR}/0.yaml " \
            '--skip-provision --batch --fail-cleanup'
        )

        pr = cli_action_json("oneprovision show #{@info[:id]} -j")
        pr = pr['DOCUMENT']['TEMPLATE']['BODY']['provision']

        host = pr['infrastructure']['hosts'][0]['id']
        host = cli_action_xml("onehost show #{host} -x")

        expect(host['//HOSTNAME']).to match(/Dummy-/)

        vnet = pr['infrastructure']['networks'][0]['id']
        vnet = cli_action_xml("onevnet show #{vnet} -x")

        expect(vnet['//VAR']).to eq('100-AAAA-100')
    end

    it 'should delete provision' do
        cli_action("oneprovision delete #{@info[:id]}")
    end

    it 'should evaluate auto index template' do
        @info[:id] = cli_create(
            "oneprovision create #{DIR}/1.yaml " \
            '--skip-provision --batch --fail-cleanup'
        )
        pr = cli_action_json("oneprovision show #{@info[:id]} -j")
        pr = pr['DOCUMENT']['TEMPLATE']['BODY']['provision']

        pr['infrastructure']['hosts'].each_with_index do |host, idx|
            host = cli_action_xml("onehost show #{host['id']} -x")
            expect(host['//HOSTNAME']).to eq("host-#{idx}")
        end
    end

    it 'should delete provision' do
        cli_action("oneprovision delete #{@info[:id]}")
    end
end
