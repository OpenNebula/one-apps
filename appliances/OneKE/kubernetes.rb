# frozen_string_literal: true

require 'base64'
require 'securerandom'
require 'uri'
require 'yaml'

require_relative 'config.rb'
require_relative 'helpers.rb'
require_relative 'onegate.rb'
require_relative 'vnf.rb'

def install_kubernetes(airgap_dir = ONE_AIRGAP_DIR)
    rke2_release_url = "https://github.com/rancher/rke2/releases/download/#{ONE_SERVICE_RKE2_VERSION}"

    amap= {
      "x86_64" => "amd64",
      "aarch64" => "arm64"
    }
    begin
      arch = amap[`arch`.strip]
    rescue KeyError
      msg :error, "Unknown architecture"
      exit 1
    end

    msg :info, "Install RKE2 runtime: #{ONE_SERVICE_RKE2_VERSION}"
    bash <<~SCRIPT
    curl -fsSL '#{rke2_release_url}/rke2.linux-#{arch}.tar.gz' | tar -xz -f- -C /usr/local/
    SCRIPT

    if ONE_SERVICE_AIRGAPPED
        msg :info, "Download RKE2 airgapped image archives: #{ONE_SERVICE_RKE2_VERSION}"
        bash <<~SCRIPT
        curl -fsSL '#{rke2_release_url}/rke2-images-core.linux-#{arch}.tar.zst' \
        | install -o 0 -g 0 -m u=rw,go=r -D /dev/fd/0 '#{airgap_dir}/rke2-images-core/rke2-images-core.linux-#{arch}.tar.zst'
        SCRIPT
        bash <<~SCRIPT
        curl -fsSL '#{rke2_release_url}/rke2-images-multus.linux-#{arch}.tar.zst' \
        | install -o 0 -g 0 -m u=rw,go=r -D /dev/fd/0 '#{airgap_dir}/rke2-images-multus/rke2-images-multus.linux-#{arch}.tar.zst'
        SCRIPT
        bash <<~SCRIPT
        curl -fsSL '#{rke2_release_url}/rke2-images-calico.linux-#{arch}.tar.zst' \
        | install -o 0 -g 0 -m u=rw,go=r -D /dev/fd/0 '#{airgap_dir}/rke2-images-calico/rke2-images-calico.linux-#{arch}.tar.zst'
        SCRIPT
        bash <<~SCRIPT
        curl -fsSL '#{rke2_release_url}/rke2-images-canal.linux-#{arch}.tar.zst' \
        | install -o 0 -g 0 -m u=rw,go=r -D /dev/fd/0 '#{airgap_dir}/rke2-images-canal/rke2-images-canal.linux-#{arch}.tar.zst'
        SCRIPT
        bash <<~SCRIPT
        curl -fsSL '#{rke2_release_url}/rke2-images-cilium.linux-#{arch}.tar.zst' \
        | install -o 0 -g 0 -m u=rw,go=r -D /dev/fd/0 '#{airgap_dir}/rke2-images-cilium/rke2-images-cilium.linux-#{arch}.tar.zst'
        SCRIPT
    end

    msg :info, "Install Helm binary: #{ONE_SERVICE_HELM_VERSION}"
    bash <<~SCRIPT
    curl -fsSL 'https://get.helm.sh/helm-v#{ONE_SERVICE_HELM_VERSION}-linux-#{arch}.tar.gz' \
    | tar -xOz -f- linux-#{arch}/helm \
    | install -o 0 -g 0 -m u=rwx,go=rx -D /dev/fd/0 /usr/local/bin/helm
    SCRIPT

    msg :info, 'Link kubectl binary'
    File.symlink '/var/lib/rancher/rke2/bin/kubectl', '/usr/local/bin/kubectl'

    msg :info, 'Link crictl binary'
    File.symlink '/var/lib/rancher/rke2/bin/crictl', '/usr/local/bin/crictl'

    msg :info, 'Set BASH profile defaults'
    file '/etc/profile.d/98-oneke.sh', <<~PROFILE, mode: 'u=rw,go=r'
    export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
    export CRI_CONFIG_FILE=/var/lib/rancher/rke2/agent/etc/crictl.yaml
    PROFILE
end

def configure_kubernetes(configure_cni: ->{}, configure_addons: ->{})
    node = detect_node

    if node[:init_master]
        configure_cni.()
        init_master
        configure_addons.()
    elsif node[:join_master]
        configure_cni.()
        join_master node[:token]
        configure_addons.()
    elsif node[:join_worker]
        join_worker node[:token]
    elsif node[:join_storage]
        join_storage node[:token]
    end

    # NOTE: There is no need to enable rke2 services after init/join is done,
    #       starting them "manually" gives us more control.
    if node[:start_server]
        bash <<~SCRIPT
        systemctl disable rke2-server.service
        systemctl start rke2-server.service
        SCRIPT
    elsif node[:start_agent]
        bash <<~SCRIPT
        systemctl disable rke2-agent.service
        systemctl start rke2-agent.service
        SCRIPT
    end

    node
end

def wait_for_any_master(retries = RETRIES, seconds = SECONDS)
    msg :info, 'Wait for any master to be available'

    retries.downto(0).each do |retry_num|
        msg :debug, "wait_for_any_master / #{retry_num}"

        master_vms_show.each do |master_vm|
            ready = master_vm.dig 'VM', 'USER_TEMPLATE', 'READY'
            next unless ready == 'YES'

            # Not using the CP/EP here, only a direct validation without going through VNF/LB.
            # The first responding master wins.

            k8s_master = master_vm.dig 'VM', 'USER_TEMPLATE', 'ONEGATE_K8S_MASTER'
            next if k8s_master.nil?

            return master_vm if tcp_port_open? k8s_master, 6443
        end

        if retry_num.zero?
            msg :error, 'No usable master found'
            exit 1
        end

        sleep seconds
    end
end

def wait_for_control_plane(endpoint = ONEAPP_K8S_CONTROL_PLANE_EP, retries = RETRIES, seconds = SECONDS)
    msg :info, 'Wait for Control-Plane to be ready'

    retries.downto(0).each do |retry_num|
        msg :debug, "wait_for_control_plane / #{retry_num}"

        break if http_status_200? "https://#{endpoint}/readyz"

        if retry_num.zero?
            msg :error, 'Control-Plane not ready'
            exit 1
        end

        sleep seconds
    end
end

def wait_for_kubelets(retries = RETRIES, seconds = SECONDS)
    msg :info, 'Wait for available Kubelets to be ready'

    retries.downto(0).each do |retry_num|
        msg :debug, "wait_for_kubelets / #{retry_num}"

        conditions = kubectl_get_nodes['items'].map do |node|
            node.dig('status', 'conditions').find do |item|
                item['reason'] == 'KubeletReady' && item['type'] == 'Ready' && item['status'] == 'True'
            end
        end

        break if conditions.all?

        if retry_num.zero?
            msg :error, 'Kubelets not ready'
            exit 1
        end

        sleep seconds
    end
end

def init_master
    ipv4 = external_ipv4s.first
    name = "oneke-ip-#{ipv4.gsub '.', '-'}"

    msg :info, "Set local hostname: #{name}"
    bash "hostnamectl set-hostname #{name}"

    onegate_vm_update ["ONEGATE_K8S_NODE_NAME=#{name}"]

    msg :info, 'Set this master to be the first VNF backend'
    vnf_supervisor_setup_backend
    vnf_control_plane_setup_backend

    cni = []
    cni << 'multus' if ONEAPP_K8S_MULTUS_ENABLED
    cni << ONEAPP_K8S_CNI_PLUGIN

    cp = URI.parse "https://#{ONEAPP_K8S_CONTROL_PLANE_EP}"
    sans = ONEAPP_K8S_EXTRA_SANS.split(',').map(&:strip)
    sans << cp.host

    server_config = {
        'node-name'                => name,
        'token'                    => SecureRandom.uuid,
        'tls-san'                  => sans.uniq,
        'node-taint'               => ['CriticalAddonsOnly=true:NoExecute'],
        'disable'                  => ['rke2-ingress-nginx'],
        'cni'                      => cni,
        'disable-kube-proxy'       => ONEAPP_K8S_CNI_PLUGIN == 'cilium',
        'disable-cloud-controller' => ONEAPP_RKE2_CLOUD_CONTROLLER_ENABLED == false
    }

    msg :info, 'Prepare initial rke2-server config'
    file '/etc/rancher/rke2/config.yaml', YAML.dump(server_config), overwrite: false

    configure_rke2_proxy 'master'

    msg :info, "Initialize first master: #{name}"
    bash 'systemctl enable rke2-server.service --now'

    server_config.merge!({
        'server' => "https://#{ONEAPP_RKE2_SUPERVISOR_EP}",
        'token'  => File.read('/var/lib/rancher/rke2/server/node-token', encoding: 'utf-8').strip
    })

    msg :info, 'Normalize rke2-server config'
    file '/etc/rancher/rke2/config.yaml', YAML.dump(server_config), overwrite: true

    onegate_vm_update ["ONEGATE_K8S_MASTER=#{ipv4}", "ONEGATE_K8S_TOKEN=#{server_config['token']}"]

    wait_for_control_plane
    wait_for_kubelets

    # Please make sure you add VM_ENCRYPTED_ATTR="ONEKE_KUBECONFIG" to /etc/one/oned.conf.
    unless (kubeconfig = resolv_kubeconfig).nil?
        encoded = Base64.strict_encode64 kubeconfig
        onegate_vm_update ["ONEKE_KUBECONFIG=#{encoded}"]
    end
end

def join_master(token, retries = RETRIES, seconds = SECONDS)
    ipv4 = external_ipv4s.first
    name = "oneke-ip-#{ipv4.gsub '.', '-'}"

    msg :info, "Set local hostname: #{name}"
    bash "hostnamectl set-hostname #{name}"

    onegate_vm_update ["ONEGATE_K8S_NODE_NAME=#{name}"]

    cni = []
    cni << 'multus' if ONEAPP_K8S_MULTUS_ENABLED
    cni << ONEAPP_K8S_CNI_PLUGIN

    cp = URI.parse "https://#{ONEAPP_K8S_CONTROL_PLANE_EP}"
    sans = ONEAPP_K8S_EXTRA_SANS.split(',').map(&:strip)
    sans << cp.host

    server_config = {
        'node-name'                => name,
        'server'                   => "https://#{ONEAPP_RKE2_SUPERVISOR_EP}",
        'token'                    => token,
        'tls-san'                  => sans.uniq,
        'node-taint'               => ['CriticalAddonsOnly=true:NoExecute'],
        'disable'                  => ['rke2-ingress-nginx'],
        'cni'                      => cni,
        'disable-kube-proxy'       => ONEAPP_K8S_CNI_PLUGIN == 'cilium',
        'disable-cloud-controller' => ONEAPP_RKE2_CLOUD_CONTROLLER_ENABLED == false
    }

    msg :info, 'Prepare rke2-server config'
    file '/etc/rancher/rke2/config.yaml', YAML.dump(server_config), overwrite: true

    configure_rke2_proxy 'master'

    # The rke2-server systemd service restarts automatically and eventually joins.
    # If it really cannot join we want to reflect this in OneFlow.
    retries.downto(0).each do |retry_num|
        if retry_num.zero?
            msg :error, 'Unable to join Control-Plane'
            exit 1
        end
        begin
            msg :info, "Join master: #{name} / #{retry_num}"
            bash 'systemctl enable rke2-server.service --now'
        rescue RuntimeError
            sleep seconds
            next
        end
        break
    end

    onegate_vm_update ["ONEGATE_K8S_MASTER=#{ipv4}", "ONEGATE_K8S_TOKEN=#{server_config['token']}"]

    msg :info, 'Set this master to be a VNF backend'
    vnf_supervisor_setup_backend
    vnf_control_plane_setup_backend

    wait_for_control_plane
    wait_for_kubelets

    # Please make sure you add VM_ENCRYPTED_ATTR="ONEKE_KUBECONFIG" to /etc/one/oned.conf.
    unless (kubeconfig = resolv_kubeconfig).nil?
        encoded = Base64.strict_encode64 kubeconfig
        onegate_vm_update ["ONEKE_KUBECONFIG=#{encoded}"]
    end
end

def join_worker(token)
    ipv4 = external_ipv4s.first
    name = "oneke-ip-#{ipv4.gsub '.', '-'}"

    msg :info, "Set local hostname: #{name}"
    bash "hostnamectl set-hostname #{name}"

    onegate_vm_update ["ONEGATE_K8S_NODE_NAME=#{name}"]

    agent_config = {
        'node-name' => name,
        'server'    => "https://#{ONEAPP_RKE2_SUPERVISOR_EP}",
        'token'     => token
    }

    msg :info, 'Prepare rke2-agent config'
    file '/etc/rancher/rke2/config.yaml', YAML.dump(agent_config), overwrite: true

    configure_rke2_proxy 'worker'

    msg :info, "Join worker: #{name}"
    bash 'systemctl enable rke2-agent.service --now'
end

def join_storage(token)
    ipv4 = external_ipv4s.first
    name = "oneke-ip-#{ipv4.gsub '.', '-'}"

    msg :info, "Set local hostname: #{name}"
    bash "hostnamectl set-hostname #{name}"

    onegate_vm_update ["ONEGATE_K8S_NODE_NAME=#{name}"]

    agent_config = {
        'node-name'  => name,
        'server'     => "https://#{ONEAPP_RKE2_SUPERVISOR_EP}",
        'token'      => token,
        'node-taint' => ['node.longhorn.io/create-default-disk=true:NoSchedule'],
        'node-label' => ['node.longhorn.io/create-default-disk=true']
    }

    msg :info, 'Prepare rke2-agent config'
    file '/etc/rancher/rke2/config.yaml', YAML.dump(agent_config), overwrite: true

    configure_rke2_proxy 'worker'

    msg :info, "Join storage: #{name}"
    bash 'systemctl enable rke2-agent.service --now'
end

def detect_node
    current_vm   = onegate_vm_show
    current_vmid = current_vm.dig 'VM', 'ID'
    current_role = current_vm.dig 'VM', 'USER_TEMPLATE', 'ROLE_NAME'

    ready = current_vm.dig('VM', 'USER_TEMPLATE', 'READY') == 'YES'

    master_vm   = master_vm_show
    master_vmid = master_vm.dig 'VM', 'ID'

    master_vm = wait_for_any_master if current_vmid != master_vmid

    token         = master_vm.dig 'VM', 'USER_TEMPLATE', 'ONEGATE_K8S_TOKEN'
    ready_to_join = !token.nil?

    results = {
        init_master:  !ready && current_role == 'master'  && current_vmid == master_vmid && !ready_to_join,
        join_master:  !ready && current_role == 'master'  && current_vmid != master_vmid && ready_to_join,
        join_worker:  !ready && current_role == 'worker'  && current_vmid != master_vmid && ready_to_join,
        join_storage: !ready && current_role == 'storage' && current_vmid != master_vmid && ready_to_join,
        start_server: current_role == 'master',
        start_agent:  current_role != 'master',
        token: token
    }

    msg :debug, "detect_node / #{results}"
    results
end

def configure_rke2_proxy(current_role)
    return if ONEAPP_K8S_HTTP_PROXY.to_s.empty? && ONEAPP_K8S_HTTPS_PROXY.to_s.empty?

    rke2_role = current_role == 'master' ? 'server' : 'agent'
    filepath  = "/etc/default/rke2-#{rke2_role}"

    msg :info, "Prepare rke2-#{rke2_role} proxy config in #{filepath}"

    proxy_config = []
    proxy_config << "HTTP_PROXY=#{ONEAPP_K8S_HTTP_PROXY}" unless ONEAPP_K8S_HTTP_PROXY.nil?
    proxy_config << "HTTPS_PROXY=#{ONEAPP_K8S_HTTPS_PROXY}" unless ONEAPP_K8S_HTTPS_PROXY.nil?
    if ONEAPP_K8S_NO_PROXY.to_s.empty?
        no_proxy = ['127.0.0.1/32', 'localhost']
        no_proxy << retrieve_endpoint_host(ONEAPP_K8S_CONTROL_PLANE_EP) if ONEAPP_K8S_CONTROL_PLANE_EP
        no_proxy << retrieve_endpoint_host(ONEAPP_RKE2_SUPERVISOR_EP) if ONEAPP_RKE2_SUPERVISOR_EP
        proxy_config << "NO_PROXY=#{no_proxy.uniq.join(',')}"
    else
        proxy_config << "NO_PROXY=#{ONEAPP_K8S_NO_PROXY}"
    end

    file filepath, proxy_config.join("\n"), overwrite: true
end

def retrieve_endpoint_host(endpoint)
    uri = URI.parse(endpoint.include?('://') ? endpoint : "http://#{endpoint}")
    host = uri.host
    host = "#{host}/32" if host =~ Resolv::IPv4::Regex
    host
end
