require 'base64'
require 'init'
require 'DiskResize'
require 'net/http'
require 'uri'
require 'yaml'

include DiskResize

shared_examples_for 'context' do |image, hv, prefix, context = nil, image_size = nil, deploy = true|
    before(:all) do
        @defaults = RSpec.configuration.defaults

        # Used to pass info accross tests
        @info = {}
        @info[:image] = image
        @info[:prefix] = prefix
        @info[:context] = context
        @info[:datastore_name] = @defaults[:one][:datastore_name]
        @info[:template] = @defaults[:one][:template]
        @info[:network_attach] = @defaults[:one][:network_attach]
        @info[:hv] = hv

        # import image if missing
        if cli_action("oneimage show '#{@info[:image]}' >/dev/null", nil).fail?
            # test images from given URL or use default
            url = if ENV['IMAGES_URL']
                      ENV['IMAGES_URL']
                  else
                      @defaults[:infra][:apps_path]
                  end

            url = url.chomp('/') + '/' + @defaults[:tests][@info[:image]][:image_name]

            cmd = "oneimage create -d '#{@info[:datastore_name]}' --type OS " <<
                  "  --name '#{@info[:image]}' " <<
                  "  --path '#{url}'" <<
                  ' --format qcow2'

            cli_create(cmd)
        end

        if windows?
            timeout = 8*DEFAULT_TIMEOUT
        else
            timeout = 4*DEFAULT_TIMEOUT
        end

        wait_loop(:success => /^(READY|USED)$/, :break => 'ERROR', :timeout => timeout) do
            xml = cli_action_xml("oneimage show -x '#{@info[:image]}'")
            Image::IMAGE_STATES[xml['STATE'].to_i]
        end
    end

    if deploy
        after(:all) do
            schedule = (Time.now + 1200).strftime('%Y/%m/%d %H:%M')
            cli_action("onevm terminate --hard #{@info[:vm_id]} --schedule '#{schedule}'")
            cli_action("onevm terminate --hard #{@info[:vm_id]}")

            # Poll state on our own and issue another onevm terminate --hard
            # if the VM state is failed. Probably still leaves a lot of trail on hosts.
            wait_loop({ :success => 'DONE', :timeout => DEFAULT_TIMEOUT / 2 }) do
                s = @info[:vm].state

                if s =~ /FAIL|POWEROFF/
                    STDERR.puts "ERROR: Terminated VM state is #{s}. Retrying termination."

                    unless windows?
                        @info[:vm].ssh('poweroff')
                        sleep 15
                    end

                    cli_action("onevm terminate --hard #{@info[:vm_id]}", nil, true)
                    sleep 15
                    s = @info[:vm].state
                end

                s
            end
        end
    end

    # Fail-fast-begin: Fail all examples in given context if any of the
    # example containing `required` in the description fails
    before(:context) do
        # reset the stopper for every context
        $continue = true
    end

    before(:each) do |_example|
        raise StandardError, 'Deploy failed, dependency error' unless $continue
    end

    if deploy
        after(:each) do |example|
            $continue = false if example.exception && \
                 example.description.include?('required')
        end
    end
    # Fail-fast-end

    if deploy
        it 'deploys (required)' do
            # Clone template and append new content
            tmpl = "#{@info[:template]}_#{@info[:image]}_#{rand(36**8).to_s(36)}"
            @info[:tmpl_id] = cli_create("onetemplate clone '#{@info[:template]}' '#{tmpl}'")

            # update context
            cli_update("onetemplate update '#{@info[:tmpl_id]}'", @info[:context], true)

            # Instantiate from modified template
            @info[:vm_dtime] = Time.now.to_i
            disk_attrs = ":dev_prefix=#{@info[:prefix]}"

            if image_size
                disk_attrs += ":size='#{image_size}'"
            end

            create_cmd = "onetemplate instantiate --disk '#{@info[:image]}'#{disk_attrs} #{@info[:tmpl_id]}"
            if windows?
                features = [
                    'ACPI="yes"',
                    'APIC="yes"',
                    'GUEST_AGENT="yes"',
                    'HYPERV="yes"',
                    'LOCALTIME="yes"',
                    'PAE="yes"',
                    'VIRTIO_SCSI_QUEUES="auto"',
                    'VIRTIO_BLK_QUEUES="auto"'
                ]

                create_cmd << ' --memory 4096 --cpu 4 --vcpu 4'
                create_cmd << " --raw FEATURES=[#{features.join(',')}]"

                if @info[:image] == 'windows2022'
                    os = [
                        'BOOT="disk0"',
                        'FIRMWARE="/usr/share/OVMF/OVMF_CODE.secboot.fd"',
                        'FIRMWARE_SECURE="YES"',
                        'MACHINE="q35"'
                    ]
                    create_cmd << "OS=[#{os.join(',')}]"
                end

            end

            pp create_cmd

            @info[:vm_id] = cli_create(create_cmd)
            @info[:vm] = VM.new(@info[:vm_id])
            @info[:vm].running?

            @info[:vm_stime] = Time.now.to_i
            cli_action("onetemplate delete #{@info[:tmpl_id]}")
        end
    end
end

shared_examples_for 'context_linux_reboot' do |safe = true|
    it 'reboots' do
        if safe
            safe_reboot_ok = false
            @info[:vm].safe_reboot
            sleep 10

            t_start = Time.now
            while Time.now - t_start < 100
                if system("ping -q -W1 -c1 #{@info[:vm].ip} >/dev/null 2>&1")
                    safe_reboot_ok = true
                    break
                end
            end
        end

        # hard reboot if expl. required or VM doesn't ping after soft reboot
        if !safe || !safe_reboot_ok
            @info[:vm].ssh('sync') unless safe
            @info[:vm].hard_reboot
        end

        sleep 5

        wait_loop do
            @info[:vm].wait_ping
            @info[:vm].reachable?
        end

        # double check we really have working SSH connection
        wait_loop do
            cmd = @info[:vm].ssh('cat /etc/passwd')
            cmd.success? and !cmd.stdout.strip.empty?
        end
    end

    it 'contextualized' do
        @info[:vm].wait_context
    end
end

# Waits until any pending/running contextualization is finished
shared_examples_for 'context_linux_contextualized' do
    it 'waits for contextualization' do
        wait_loop do
            net = @info[:vm].ssh('test -e /var/run/one-context/context.sh.network')
            lock = @info[:vm].ssh('test -e /var/run/one-context/one-context.lock')
            ps = @info[:vm].ssh('ps axuwww').stdout.strip

            net.success? && \
                lock.fail? && \
                !ps.include?('one-context-run') && \
                !ps.include?('one-contextd')
        end
    end
end

shared_examples_for 'context_windows_safe_poweroff' do
    it 'poweroff' do
        @info[:vm].winrm('shutdown /s /f /t 0')
        @info[:vm].wait_no_ping

        if @info[:vm].state == 'RUNNING'
            # issue poweroff directly, but allow command to fail silently
            # as the state of VM can already change to POWEROFF by monitoring
            cli_action("onevm poweroff #{@info[:vm].id}", nil, true)
        end

        @info[:vm].state?('POWEROFF')
    end
end

def kvm_only(hv)
    nosup_hv(hv) if hv != 'KVM'
end

def kvm?(hv)
    hv == 'KVM'
end

def vcenter_only(hv)
    nosup_hv(hv) if hv != 'VCENTER'
end

def skip_containers(hv)
    nosup_hv(hv) if ['LXD', 'LXC'].include? hv
end

def skip_freebsd(image)
    nosup_os(image) if image =~ /(freebsd)/i
end

def freebsd12?(image)
    image =~ /(freebsd1[12])/i
end

def skip_amazon2023(image)
    nosup_os(image) if image =~ /(amazon2023)/i
end

def windows?
    @info[:image] =~ /windows/
end

def nosup_hv(hv)
    skip nosup("hypervisor: #{hv}")
end

def nosup_os(os)
    skip nosup("OS: #{os}")
end

def nosup(platform)
    "Unsupported on this #{platform}"
end
