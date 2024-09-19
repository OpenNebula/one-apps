###########################################################
#
# Main Tests
#
#

shared_examples_for 'context_linux_common3' do |image, hv, prefix, context|
    include_examples 'context_linux', image, hv, prefix, <<EOT
#{context}
CONTEXT=[
  NETWORK="YES",
  SSH_PUBLIC_KEY="\$USER[SSH_PUBLIC_KEY]",
  TIMEZONE="InvalidTimeZone"
]
EOT

    it 'has UTC timezone' do
        out = @info[:vm].ssh("date '+%Z'").stdout.strip
        expect(out).to eq('UTC')
    end
end
