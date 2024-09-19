#-------------------------------------------------------------------------------
# Defines test configuration and start OpenNebula
#-------------------------------------------------------------------------------

require 'init_functionality'
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

RSpec.describe 'Datastore operations test' do
    #---------------------------------------------------------------------------
    # OpenNebula bootstraping:
    #   - Define infrastructure: hosts, datastore, users, networks,...
    #   - Common instance variables: templates,...
    #---------------------------------------------------------------------------
    before(:all) do
        @cluster_name = 'test_cluster'
        @cluster_id = cli_create("onecluster create #{@cluster_name}")
    end

    before(:each) do
        @cleanup_ds = []
    end

    after(:each) do
        @cleanup_ds.each do |id|
            cli_action("onedatastore delete #{id}")
        end
    end

    #---------------------------------------------------------------------------
    # TESTS
    #---------------------------------------------------------------------------

    #   * list
    #        Lists Datastores in the pool
    #        valid options: list, delay, xml, numeric
    #   * show <datastoreid>
    #        Shows information for the given Datastore
    #        valid options: xml

    it 'should check that two Datastores are created by default' do
        output = cli_action('onedatastore list').stdout
        expect(output).to match(/0 system/)
        expect(output).to match(/1 default/)
        expect(output).to match(/2 files/)

        cli_action('onedatastore show 0')
        cli_action('onedatastore show system -x')

        cli_action('onedatastore show 1 -x')
        cli_action('onedatastore show default')

        cli_action('onedatastore show 2 -x')
        cli_action('onedatastore show files')
    end

    #   * create <file>
    #        Creates a new Datastore from the given template file
    #        valid options: cluster

    it 'should create a new Datastore without Cluster' do
        id = cli_create('onedatastore create', "NAME = new_ds\nTM_MAD=dummy\nDS_MAD=dummy")
        expect(id).to be >= 100

        expect(cli_action('onedatastore list').stdout).to match(/#{id} new_ds/)

        cli_action("onedatastore show #{id}")
        cli_action('onedatastore show new_ds -x')

        @cleanup_ds << id
    end

    it 'should create a new Datastore of type FILE_DS using stdin template' do
        cmd = 'onedatastore create'

        template = <<~EOT
            NAME = file_ds
            TYPE=FILE_DS
            TM_MAD=dummy
            DS_MAD=dummy
        EOT

        stdin_cmd = <<~BASH
            #{cmd} <<EOF
            #{template}
            EOF
        BASH

        id = cli_create(stdin_cmd)

        expect(id).to be >= 100

        expect(cli_action('onedatastore list').stdout).to match(/#{id} file_ds/)

        cli_action("onedatastore show #{id}")
        ds_xml = cli_action_xml('onedatastore show file_ds -x')

        expect(ds_xml['TYPE']).to eql '2'

        @cleanup_ds << id
    end

    it 'should create a new Datastore in an existing Cluster, numeric id' do
        id = cli_create("onedatastore create -c #{@cluster_id}",
                        "NAME = new_ds\nTM_MAD=dummy\nDS_MAD=dummy")
        @cleanup_ds << id
    end

    it 'should create a new Datastore in an existing Cluster, by name' do
        id = cli_create("onedatastore create -c #{@cluster_name}",
                        "NAME = new_ds\nTM_MAD=dummy\nDS_MAD=dummy")
        @cleanup_ds << id
    end

    it 'should try to create a new Datastore in an invalid Cluster and check the failure, numeric id' do
        output = cli_create("onedatastore create -c #{@cluster_id + 50}",
                            "NAME = new_ds\nTM_MAD=dummy\nDS_MAD=dummy", false).stderr
        expect(output).to match(/Error getting cluster/)
    end

    it 'should try to create a new Datastore in an invalid Cluster and check the failure, by name' do
        output = cli_create('onedatastore create -c non-existent',
                            "NAME = new_ds\nTM_MAD=dummy\nDS_MAD=dummy", false).stderr
        expect(output).to match(/CLUSTER named non-existent not found/)
    end

    it 'should try to create an incomplete Datastore and check the failure' do
        ds_template = {
            :name   => 'new_ds',
          :tm_mad => 'ssh'
        }

        output = cli_create('onedatastore create',
                            "NAME = new_ds\nTM_MAD=dummy", false).stderr
        expect(output).to match(/No DS_MAD in template/)
    end

    it 'should try to create an existing Datastore and check the failure' do
        id = cli_create('onedatastore create', "NAME = new_ds\nTM_MAD=dummy\nDS_MAD=dummy")

        output = cli_create('onedatastore create',
                            "NAME = new_ds\nTM_MAD=dummy\nDS_MAD=dummy", false).stderr
        expect(output).to match(/NAME is already taken/)

        @cleanup_ds << id
    end

    #   * delete <range|datastoreid_list>
    #        Deletes the given Datastore

    it 'should delete an existing Datastore, numeric id' do
        id = cli_create('onedatastore create', "NAME = new_ds\nTM_MAD=dummy\nDS_MAD=dummy")

        cli_action("onedatastore delete #{id}")
    end

    it 'should delete an existing Datastore, by name' do
        id = cli_create('onedatastore create', "NAME = new_ds\nTM_MAD=dummy\nDS_MAD=dummy")

        cli_action('onedatastore delete new_ds')
    end

    it 'should try to delete a non-existent Datastore and check the failure, numeric id' do
        output = cli_action('onedatastore delete 12345', false).stderr
        expect(output).to match(/Error getting datastore/)
    end

    it 'should try to delete a non-existent Datastore and check the failure, by name' do
        output = cli_action('onedatastore delete non-existent', false).stderr
        expect(output).to match(/DATASTORE named .* not found/)
    end

    it 'should try to delete a non empty Datastore and check the failure' do
        id = cli_create('onedatastore create', "NAME = new_ds\nTM_MAD=dummy\nDS_MAD=dummy")

        wait_loop do
            xml = cli_action_xml("onedatastore show -x #{id}")
            xml['FREE_MB'].to_i > 0
        end

        img_id = cli_create("oneimage create --name new_image --size 100 --type datablock -d #{id}")

        output = cli_action("onedatastore delete #{id}", false).stderr
        expect(output).to match(/is not empty/)

        cli_action("oneimage delete #{img_id}")

        @cleanup_ds << id
    end

    # NOT TESTED COMMANDS
    #
    #    * chmod <range|datastoreid_list> <octet>
    #         Changes the Datastore permissions
    #
    #    * chown <range|datastoreid_list> <userid> [<groupid>]
    #         Changes the Datastore owner and group
    #
    #    * chgrp <range|datastoreid_list> <groupid>
    #         Changes the Datastore group
    #
    #    * update <datastoreid>
    #         Launches the system editor to modify and update the template contents
end
