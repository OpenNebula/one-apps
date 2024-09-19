require 'init_functionality'
require 'sunstone_test'
require 'sunstone/Template'

RSpec.describe "Sunstone vm template tab", :type => 'skip' do

    before(:all) do
        user = @client.one_auth.split(":")
        @auth = {
            :username => user[0],
            :password => user[1]
        }

        @host_id = cli_create("onehost create localhost --im dummy --vm dummy")

        @sunstone_test = SunstoneTest.new(@auth)
        @sunstone_test.login
        @template = Sunstone::Template.new(@sunstone_test)
    end

    before(:each) do
        sleep 1
    end

    after(:all) do
        @sunstone_test.sign_out
    end

    it "should create a template with topology NUMA" do
        template = {
            name: "temp_with_numa",
            mem: "2",
            cpu: "0.1",
            memory_cost: "1",
            cpu_cost: "2",
            disk_cost: "1",
            topology: {
                cores: "2",
                memory_access: "private",
                pin_policy: "THREAD",
                sockets: "2",
                threads: "2"
            }
        }
        if @template.navigate_create(template[:name])
            @template.add_general(template)
            @template.add_numa(template[:topology])
            @template.submit
        end

        @sunstone_test.wait_resource_create("template", template[:name])
        tmp_xml = cli_action_xml("onetemplate show -x '#{template[:name]}'") rescue nil

        expect(tmp_xml['TEMPLATE/TOPOLOGY/CORES']).to eql template[:topology][:cores]
        expect(tmp_xml['TEMPLATE/TOPOLOGY/MEMORY_ACCESS']).to eql template[:topology][:memory_access]
        expect(tmp_xml['TEMPLATE/TOPOLOGY/PIN_POLICY']).to eql template[:topology][:pin_policy]
        expect(tmp_xml['TEMPLATE/TOPOLOGY/SOCKETS']).to eql template[:topology][:sockets]
        expect(tmp_xml['TEMPLATE/TOPOLOGY/THREADS']).to eql template[:topology][:threads]
    end

    it "should create a template with topology NUMA and HUGEPAGE_SIZE" do
        template = {
            name: "temp_with_numa_and_hugepages_size",
            mem: "2",
            cpu: "0.1",
            memory_cost: "1",
            cpu_cost: "2",
            disk_cost: "1",
            topology: {
                cores: "2",
                memory_access: "private",
                pin_policy: "THREAD",
                sockets: "2",
                threads: "2",
                hugepage_size: "2"
            }
        }
        if @template.navigate_create(template[:name])
            @template.add_general(template)
            @template.add_numa(template[:topology])
            @template.submit
        end

        @sunstone_test.wait_resource_create("template", template[:name])
        tmp_xml = cli_action_xml("onetemplate show -x '#{template[:name]}'") rescue nil

        expect(tmp_xml['TEMPLATE/TOPOLOGY/CORES']).to eql template[:topology][:cores]
        expect(tmp_xml['TEMPLATE/TOPOLOGY/MEMORY_ACCESS']).to eql template[:topology][:memory_access]
        expect(tmp_xml['TEMPLATE/TOPOLOGY/PIN_POLICY']).to eql template[:topology][:pin_policy]
        expect(tmp_xml['TEMPLATE/TOPOLOGY/SOCKETS']).to eql template[:topology][:sockets]
        expect(tmp_xml['TEMPLATE/TOPOLOGY/THREADS']).to eql template[:topology][:threads]
        expect(tmp_xml['TEMPLATE/TOPOLOGY/HUGEPAGE_SIZE']).to eql template[:topology][:hugepage_size]
    end
end
