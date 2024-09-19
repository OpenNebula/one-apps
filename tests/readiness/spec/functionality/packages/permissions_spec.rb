require 'init_functionality'

describe 'Ownership and Permissions' do
    # NOTE: We can't test all, since functionality tests have customized
    # permissions on /etc to allow modifications under oneadmin user.
    {
        '/var/lib/one'                 => { 'uid' => 9869, 'gid' => 9869, 'mode' => 0o40750 },
        '/var/lib/one/backups'         => { 'uid' => 9869, 'gid' => 9869, 'mode' => 0o40700 },
        '/var/lib/one/backups/config'  => { 'uid' => 0,    'gid' => 0,    'mode' => 0o40700 },
        '/var/lib/one/datastores'      => { 'uid' => 9869, 'gid' => 9869, 'mode' => 0o40750 },
        '/var/lib/one/remotes'         => { 'uid' => 9869, 'gid' => 9869, 'mode' => 0o40750 },
        '/var/log/one'                 => { 'uid' => 9869, 'gid' => 9869, 'mode' => 0o40750 },
        '/run/one'                     => { 'uid' => 9869, 'gid' => 9869, 'mode' => 0o40750 }
    }.each do |name, attr|
        it "is correct on #{name}" do
            stat = File.stat(name)

            attr.each do |attr_name, attr_value|
                stat_value = stat.send(attr_name)

                expect(stat_value).to eq(attr_value),
                                      "Expected #{attr_name} with " \
                                      "#{attr_value}, but found #{stat_value}"
            end
        end
    end
end
