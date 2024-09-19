#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe "Rename VirtualMachine test" do

  before(:each) do
    tmpl = <<-EOF
    NAME = test_name
    CPU  = 1
    MEMORY = 128
    EOF

    @vm_id = cli_create("onevm create", tmpl)
  end

  after(:each) do
    cli_action("onevm recover --delete #{@vm_id}")
  end

  #---------------------------------------------------------------------------
  # TESTS
  #---------------------------------------------------------------------------

  it "should rename a VirtualMachine and check the list and show commands" do
    expect(cli_action("onevm list").stdout).to match(/test_name/)
    expect(cli_action("onevm show test_name").stdout).to match(/NAME *: *test_name/)

    cli_action("onevm rename test_name new_name")

    expect(cli_action("onevm list").stdout).not_to match(/test_name/)
    cli_action("onevm show test_name", false)

    expect(cli_action("onevm list").stdout).to match(/new_name/)
    expect(cli_action("onevm show new_name").stdout).to match(/NAME *: *new_name/)
  end

  it "should rename a VirtualMachine, restart opennebula and check its name" do
    expect(cli_action("onevm list").stdout).to match(/test_name/)
    expect(cli_action("onevm show test_name").stdout).to match(/NAME *: *test_name/)

    cli_action("onevm rename test_name new_name")

    @one_test.stop_one
    @one_test.start_one

    expect(cli_action("onevm list").stdout).not_to match(/test_name/)
    cli_action("onevm show test_name", false)

    expect(cli_action("onevm list").stdout).to match(/new_name/)
    expect(cli_action("onevm show new_name").stdout).to match(/NAME *: *new_name/)
  end

  it "should rename a VirtualMachine to an existing name" do
    tmpl = <<-EOF
      NAME = foo
      CPU  = 1
      MEMORY = 128
    EOF
    id = cli_create("onevm create", tmpl)

    cli_action("onevm rename test_name foo")

    expect(cli_action("onevm list").stdout).to match(/foo/)
    expect(cli_action("onevm list").stdout).not_to match(/test_name/)
    cli_action("onevm show test_name", false)

    cli_action("onevm recover --delete #{id}")
  end

  it "should rename a VirtualMachine to an existing name, but with different capitalization" do
    tmpl = <<-EOF
      NAME = foo
      CPU  = 1
      MEMORY = 128
    EOF
    cli_create("onevm create", tmpl)

    cli_action("onevm rename foo TEST_name")

    expect(cli_action("onevm list").stdout).to match(/test_name/)
    expect(cli_action("onevm list").stdout).to match(/TEST_name/)
    expect(cli_action("onevm show test_name").stdout).to match(/NAME *: *test_name/)
    expect(cli_action("onevm show TEST_name").stdout).to match(/NAME *: *TEST_name/)

    cli_action("onevm recover --delete TEST_name")
  end

  it "should rename a VirtualMachine to an existing name but with different owner" do
    cli_action("oneuser create a a")

    tmpl = <<-EOF
      NAME = foo
      CPU  = 1
      MEMORY = 128
    EOF
    id = cli_create("onevm create", tmpl)

    cli_action("onevm chown foo a users")

    cli_action("onevm rename test_name foo")

    expect(cli_action("onevm list").stdout).to match(/foo/)
    expect(cli_action("onevm list").stdout).not_to match(/test_name/)
    cli_action("onevm show test_name", false)

    cli_action("onevm recover --delete #{id}")
  end

end