require 'init'

SSH_OPTS = '-o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null'

VNET_PUBLIC_IP   = '192.168.150.100'
VNET_PUBLIC_LBIP = '192.168.150.87'

K8S_SERVICE_NAME = 'Service OneKE 1.29 Airgapped'

MANIFEST = <<~MANIFEST
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: http
        image: nginx:alpine
        imagePullPolicy: IfNotPresent
        ports:
        - name: http
          containerPort: 80
        volumeMounts:
        - mountPath: /test/
          name: test
      volumes:
      - name: test
        persistentVolumeClaim:
          claimName: test
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 4Gi
  storageClassName: longhorn-retain
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  selector:
    app: nginx
  type: ClusterIP
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: nginx
spec:
  entryPoints: [web]
  routes:
    - kind: Rule
      match: Path(`/`)
      services:
        - kind: Service
          name: nginx
          port: 80
          scheme: http
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-lb
spec:
  selector:
    app: nginx
  type: LoadBalancer
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 80
MANIFEST

def download_kubectl_and_kubeconfig
    return if File.exist?('/var/tmp/kubectl') && File.exist?('/var/tmp/kubeconfig')

    service = cli_action_json "oneflow show '#{K8S_SERVICE_NAME}' --json", nil
    roles   = service.dig 'DOCUMENT', 'TEMPLATE', 'BODY', 'roles'
    master  = roles.find {|item| item['name'] == 'master'}
    nodes   = master.dig 'nodes'
    name    = nodes.first.dig 'vm_info', 'VM', 'NAME'

    vm   = cli_action_json "onevm show '#{name}' --json", nil
    nics = vm.dig 'VM', 'TEMPLATE', 'NIC'
    nic  = nics.find {|item| item['NAME'] == '_NIC0'}
    ip   = nic.dig 'IP'

    proxy_command = "ProxyCommand='ssh #{SSH_OPTS} root@#{VNET_PUBLIC_IP} -W %h:%p'"

    # Fetch (statically linked) kubectl binary
    cli_action "scp #{SSH_OPTS} -o #{proxy_command} root@#{ip}:/var/lib/rancher/rke2/bin/kubectl /var/tmp/kubectl", nil

    # Fetch kubeconfig
    cli_action "scp #{SSH_OPTS} -o #{proxy_command} root@#{ip}:/etc/rancher/rke2/rke2.yaml /var/tmp/rke2.yaml", nil

    # Update kubeconfig
    kubeconfig = YAML.safe_load File.read('/var/tmp/rke2.yaml', encoding: 'utf-8')
    kubeconfig['clusters'][0]['cluster']['server'] = "https://#{VNET_PUBLIC_IP}:6443"
    File.write '/var/tmp/kubeconfig', YAML.dump(kubeconfig)
end

RSpec.describe 'Deploy NGINX manifest' do
    before(:all) do
        download_kubectl_and_kubeconfig
    end
    it 'apply NGINX manifest' do
        file = Tempfile.new 'nginx-with-lb-and-pvc.yml'
        file.write MANIFEST
        file.flush
        file.close

        wait_loop(success: true, break: nil, timeout: 300, resource_ref: nil) do
            cmd = cli_action "/var/tmp/kubectl --kubeconfig /var/tmp/kubeconfig apply -f #{file.path}", nil
            cmd.success?
        end
    end
    it 'check NGINX is running' do
        wait_loop(success: true, break: nil, timeout: 300, resource_ref: nil) do
           cmd = cli_action "curl -fsSL http://#{VNET_PUBLIC_IP}", nil
           result = /Welcome to nginx!/.match(cmd.stdout)
           result ? true : false
        end
    end
    #it 'check NGINX is running (via LB)' do
    #    wait_loop(success: true, break: nil, timeout: 300, resource_ref: nil) do
    #       cmd = cli_action "curl -fsSL http://#{VNET_PUBLIC_LBIP}", nil
    #       result = /Welcome to nginx!/.match(cmd.stdout)
    #       result ? true : false
    #    end
    #end
end
