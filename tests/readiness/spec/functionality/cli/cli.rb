require 'init_functionality'
require 'yaml'

#-------------------------------------------------------------------------------
# Checks output of CLI commands
#-------------------------------------------------------------------------------

RSpec.describe 'CLI outputs' do
    before(:all) do
        @h1      = cli_create('onehost create 1 -i dummy -v dummy')
        @h2      = cli_create('onehost create 2 -i dummy -v dummy')
        @default = YAML.load_file('/etc/one/cli/onehost.yaml')[:default].size
    end

    # ID NAME            CLUSTER    TVM      ALLOCATED_CPU      ALLOCATED_MEM STAT
    #  1 2               default      0       0 / 800 (0%)      0K / 16G (0%) on
    #  0 1               default      0       0 / 800 (0%)      0K / 16G (0%) on
    it 'should check normal output' do
        output = SafeExec.run('onehost list').stdout

        expect(output.split("\n").size).to eq(3)
        expect(output.split("\n")[0].split.size).to eq(@default)
    end

    # 1 2               default      0       0 / 800 (0%)      0K / 16G (0%) on
    # 0 1               default      0       0 / 800 (0%)      0K / 16G (0%) on
    it 'should check normal output without header' do
        output = SafeExec.run('onehost list --no-header').stdout

        expect(output.split("\n").size).to eq(2)
    end

    # ID,NAME,CLUSTER,TVM,ALLOCATED_CPU,ALLOCATED_MEM,STAT
    # 1,2,default,0,0 / 800 (0%),0K / 16G (0%),on
    # 0,1,default,0,0 / 800 (0%),0K / 16G (0%),on
    it 'should check CSV output' do
        output = SafeExec.run('onehost list --csv').stdout

        expect(output.split("\n").size).to eq(3)
        expect(output.split("\n")[1].split(',').size).to eq(@default)
    end

    # 1,2,default,0,0 / 800 (0%),0K / 16G (0%),on
    # 0,1,default,0,0 / 800 (0%),0K / 16G (0%),on
    it 'should check CSV output without header' do
        output = SafeExec.run('onehost list --csv --no-header').stdout

        expect(output.split("\n").size).to eq(2)
        expect(output.split("\n")[0].split(',').size).to eq(@default)
    end

    # ID
    #  1
    #  0
    it 'should check list option with normal output' do
        output = SafeExec.run('onehost list --list ID').stdout

        expect(output.split("\n").size).to eq(3)
        expect(output.split("\n")[0].split.size).to eq(1)
    end

    #  1
    #  0
    it 'should check list option with normal output without header' do
        output = SafeExec.run('onehost list --list ID --no-header').stdout

        expect(output.split("\n").size).to eq(2)
        expect(output.split("\n")[0].split.size).to eq(1)
    end

    # ID,NAME
    # 1,2
    # 0,1
    it 'should check list option with CSV output' do
        output = SafeExec.run('onehost list --csv --list ID,NAME').stdout

        expect(output.split("\n").size).to eq(3)
        expect(output.split("\n")[1].split(',').size).to eq(2)
    end

    # ID,NAME
    # 1,2
    # 0,1
    it 'should check list option with CSV output without header' do
        output = SafeExec.run(
            'onehost list --csv --list ID,NAME --no-header'
        ).stdout

        expect(output.split("\n").size).to eq(2)
        expect(output.split("\n")[0].split(',').size).to eq(2)
    end

    # ID NAME            CLUSTER    TVM      ALLOCATED_CPU      ALLOCATED_MEM STAT
    #  1 2               default      0       0 / 800 (0%)      0K / 16G (0%) on
    it 'should check filter option with normal output' do
        output = SafeExec.run("onehost list --filter ID!=#{@h1}").stdout

        expect(output.split("\n").size).to eq(2)
    end

    # ID,NAME,CLUSTER,TVM,ALLOCATED_CPU,ALLOCATED_MEM,STAT
    # 1,2,default,0,0 / 800 (0%),0K / 16G (0%),on
    it 'should check filter option with CSV output' do
        output = SafeExec.run("onehost list --csv --filter ID!=#{@h1}").stdout

        expect(output.split("\n").size).to eq(2)
        expect(output.split("\n")[1].split(',').size).to eq(@default)
    end

    # NAME
    # 2
    it 'should check filter by hidden column with normal output' do
        output = SafeExec.run(
            "onehost list --list NAME --filter ID!=#{@h1}"
        ).stdout

        expect(output.split("\n").size).to eq(2)
        expect(output.split("\n")[1].split.size).to eq(1)
    end

    # NAME
    # 2
    it 'should check filter by hidden column with CSV output' do
        output = SafeExec.run(
            "onehost list --csv --list NAME --filter ID!=#{@h1}"
        ).stdout

        expect(output.split("\n").size).to eq(2)
        expect(output.split("\n")[1].split(',').size).to eq(1)
    end
end
