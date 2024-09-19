require 'init_functionality'

RSpec.describe 'Provider' do
    before(:all) do
        tmpl      = 'spec/provision/provider/provider.yaml'
        @provider = cli_create("oneprovider create #{tmpl}")
    end

    it 'check provider information' do
        json = cli_action_json("oneprovider show #{@provider} -j")
        json = json['DOCUMENT']['TEMPLATE']['PROVISION_BODY']

        expect(json['provider']).to eq('equinix')
        expect(json['connection']['token']).to eq('fake_token')
        expect(json['connection']['project']).to eq('fake_project')
        expect(json['connection']['facility']).to eq('ams1')
        expect(json['connection']['plan']).to eq('baremetal_0')
        expect(json['connection']['os']).to eq('centos_7')
    end

    it 'list providers' do
        csv = cli_action('oneprovider list --csv --no-header').stdout
        csv = csv.split(',')

        expect(csv.size).to eq(3)
        expect(csv[0].to_s).to eq(@provider.to_s)
        expect(csv[1]).to eq('equinix')
    end

    it 'update provider' do
        update_file = 'spec/provision/provider/update.json'
        cli_action("oneprovider update #{@provider} #{update_file}")

        json = cli_action_json("oneprovider show #{@provider} -j")
        json = json['DOCUMENT']['TEMPLATE']['PROVISION_BODY']

        expect(json['provider']).to eq('equinix')
        expect(json['connection']['token']).to eq('new_fake_token')
        expect(json['connection']['project']).to eq('fake_project')
        expect(json['connection']['facility']).to eq('ams1')
        expect(json['connection']['plan']).to eq('baremetal_0')
        expect(json['connection']['os']).to eq('centos_8')
    end

    it 'chgrp' do
        cli_action("oneprovider chgrp #{@provider} users")

        json = cli_action_json("oneprovider show #{@provider} -j")

        expect(json['DOCUMENT']['GNAME']).to eq('users')
    end

    it 'chown' do
        cli_action("oneprovider chown #{@provider} serveradmin")

        json = cli_action_json("oneprovider show #{@provider} -j")

        expect(json['DOCUMENT']['UNAME']).to eq('serveradmin')
    end

    it 'chmod' do
        cli_action("oneprovider chmod #{@provider} 777")

        json = cli_action_json("oneprovider show #{@provider} -j")

        expect(json['DOCUMENT']['PERMISSIONS']['OWNER_U']).to eq('1')
        expect(json['DOCUMENT']['PERMISSIONS']['OWNER_M']).to eq('1')
        expect(json['DOCUMENT']['PERMISSIONS']['OWNER_A']).to eq('1')
        expect(json['DOCUMENT']['PERMISSIONS']['GROUP_U']).to eq('1')
        expect(json['DOCUMENT']['PERMISSIONS']['GROUP_U']).to eq('1')
        expect(json['DOCUMENT']['PERMISSIONS']['GROUP_U']).to eq('1')
        expect(json['DOCUMENT']['PERMISSIONS']['OTHER_U']).to eq('1')
        expect(json['DOCUMENT']['PERMISSIONS']['OTHER_U']).to eq('1')
        expect(json['DOCUMENT']['PERMISSIONS']['OTHER_U']).to eq('1')
    end

    it 'delete provider' do
        cli_action("oneprovider delete #{@provider}")
        cli_action("oneprovider show #{@provider}", false)
    end
end
