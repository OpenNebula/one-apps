RSpec.shared_examples_for 'cleanup' do

    before(:each) do
        # skip ~> not scheduled for today
        skip 'Previous examples skipped' if $continue == 'skip'
    end


    it 'delete provision with cleanup' do
        skip 'Previous required test failed' unless @info[:p_id]

        cli_action_timeout(
            "oneprovision delete #{@info[:p_id]} -D --cleanup --force",
            true,
            1200
        )
    end

    it 'count clusters' do
        expect(count_elements('cluster')).to eq(0)
    end

    it 'count datastores' do
        expect(count_elements('datastore')).to eq(0)
    end

    it 'count hosts' do
        expect(count_elements('host')).to eq(0)
    end

    it 'count vnets' do
        expect(count_elements('network')).to eq(0)
    end

    it 'list provisions' do
        expect(empty?).to eq(true)
    end

    it 'should delete resources on remote provider' do
        skip 'No needed' unless $provider

        connection = $provider['connection']

        case $provider['provider']
        when 'equinix'
            p = Equinix.new(connection['token'], connection['project'])
        when 'aws'
            p = AWS.new(connection['access_key'], connection['secret_key'])
        end

        p.delete_devices # don't stop here even if there were devices
        expect(p.delete_net).to eq(true)
    end
end
