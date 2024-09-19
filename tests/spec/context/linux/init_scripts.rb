############################################################
#
# Test Snippets
#

shared_examples_for 'context_linux_prepare_init_scripts' do |image, hv, prefix|
    it 'oneimage create touch1.sh' do
        if cli_action("oneimage show 'touch1.sh' >/dev/null", nil).fail?
            files_image = Tempfile.new('touch1.sh', '/var/tmp')
            files_image.write("touch /tmp/touch1.txt\n")
            files_image.write("echo ok >> /tmp/touch1.txt\n")
            files_image.close

            cli_action("oneimage create --name 'touch1.sh' -d files --type CONTEXT --path '#{files_image.path}'", nil)
        end
    end
end

###########################################################
#
# Main Tests
#

shared_examples_for 'context_linux_init_scripts' do |image, hv, prefix|
    include_examples 'context_linux', image, hv, prefix, <<EOT
CONTEXT=[
    FILES_DS=\"$FILE[IMAGE=\\\"touch1.sh\\\"]\",
    INIT_SCRIPTS="touch1.sh",
    NETWORK="YES",
    SSH_PUBLIC_KEY=\"$USER[SSH_PUBLIC_KEY]\" ]
EOT

    it 'ran contextualization init script' do
        out = @info[:vm].ssh('cat /tmp/touch1.txt').stdout.strip

        expect(out.lines.length).to eq(1)
    end
end
