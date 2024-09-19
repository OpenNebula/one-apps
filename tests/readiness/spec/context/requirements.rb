shared_examples_for 'requirements' do

    it 'dnsmasq is running' do
        unless system('sudo systemctl is-active --quiet dnsmasq')
            STDERR.puts('dnmasq was not runnin, starting')
            system('sudo systemctl start dnsmasq')
        end

        expect(
            system('sudo systemctl is-active --quiet dnsmasq')
        ).to be(true)
    end

end
