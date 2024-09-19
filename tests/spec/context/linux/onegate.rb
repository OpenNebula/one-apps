shared_examples_for 'onegate_linux' do |image, hv, prefix, ready_method, context|
    include_examples 'context_linux', image, hv, prefix, <<~EOT
        #{context}
        CONTEXT=[
          NETWORK="YES",
          SSH_PUBLIC_KEY="\$USER[SSH_PUBLIC_KEY]",
          TOKEN="YES",
          REPORT_READY="YES",
          #{ready_method[:method]}]
    EOT

    it 'uses ready_method' do
        pp "using ready_method #{ready_method[:method]}"
    end

    if ready_method[:ready]
        it 'reports READY=YES via OneGate' do
            @info[:vm].ready?
        end
    else
        it 'does not report READY=YES via OneGate' do
            @info[:vm].ready?(nil)
        end
    end
end
