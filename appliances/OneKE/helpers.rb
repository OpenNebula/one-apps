# frozen_string_literal: true

require 'base64'
require 'fileutils'
require 'json'
require 'net/http'
require 'tempfile'
require 'uri'
require 'yaml'

begin
    require '/etc/one-appliance/lib/helpers.rb'
rescue LoadError
    require_relative '../lib/helpers.rb'
end

def kubectl(arguments, namespace: nil, kubeconfig: KUBECONFIG)
    kubeconfig = [kubeconfig].flatten.find { |path| !path.nil? && File.exist?(path) }
    command = ['/var/lib/rancher/rke2/bin/kubectl']
    command << "--kubeconfig #{kubeconfig}" unless kubeconfig.nil?
    command << "--namespace #{namespace}" unless namespace.nil?
    command << arguments
    bash command.flatten.join(' ')
end

def kubectl_get_nodes
    JSON.parse kubectl 'get nodes -o json'
end

def kubectl_get_configmap(name, namespace: 'kube-system', kubeconfig: KUBECONFIG)
    YAML.safe_load kubectl <<~COMMAND, namespace: namespace, kubeconfig: kubeconfig
    get configmap/#{name} -o yaml
    COMMAND
end

def kubectl_apply_f(path, kubeconfig: KUBECONFIG)
    kubectl "apply -f #{path}", kubeconfig: kubeconfig
end

def kubectl_apply(manifest, kubeconfig: KUBECONFIG)
    Tempfile.create do |temp_file|
        temp_file.write manifest
        temp_file.close
        return kubectl_apply_f temp_file.path, kubeconfig: kubeconfig
    end
end

def pull_docker_images(images, dest_dir)
    images.each do |image|
        name, tag = image.split ':'

        path = "#{dest_dir}/#{name.gsub '/', '_'}.tar.zst"

        next if File.exist? path

        msg :info, "Pull #{name}:#{tag} -> #{path}"

        FileUtils.mkdir_p dest_dir

        bash <<~SCRIPT
        skopeo copy 'docker://#{name}:#{tag}' 'docker-archive:/dev/fd/2:#{name}:#{tag}' 3>&1 1>&2 2>&3 \
        | zstd --ultra -o '#{path}'
        SCRIPT
    end
end

def extract_images(manifest)
    images = []

    YAML.load_stream manifest do |document|
        next if document.nil?

        if document.dig('kind') == 'HelmChart'
            # NOTE: Aassuming all one-*.yaml manifests contain chartContent: and valuesContent: fields.
            chart_tgz  = Base64.decode64 document.dig('spec', 'chartContent')
            values_yml = document.dig('spec', 'valuesContent')

            Dir.mktmpdir do |temp_dir|
                file "#{temp_dir}/chart.tgz", chart_tgz, overwrite: true
                file "#{temp_dir}/values.yml", values_yml, overwrite: true
                images += extract_images bash("helm template '#{temp_dir}/chart.tgz' -f '#{temp_dir}/values.yml'")
            end

            next
        end

        containers = []
        containers += document.dig('spec', 'template', 'spec', 'containers').to_a
        containers += document.dig('spec', 'template', 'spec', 'initContainers').to_a
        containers += document.dig('spec', 'jobTemplate', 'spec', 'template', 'spec', 'containers').to_a
        containers += document.dig('spec', 'jobTemplate', 'spec', 'template', 'spec', 'initContainers').to_a

        images += containers.map { |container| container.dig 'image' }
    end

    images.uniq
end

def pull_addon_images(addon_dir = ONE_ADDON_DIR, airgap_dir = ONE_AIRGAP_DIR)
    Dir["#{addon_dir}/one-*.yaml"].each do |path|
        manifest = File.read path
        pull_docker_images extract_images(manifest), "#{airgap_dir}/#{File.basename(path, '.yaml')}/"
    end
end

# NOTE: This must be executed *before* starting rke2-server/agent services,
#       otherwise images will not be loaded into containerd.
def include_images(name, airgap_dir = ONE_AIRGAP_DIR, image_dir = K8S_IMAGE_DIR)
    FileUtils.mkdir_p image_dir
    Dir["#{airgap_dir}/#{name}/*.tar.zst"].each do |path|
        msg :info, "Include airgapped image: #{File.basename(path)}"
        symlink = "#{image_dir}/#{File.basename(path)}"
        File.symlink path, symlink unless File.exist? symlink
    end
end

# NOTE: This must be executed *after* starting rke2-server/agent services.
def include_manifests(name, addon_dir = ONE_ADDON_DIR, manifest_dir = K8S_MANIFEST_DIR)
    FileUtils.mkdir_p manifest_dir
    Dir["#{addon_dir}/#{name}*.yaml"].each do |path|
        msg :info, "Include addon: #{File.basename(path)}"
        symlink = "#{manifest_dir}/#{File.basename(path)}"
        File.symlink path, symlink unless File.exist? symlink
    end
end

def with_policy_rc_d_disabled
    file '/usr/sbin/policy-rc.d', 'exit 101', mode: 'a+x', overwrite: true
    yield
ensure
    file '/usr/sbin/policy-rc.d', 'exit 0', mode: 'a+x', overwrite: true
end

def install_packages(packages, hold: false)
    msg :info, "Install APT packages: #{packages.join(',')}"

    puts bash <<~SCRIPT
    apt-get install -y #{packages.join(' ')}
    SCRIPT

    bash <<~SCRIPT if hold
    apt-mark hold #{packages.join(' ')}
    SCRIPT
end

def http_status_200?(url,
                     cacert = '/var/lib/rancher/rke2/server/tls/server-ca.crt',
                     cert = '/var/lib/rancher/rke2/server/tls/client-admin.crt',
                     key = '/var/lib/rancher/rke2/server/tls/client-admin.key',
                     seconds = 5)

    url  = URI.parse url
    http = Net::HTTP.new url.host, url.port

    if url.scheme == 'https'
        http.use_ssl     = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.ca_file     = cacert
        http.cert        = OpenSSL::X509::Certificate.new File.read cert
        http.key         = OpenSSL::PKey::EC.new File.read key
    end

    http.open_timeout = seconds

    http.get(url.path).code == '200'
rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ETIMEDOUT, Net::OpenTimeout
    false
end
