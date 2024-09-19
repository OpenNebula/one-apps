require 'init_functionality'

def play_tasks(tasks, expect_success = true)
    playbook = <<-END.gsub(/^\s+\|/, '')
        |---
        |- hosts: "#{Socket.gethostname}"
        |  tasks:
    END

    if tasks.is_a? Array
        playbook <<  tasks.join("\n")
    else
        playbook <<  tasks
    end

    tempfile = Tempfile.new('playbook')
    tempfile.puts(playbook)
    tempfile.close


    cmd = "ansible-playbook -i #{Socket.gethostname}, #{tempfile.path}"

    cmd = SafeExec.run(cmd)

    fail cmd.stdout + "\n" + cmd.stderr if expect_success && cmd.fail?

    cmd
end

describe "Test with system ansible" do

    prepend_before(:all) do
        @defaults_yaml=File.join(File.dirname(__FILE__),'defaults.yaml')
    end

    before(:all) do
        @info = {}

        mads = "TM_MAD=dummy\nDS_MAD=dummy"
        cli_update('onedatastore update system', mads, false)
        cli_update('onedatastore update default', mads, false)

        # sys DS somehow remains unmonitored
        SafeExec.run('onedb change-body datastore --id 0 /DATASTORE/FREE_MB 10000')
        SafeExec.run('onedb change-body datastore --id 0 /DATASTORE/TOTAL_MB 10000')
    end

    it "Ensure ansible is installed" do

        cmd = SafeExec.run("ansible --version | head -1")
        cmd.expect_success

        puts "Running #{cmd.stdout}"
    end

    it 'Create hosts' do
        task = <<-END.gsub(/^\s+\|/, '')
               |  - one_host:
               |      name: "#{Socket.gethostname}"
               |      vmm_mad_name: "dummy"
               |      im_mad_name : "dummy"
        END
        play_tasks(task, false)
    end

    it 'Creates Image' do
        wait_loop do
            ds_size = SafeExec.run(
                'onedatastore show 1 --json | jq -r ".DATASTORE.FREE_MB"'
            ).stdout.strip

            ds_size.match(/^(\d)+$/) && ds_size.to_i > 5000
        end

        template = <<-EOF
            NAME   = testimage
            TYPE   = OS
            SOURCE = /this/is/a/path
            FORMAT = qcow2
            SIZE   = 2048
        EOF

        img_id = cli_create('oneimage create -d default', template)

        template = <<-EOF
            NAME   = "alpine"
            CONTEXT= [ NETWORK="YES" ]
            CPU    = "1"
            DISK   = [ IMAGE_ID="#{img_id}" ]
            MEMORY = "128"
            OS     = [ ARCH="x86_64" ]
        EOF

        cli_create('onetemplate create', template)
    end

    it 'Deploys' do
        task = <<-END.gsub(/^\s+\|/, '')
               |  - one_vm:
               |      template_name: alpine
               |      vcpu: 1
               |    register: result
               |  - debug:
               |      msg: "{{ result }}"
        END

        cmd = play_tasks(task)
        cmd.expect_success

        fail "Can not parse VM id in the string \"#{cmd.stdout}\"" \
            unless cmd.stdout.match(
                /instances_ids":\s*\[\s*\n\s*([0-9]*).*/m
            )

        @info[:vm_id] = Regexp.last_match(1)
        @info[:vm] = VM.new(@info[:vm_id])
        @info[:vm].running?
    end

    it 'PowerOff' do
        skip 'Deploy success required' unless @info[:vm]

        task = <<-END.gsub(/^\s+\|/, '')
               |  - one_vm:
               |      instance_ids:
               |      - #{@info[:vm_id]}
               |      state: poweredoff
               |      hard: yes
        END

        play_tasks(task)
        @info[:vm].state?('POWEROFF')
    end

    it 'Resume' do
        skip 'Deploy success required' unless @info[:vm]

        task = <<-END.gsub(/^\s+\|/, '')
               |  - one_vm:
               |      instance_ids:
               |      - #{@info[:vm_id]}
               |      state: running
        END

        play_tasks(task)
        @info[:vm].running?
    end

    it 'Terminates' do
        skip 'Deploy success required' unless @info[:vm]

        task = <<-END.gsub(/^\s+\|/, '')
               |  - one_vm:
               |      instance_ids:
               |      - #{@info[:vm_id]}
               |      state: absent
               |      hard: yes
        END

        play_tasks(task)
        @info[:vm].state?('DONE')
    end
end
