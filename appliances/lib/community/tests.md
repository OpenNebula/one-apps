# Certification tests

The appliance contribution relies on the one-apps framework. That is, you provide some packer scripts that build a an appliance with certain functionality. When contributing an appliance, you must provide two separate logics and verify the two processes for each of them work as intended.

The contribution is composed by two requirements

1. The first one is to provide the code that generates your appliance using the one-apps framework. The process is described in detail on the [one-apps wiki dev section](https://github.com/OpenNebula/one-apps/wiki/tool_dev#creating-a-new-appliance). You can take a look also at [a webinar](https://www.youtube.com/watch?v=UstX_KyOi0k) that showcases this process in detail.
2. The second one is to provide a set of tests that verify the functionality provided by your appliance.
   1. These tests are also code that must be provided by you together with the appliance logic.
   2. Besides this, the appliance must comply with our internal test suite that verifies the Virtual Machine image works properly with the contextualization packages. You do not need to write tests for this, just some metadata describing the base OS used for the image.

## How to create your own tests

The tests are built around [rspec](https://rspec.info/). You describe certain tests, called examples, and define conditions where the test fails or succeeds based on expectations. The tests are assumed to be executed in the OpenNebula frontend. This means the `opennebula` systemd unit runs in the same host where the tests are executed.

We are going to showcase the contribution process with database appliance showcased on the [one-apps webinar](https://www.youtube.com/watch?v=UstX_KyOi0k)

### App structure

The application logic resides at `./appliances/<appliance>`. Within that directory resides also the appliance metadata and the `tests` directory.

For example

```
appliances/example/
├── appliance.sh # appliance logic
├── context.yaml # generated after the tests are executed based on metadata
├── metadata.yaml # appliance metadata used in testing
├── tests
│   └── 00-example_basic.rb
└── tests.yaml # list of test files to be executed
```

The file `00-example_basic.rb` contains some tests that verify the mysql database within the Virtual Machine.

### Example tests

The appliance provides the following custom contextualization parameters

```bash
ONEAPP_DB_NAME # Database name
ONEAPP_DB_USER # Database service user
ONEAPP_DB_PASSWORD # Database service password
ONEAPP_DB_ROOT_PASSWORD # Database password for root
```

The tests basically verify that using these parameters is working as intended.

In this case 6 tests are performed using rspec `it` blocks:
- mysql is installed.
  - This verifies that the app built correctly with the required software
  - The app could have successfully built, but failed to perform some install tasks
- mysql is running
- one-apps service framework reports the app as ready
  - every time the the VM containing the app starts, the service within, in this case mysql, will be reconfigured according to what is stated in the CONTEXT section.
  - one-apps will trigger the configuration and if everything goes well, it will report ready

To run the tests, `cd` into the directory `./appliances/lib/community` and then execute `./app_readiness.rb <app_name>`.

Using this example

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
  check one-apps motd
  can connect as root with defined password
  database exists
  can connect as user with defined password

Finished in 1 minute 10.07 seconds (files took 0.20889 seconds to load)
6 examples, 0 failures

```

Only the tests defined at `tests.yaml` will be executed. With this you can define multiple test files to verify independent workflows and also test them separately.

```yaml
---
- '00-example_basic.rb'
```

### Creating rspec example groups from scratch

In order to develop your test, you will need to create your example group(s).

Taking a look at the file `00-example_basic.rb` we have the group `Appliance Certification` with 6 examples. Each example is an `it` block. Within the blocks there is some regular code and some code that *checks expectations*. An example of this special code is

```ruby
expect(execution.exitstatus).to eq(0)
expect(execution.stdout).to include('All set and ready to serve')
```

The test in this case succeeds provided that a command runs without errors and its output contains a string. Both are required to pass the test.


Here is an example that does nothing useful, yet still runs

```ruby
# /tmp/asdf.rb file
describe 'Useless test' do
    it 'Checks running state' do
        running = true
        expect(running).to be(true)
    end

    it 'Checks state' do
        status = 'running'
        expect(status).to eql('amazing') # will fail
    end
end
```

If you run this with `rspec -f d /tmp/asdf.rb`, you'll get

```
Useless test
  Checks running state
  Checks state (FAILED - 1)

Failures:

  1) Useless test Checks state
     Failure/Error: expect(status).to eql('amazing')

       expected: "amazing"
            got: "running"

       (compared using eql?)
     # /tmp/asdf.rb:9:in `block (2 levels) in <top (required)>'

Finished in 0.01369 seconds (files took 0.09474 seconds to load)
2 examples, 1 failure

Failed examples:

rspec /tmp/asdf.rb:7 # Useless test Checks state
```

Now you need to make your tests useful. For this we provide some libraries to aid you. If you notice, in the mysql test file there are some calls that reference remote command execution in VMs. However we never create a VM in this code. This file uses the `app_handler.rb` library, which takes care of this. You can use this library to abstract from the complexity of creating and destroying a VM with custom context parameters.

To use it you need to do the following on the rspec file at `appliances/<appliance>/tests/<rspec_file>.rb`

- load the library with `require_relative ../../lib/community/app_handler`
- load the library example group within your example group with `include_context('vm_handler')`

Once you do that, the VM instance will be stored in the variable `@info[:vm]`. You can execute commands in there with `ssh` instance method. The execution will return as an object where you can inspect parameters like the `existstaus, stderr and stdout`.

For an in-depth look at what you can do with the VM, please take a look at the file `appliances/lib/community/clitester/VM.rb`. This class abstracts lots of operations performed to a VM via CLI.

Now these tests assume certain conditions on the host running OpenNebula.
- a virtual network where the test VMs will run
- a VM Template with
  - this virtual network
  - no disk. The disk will be passed dynamically as your app is built
  - `SSH_PUBLIC_KEY="$USER[SSH_PUBLIC_KEY]"`
- The tests are expected to run as the oneadmin user
- The oneadmin user must be able reach these VMs. You have to set the SSH_PUBLIC_KEY on the user template

You can use [one-deploy](https://github.com/OpenNebula/one-deploy) to quickly create a compatible test scenario. A simple node containing both the frontend and a kvm node will do. An inventory file is provided as a reference at `appliances/lib/community/ansible/inventory.yaml`

Lastly you have to define a `metadata.yaml` file. This describes the appliance, showcasing information like the CONTEXT Params used to control the App and the Linux distro used.

```yaml
---
:app:
  :name: service_example # name used to make the app with the makefile
  :type: service # there are service (complex apps) and distro (base apps)
  :os:
    :type: linux # linux, freebsd or windows
    :base: alma8 # distro where the app runs on
  :hypervisor: KVM
  :context: # which context params are used to control the app
    :prefixed: true # params are prefixed with ONEAPP_ on the appliance logic ex. ONEAPP_DB_NAME
    :params:
      :DB_NAME: 'dbname'
      :DB_USER: 'username'
      :DB_PASSWORD: 'upass'
      :DB_ROOT_PASSWORD: 'arpass'

:one:
  :datastore_name: default # target datatore to import the one-apps produced image
  :timeout: '90' # timeout for XMLRPC calls

:infra:
  :disk_format: qcow2 # one-apps built image disk format
  :apps_path: /opt/one-apps/export # directory where one-apps exports the appliances to

```

After executing the tests, the `context.yaml` file is generated. This file should be included in the Pull Request as well. We will use it to pass the `context` tests in our infrastructure.
