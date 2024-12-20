# Certification tests

In order to certify your appliances. Two steps are required

1. The first one is to provide the code that generates your appliance using the one-apps framework. The process is described in detail on the [oneapps wiki dev section](https://github.com/OpenNebula/one-apps/wiki/tool_dev#creating-a-new-appliance). You can take a look also at [a webinar](https://www.youtube.com/watch?v=UstX_KyOi0k&t=1000s) that showcases this process in detail.
2. The second one is to execute a set of tests that verify the functionality provided by your appliance. These you will have to write your own, however there are some guidelines you need to follow. Our goal is to run these tests alongside our internal CI process that verify the offical marketplace appliances.

## How to create your own tests

The tests are built around [rspec](https://rspec.info/). You describe certain tests, called examples, and define conditions where the test fails or succeeds based on expectations. The tests are assumed to be executed in the OpenNebula frontend.

### App structure

The application logic resides at `./appliances/<appliance>`. Within that directory, resides also the appliance metadata an the `tests` directory.

For example

```
appliances/example/
├── appliance.sh
├── context.yaml # is generated after the tests are executed
├── metadata.yaml
├── tests
│   └── 00-example_basic.rb
└── tests.yaml
```

The file `00-example_basic.rb` contains some tests that verify the mysql database app that was written previously with one-apps. In this case 6 tests are performed

- mysql is installed.
  - This verifies that the app built correctly with the required software
  - The app could have succesfully built, but failed to perform some install tasks
- mysql is running
- oneapps service framework reports the app as ready
  - every time the the VM containing the app starts, the service within, in this case mysql, will be reconfigured according to what is stated in the CONTEXT section.
  - oneapps will trigger the configuration and if everything goes well, it will report ready

### Example tests

To run the tests, cd into the directory `./appliances/lib/community` and then execute `./app_readiness.rb <app_name>`. Using this example

```
root@PC04:/opt/one-apps/appliances/lib/community# ./app_readiness.rb example
Appliance Certification
  mysql is installed
  mysql service is running
"\n" +
"    ___   _ __    ___\n" +
"   / _ \\ | '_ \\  / _ \\   OpenNebula Service Appliance\n" +
"  | (_) || | | ||  __/\n" +
"   \\___/ |_| |_| \\___|\n" +
"\n" +
" All set and ready to serve 8)\n" +
"\n"
  check oneapps motd
  can connect as root with defined password
  database exists
  can connect as user with defined password

Finished in 1 minute 10.07 seconds (files took 0.20889 seconds to load)
6 examples, 0 failures

```

Only the tests defined at `tests.yaml` will be executed. With this you can define multiple test files to verify independent workflows.

```yaml
---
- '00-example_basic.rb'
```

### Creating rspec example groups

In order to develop your test, you will need to create your example group. In this case, we have the group `Appliance Certification` with 6 examples. Each example is an `it` clause. Here is an example that does nothing useful, yet still runs

```ruby
describe 'Useless test' do
    it 'does nothing' do
        expect(true).to be(true)
    end

    it 'does nothing still' do
        expect(false).to be(false)
    end
end
```

If you run this with rspec, you'll get


```
Useless test
  does nothing
  does nothing still

Finished in 0.00065 seconds (files took 0.0396 seconds to load)
2 examples, 0 failures
```

Now you need to make your tests useful. For this we provide some libraries to aid you. If you notice, in the mysql test file there are some calls that reference remote command execution in VMs. However we never create a VM in this code. This file uses the `app_handler.rb` library, which takes care of this. You can use this library to abstract from the complexity of creating and destroying a VM.

To use it you need to do the following on the rspec file

- load the library with `require_relative ../../lib/community/app_handler`
- load the library example group within your example group with `include_context('vm_handler')`

Once you do that, the VM instance will be stored in the variable `@info[:vm]`. You can execute commands in there with `ssh` instance method. The execution will return as an object where you can inspect parameters like the `existstaus, stderr and stdout`. For an in-depth look at what you can do with the VM, please take a look at the file `CLITester/VM.rb` for a reference. This class abstract operations performed to a VM via CLI.

Now these test assume certain conditions on OpenNebula and the infrastructure.
- a virtual network where the VMs will run and frontend can reach. This is required to execute commands as the oneadmin user.
- a VM Template with
  - this virtual network
  - no disk. The disk will be passed dynamically as your app is built
  - `SSH_PUBLIC_KEY="$USER[SSH_PUBLIC_KEY]"` where the USER is the CLI user running the tests.

You can use [one-deploy](https://github.com/OpenNebula/one-deploy) to quickly create a compatible test scenario. A simple node containing both the frontend and a kvm node will do. An inventory file is provided as a reference at `appliances/lib/community/ansible/inventory.yaml`

Lastly you have to define a `metadata.yaml` file. This describes the Application, showcasing information like the CONTEXT Params used to control the App, the distro used and a reference to the base VM Template used to test the appliance.

Take a look at the files `metadata.yaml` and `00-example_basic.rb` on the `example` appliance for reference.
