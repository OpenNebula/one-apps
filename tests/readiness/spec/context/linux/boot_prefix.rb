###########################################################
#
# Main Tests
#

shared_examples_for 'context_linux_boot_prefix' do |image, hv, prefix|
    include_examples 'context_linux', image, hv, prefix, <<EOT
CONTEXT=[
  NETWORK="YES",
  SSH_PUBLIC_KEY=\"$USER[SSH_PUBLIC_KEY]\"
]
EOT
end
