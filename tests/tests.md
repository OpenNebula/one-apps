# Certification tests

In order to certify your appliances. Two steps are required

1. The first one is to provide the code that generates your appliance using the one-apps framework. The process is described in detail on the [oneapps wiki dev section](https://github.com/OpenNebula/one-apps/wiki/tool_dev#creating-a-new-appliance). You can take a look also at [a webinar](https://www.youtube.com/watch?v=UstX_KyOi0k&t=1000s) that showcases this process in detail.
2. The second one is to execute a set of tests that verify the functionality provided by your appliance. These you will have to write your own, however there are some guidelines you need to follow. Our goal is to run these tests alongside our internal CI process that verify the offical marketplace appliances.

## How to create your own tests

The tests are built around [rspec](https://rspec.info/). You describe certain tests, called examples, and define conditions where the test fails or succeeds based on expectations. You can group these examples on groups so you can run them on multiple instances (like testing multiple apps). The tests are assumed to be executed in the OpenNebula frontend.

For example. The following code checks if dnsmasq (required to test DHCP) is running based on the expectation that the function call `system('sudo systemctl is-active --quiet dnsmasq')` will return `true`.

```ruby
require 'rspec'

describe 'Contextualization' do
    it 'dnsmasq is running' do
        unless system('sudo systemctl is-active --quiet dnsmasq')
            STDERR.puts('dnmasq was not runnin, starting')
            system('sudo systemctl start dnsmasq')
        end

        expect(system('sudo systemctl is-active --quiet dnsmasq')).to be(true)
    end
end
```

To run this thest then you execute `rspec -f d ./dnsmasq.rb` assuming `dnsmasq.rb` is the file with the previous content.

First you need to load the gems that opennebula installs

```bash
export GEM_PATH=/usr/share/one/gems/
export GEM_HOME=$GEM_PATH
export PATH=$PATH:$GEM_PATH/bin
```

Then you can run rspec

```
oneadmin@PC04:~$ rspec -f d dnsmasq.rb

Contextualization
  dnsmasq is running

Finished in 0.01662 seconds (files took 0.03817 seconds to load)
1 example, 0 failures

```

This is a very simple example. For a more comprehensive example, check the file `tutorial_tests.rb`. This file showcases how to interact with some of the libraries we provide that abstract the use of OpenNebula through CLI. For even more in-depth examples, please review the `./spec/` directory. It contains the source code of the examples we run. These require certain conditions to be met on the infrastructure, so most likely won't run. However, they showcase how we use rspec to certify our appliances. 
