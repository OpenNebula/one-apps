# frozen_string_literal: true

require 'json'
require 'rspec'

require_relative 'cleaner.rb'

RSpec.describe 'detect_invalid_nodes' do
    it 'should return list of invalid nodes (to be removed)' do
        allow(self).to receive(:kubectl_get_nodes).and_return JSON.parse <<~'JSON'
        {
            "apiVersion": "v1",
            "items": [
                {
                    "apiVersion": "v1",
                    "kind": "Node",
                    "metadata": {
                        "annotations": {
                            "flannel.alpha.coreos.com/backend-data": "{\"VtepMAC\":\"6e:c7:7a:19:fb:7f\"}",
                            "flannel.alpha.coreos.com/backend-type": "vxlan",
                            "flannel.alpha.coreos.com/kube-subnet-manager": "true",
                            "flannel.alpha.coreos.com/public-ip": "172.20.0.100",
                            "kubeadm.alpha.kubernetes.io/cri-socket": "/var/run/dockershim.sock",
                            "node.alpha.kubernetes.io/ttl": "0",
                            "projectcalico.org/IPv4Address": "172.20.0.100/24",
                            "projectcalico.org/IPv4IPIPTunnelAddr": "10.244.0.1",
                            "volumes.kubernetes.io/controller-managed-attach-detach": "true"
                        },
                        "creationTimestamp": "2022-03-15T09:06:29Z",
                        "labels": {
                            "beta.kubernetes.io/arch": "amd64",
                            "beta.kubernetes.io/os": "linux",
                            "kubernetes.io/arch": "amd64",
                            "kubernetes.io/hostname": "oneke-ip-172-20-0-100",
                            "kubernetes.io/os": "linux",
                            "node-role.kubernetes.io/control-plane": "",
                            "node-role.kubernetes.io/master": "",
                            "node.kubernetes.io/exclude-from-external-load-balancers": ""
                        },
                        "name": "oneke-ip-172-20-0-100",
                        "resourceVersion": "17537",
                        "uid": "e198b625-8c3b-40c5-b41b-acd994a73be3"
                    },
                    "spec": {
                        "podCIDR": "10.244.0.0/24",
                        "podCIDRs": [
                            "10.244.0.0/24"
                        ],
                        "taints": [
                            {
                                "effect": "NoSchedule",
                                "key": "node-role.kubernetes.io/master"
                            }
                        ]
                    },
                    "status": {
                        "addresses": [
                            {
                                "address": "172.20.0.100",
                                "type": "InternalIP"
                            },
                            {
                                "address": "oneke-ip-172-20-0-100",
                                "type": "Hostname"
                            }
                        ],
                        "allocatable": {
                            "cpu": "2",
                            "ephemeral-storage": "18566299208",
                            "hugepages-2Mi": "0",
                            "memory": "1939544Ki",
                            "pods": "110"
                        },
                        "capacity": {
                            "cpu": "2",
                            "ephemeral-storage": "20145724Ki",
                            "hugepages-2Mi": "0",
                            "memory": "2041944Ki",
                            "pods": "110"
                        },
                        "conditions": [
                            {
                                "lastHeartbeatTime": "2022-03-15T09:07:04Z",
                                "lastTransitionTime": "2022-03-15T09:07:04Z",
                                "message": "Flannel is running on this node",
                                "reason": "FlannelIsUp",
                                "status": "False",
                                "type": "NetworkUnavailable"
                            },
                            {
                                "lastHeartbeatTime": "2022-03-15T11:09:59Z",
                                "lastTransitionTime": "2022-03-15T09:06:22Z",
                                "message": "kubelet has sufficient memory available",
                                "reason": "KubeletHasSufficientMemory",
                                "status": "False",
                                "type": "MemoryPressure"
                            },
                            {
                                "lastHeartbeatTime": "2022-03-15T11:09:59Z",
                                "lastTransitionTime": "2022-03-15T09:06:22Z",
                                "message": "kubelet has no disk pressure",
                                "reason": "KubeletHasNoDiskPressure",
                                "status": "False",
                                "type": "DiskPressure"
                            },
                            {
                                "lastHeartbeatTime": "2022-03-15T11:09:59Z",
                                "lastTransitionTime": "2022-03-15T09:06:22Z",
                                "message": "kubelet has sufficient PID available",
                                "reason": "KubeletHasSufficientPID",
                                "status": "False",
                                "type": "PIDPressure"
                            },
                            {
                                "lastHeartbeatTime": "2022-03-15T11:09:59Z",
                                "lastTransitionTime": "2022-03-15T09:07:02Z",
                                "message": "kubelet is posting ready status. AppArmor enabled",
                                "reason": "KubeletReady",
                                "status": "True",
                                "type": "Ready"
                            }
                        ],
                        "daemonEndpoints": {
                            "kubeletEndpoint": {
                                "Port": 10250
                            }
                        },
                        "images": [],
                        "nodeInfo": {
                            "architecture": "amd64",
                            "bootID": "612377df-f413-43ae-91d9-b9ab75d2661a",
                            "containerRuntimeVersion": "docker://20.10.13",
                            "kernelVersion": "5.4.0-1058-kvm",
                            "kubeProxyVersion": "v1.21.10",
                            "kubeletVersion": "v1.21.10",
                            "machineID": "2f2741fd3cb14ef4b6560ae805e1756c",
                            "operatingSystem": "linux",
                            "osImage": "Ubuntu 20.04.4 LTS",
                            "systemUUID": "2f2741fd-3cb1-4ef4-b656-0ae805e1756c"
                        }
                    }
                },
                {
                    "apiVersion": "v1",
                    "kind": "Node",
                    "metadata": {
                        "annotations": {
                            "csi.volume.kubernetes.io/nodeid": "{\"driver.longhorn.io\":\"oneke-ip-172-20-0-101\"}",
                            "flannel.alpha.coreos.com/backend-data": "{\"VtepMAC\":\"fa:f6:f4:57:8f:2e\"}",
                            "flannel.alpha.coreos.com/backend-type": "vxlan",
                            "flannel.alpha.coreos.com/kube-subnet-manager": "true",
                            "flannel.alpha.coreos.com/public-ip": "172.20.0.101",
                            "kubeadm.alpha.kubernetes.io/cri-socket": "/var/run/dockershim.sock",
                            "node.alpha.kubernetes.io/ttl": "0",
                            "projectcalico.org/IPv4Address": "172.20.0.101/24",
                            "projectcalico.org/IPv4IPIPTunnelAddr": "10.244.1.1",
                            "volumes.kubernetes.io/controller-managed-attach-detach": "true"
                        },
                        "creationTimestamp": "2022-03-15T09:08:14Z",
                        "labels": {
                            "beta.kubernetes.io/arch": "amd64",
                            "beta.kubernetes.io/os": "linux",
                            "kubernetes.io/arch": "amd64",
                            "kubernetes.io/hostname": "oneke-ip-172-20-0-101",
                            "kubernetes.io/os": "linux"
                        },
                        "name": "oneke-ip-172-20-0-101",
                        "resourceVersion": "17722",
                        "uid": "dc33eae6-73c2-4a91-90c7-990c2fa5cc11"
                    },
                    "spec": {
                        "podCIDR": "10.244.1.0/24",
                        "podCIDRs": [
                            "10.244.1.0/24"
                        ]
                    },
                    "status": {
                        "addresses": [
                            {
                                "address": "172.20.0.101",
                                "type": "InternalIP"
                            },
                            {
                                "address": "oneke-ip-172-20-0-101",
                                "type": "Hostname"
                            }
                        ],
                        "allocatable": {
                            "cpu": "2",
                            "ephemeral-storage": "18566299208",
                            "hugepages-2Mi": "0",
                            "memory": "1939544Ki",
                            "pods": "110"
                        },
                        "capacity": {
                            "cpu": "2",
                            "ephemeral-storage": "20145724Ki",
                            "hugepages-2Mi": "0",
                            "memory": "2041944Ki",
                            "pods": "110"
                        },
                        "conditions": [
                            {
                                "lastHeartbeatTime": "2022-03-15T09:08:25Z",
                                "lastTransitionTime": "2022-03-15T09:08:25Z",
                                "message": "Flannel is running on this node",
                                "reason": "FlannelIsUp",
                                "status": "False",
                                "type": "NetworkUnavailable"
                            },
                            {
                                "lastHeartbeatTime": "2022-03-15T11:11:22Z",
                                "lastTransitionTime": "2022-03-15T09:08:14Z",
                                "message": "kubelet has sufficient memory available",
                                "reason": "KubeletHasSufficientMemory",
                                "status": "False",
                                "type": "MemoryPressure"
                            },
                            {
                                "lastHeartbeatTime": "2022-03-15T11:11:22Z",
                                "lastTransitionTime": "2022-03-15T09:08:14Z",
                                "message": "kubelet has no disk pressure",
                                "reason": "KubeletHasNoDiskPressure",
                                "status": "False",
                                "type": "DiskPressure"
                            },
                            {
                                "lastHeartbeatTime": "2022-03-15T11:11:22Z",
                                "lastTransitionTime": "2022-03-15T09:08:14Z",
                                "message": "kubelet has sufficient PID available",
                                "reason": "KubeletHasSufficientPID",
                                "status": "False",
                                "type": "PIDPressure"
                            },
                            {
                                "lastHeartbeatTime": "2022-03-15T11:11:22Z",
                                "lastTransitionTime": "2022-03-15T09:08:25Z",
                                "message": "kubelet is posting ready status. AppArmor enabled",
                                "reason": "KubeletReady",
                                "status": "True",
                                "type": "Ready"
                            }
                        ],
                        "daemonEndpoints": {
                            "kubeletEndpoint": {
                                "Port": 10250
                            }
                        },
                        "images": [],
                        "nodeInfo": {
                            "architecture": "amd64",
                            "bootID": "b2b7b410-bc29-4a6d-b4a6-fdbf7328b6cb",
                            "containerRuntimeVersion": "docker://20.10.13",
                            "kernelVersion": "5.4.0-1058-kvm",
                            "kubeProxyVersion": "v1.21.10",
                            "kubeletVersion": "v1.21.10",
                            "machineID": "1f5851ae52914927a1cf4c86427e0a36",
                            "operatingSystem": "linux",
                            "osImage": "Ubuntu 20.04.4 LTS",
                            "systemUUID": "1f5851ae-5291-4927-a1cf-4c86427e0a36"
                        }
                    }
                },
                {
                    "apiVersion": "v1",
                    "kind": "Node",
                    "metadata": {
                        "annotations": {
                            "csi.volume.kubernetes.io/nodeid": "{\"driver.longhorn.io\":\"oneke-ip-172-20-0-102\"}",
                            "flannel.alpha.coreos.com/backend-data": "{\"VtepMAC\":\"1a:f1:ed:df:19:cd\"}",
                            "flannel.alpha.coreos.com/backend-type": "vxlan",
                            "flannel.alpha.coreos.com/kube-subnet-manager": "true",
                            "flannel.alpha.coreos.com/public-ip": "172.20.0.102",
                            "kubeadm.alpha.kubernetes.io/cri-socket": "/var/run/dockershim.sock",
                            "node.alpha.kubernetes.io/ttl": "0",
                            "projectcalico.org/IPv4Address": "172.20.0.102/24",
                            "projectcalico.org/IPv4IPIPTunnelAddr": "10.244.2.1",
                            "volumes.kubernetes.io/controller-managed-attach-detach": "true"
                        },
                        "creationTimestamp": "2022-03-15T09:08:28Z",
                        "labels": {
                            "beta.kubernetes.io/arch": "amd64",
                            "beta.kubernetes.io/os": "linux",
                            "kubernetes.io/arch": "amd64",
                            "kubernetes.io/hostname": "oneke-ip-172-20-0-102",
                            "kubernetes.io/os": "linux",
                            "node.longhorn.io/create-default-disk": "true"
                        },
                        "name": "oneke-ip-172-20-0-102",
                        "resourceVersion": "17746",
                        "uid": "cb5c7412-0ec8-47a6-9caa-5fd8bd720684"
                    },
                    "spec": {
                        "podCIDR": "10.244.2.0/24",
                        "podCIDRs": [
                            "10.244.2.0/24"
                        ],
                        "taints": [
                            {
                                "effect": "NoSchedule",
                                "key": "node.longhorn.io/create-default-disk",
                                "value": "true"
                            }
                        ]
                    },
                    "status": {
                        "addresses": [
                            {
                                "address": "172.20.0.102",
                                "type": "InternalIP"
                            },
                            {
                                "address": "oneke-ip-172-20-0-102",
                                "type": "Hostname"
                            }
                        ],
                        "allocatable": {
                            "cpu": "2",
                            "ephemeral-storage": "18566299208",
                            "hugepages-2Mi": "0",
                            "memory": "1939544Ki",
                            "pods": "110"
                        },
                        "capacity": {
                            "cpu": "2",
                            "ephemeral-storage": "20145724Ki",
                            "hugepages-2Mi": "0",
                            "memory": "2041944Ki",
                            "pods": "110"
                        },
                        "conditions": [
                            {
                                "lastHeartbeatTime": "2022-03-15T09:08:39Z",
                                "lastTransitionTime": "2022-03-15T09:08:39Z",
                                "message": "Flannel is running on this node",
                                "reason": "FlannelIsUp",
                                "status": "False",
                                "type": "NetworkUnavailable"
                            },
                            {
                                "lastHeartbeatTime": "2022-03-15T11:11:32Z",
                                "lastTransitionTime": "2022-03-15T09:08:28Z",
                                "message": "kubelet has sufficient memory available",
                                "reason": "KubeletHasSufficientMemory",
                                "status": "False",
                                "type": "MemoryPressure"
                            },
                            {
                                "lastHeartbeatTime": "2022-03-15T11:11:32Z",
                                "lastTransitionTime": "2022-03-15T09:08:28Z",
                                "message": "kubelet has no disk pressure",
                                "reason": "KubeletHasNoDiskPressure",
                                "status": "False",
                                "type": "DiskPressure"
                            },
                            {
                                "lastHeartbeatTime": "2022-03-15T11:11:32Z",
                                "lastTransitionTime": "2022-03-15T09:08:28Z",
                                "message": "kubelet has sufficient PID available",
                                "reason": "KubeletHasSufficientPID",
                                "status": "False",
                                "type": "PIDPressure"
                            },
                            {
                                "lastHeartbeatTime": "2022-03-15T11:11:32Z",
                                "lastTransitionTime": "2022-03-15T09:08:38Z",
                                "message": "kubelet is posting ready status. AppArmor enabled",
                                "reason": "KubeletReady",
                                "status": "True",
                                "type": "Ready"
                            }
                        ],
                        "daemonEndpoints": {
                            "kubeletEndpoint": {
                                "Port": 10250
                            }
                        },
                        "images": [],
                        "nodeInfo": {
                            "architecture": "amd64",
                            "bootID": "0df98c4d-163e-4468-b299-7d8fdb34a172",
                            "containerRuntimeVersion": "docker://20.10.13",
                            "kernelVersion": "5.4.0-1058-kvm",
                            "kubeProxyVersion": "v1.21.10",
                            "kubeletVersion": "v1.21.10",
                            "machineID": "69820ee32d094fdbbb065b80643a06dc",
                            "operatingSystem": "linux",
                            "osImage": "Ubuntu 20.04.4 LTS",
                            "systemUUID": "69820ee3-2d09-4fdb-bb06-5b80643a06dc"
                        }
                    }
                }
            ],
            "kind": "List",
            "metadata": {
                "resourceVersion": "",
                "selfLink": ""
            }
        }
        JSON
        allow(self).to receive(:all_vms_show).and_return JSON.parse <<~JSON
        [
            {
              "VM": {
                "NAME": "master_0_(service_21)",
                "ID": "49",
                "STATE": "3",
                "LCM_STATE": "3",
                "USER_TEMPLATE": {
                  "INPUTS_ORDER": "ONEAPP_K8S_ADDRESS,ONEAPP_K8S_TOKEN,ONEAPP_K8S_HASH,ONEAPP_K8S_NODENAME,ONEAPP_K8S_PORT,ONEAPP_K8S_TAINTED_MASTER,ONEAPP_K8S_PODS_NETWORK,ONEAPP_K8S_ADMIN_USERNAME,ONEAPP_K8S_METALLB_RANGE,ONEAPP_K8S_METALLB_CONFIG",
                  "ONEGATE_K8S_NODE_NAME": "oneke-ip-172-20-0-100",
                  "ONEGATE_K8S_HASH": "09a9ed140fec2fa1a2281a3125952d6f2951b67a67534647b0a606ae2d478f60",
                  "ONEGATE_K8S_MASTER": "172.20.0.100",
                  "ONEGATE_K8S_TOKEN": "sg7711.p19vy0eqxefc0lqz",
                  "READY": "YES",
                  "ROLE_NAME": "master",
                  "SERVICE_ID": "21",
                  "USER_INPUTS": {
                    "ONEAPP_K8S_ADDRESS": "O|text|Master node address",
                    "ONEAPP_K8S_HASH": "O|text|Secret hash (to join node into the cluster)",
                    "ONEAPP_K8S_METALLB_CONFIG": "O|text64|Custom MetalLB config",
                    "ONEAPP_K8S_METALLB_RANGE": "O|text|MetalLB IP range (default none)",
                    "ONEAPP_K8S_NODENAME": "O|text|Master node name",
                    "ONEAPP_K8S_PODS_NETWORK": "O|text|Pods network in CIDR (default 10.244.0.0/16)",
                    "ONEAPP_K8S_PORT": "O|text|Kubernetes API port (default 6443)",
                    "ONEAPP_K8S_TOKEN": "O|password|Secret token (to join node into the cluster)"
                  }
                },
                "TEMPLATE": {
                  "NIC": [
                    {
                      "IP": "172.20.0.100",
                      "MAC": "02:00:ac:14:00:64",
                      "NAME": "_NIC0",
                      "NETWORK": "service"
                    }
                  ],
                  "NIC_ALIAS": []
                }
              }
            },
            {
              "VM": {
                "NAME": "storage_0_(service_21)",
                "ID": "51",
                "STATE": "3",
                "LCM_STATE": "3",
                "USER_TEMPLATE": {
                  "INPUTS_ORDER": "ONEAPP_K8S_ADDRESS,ONEAPP_K8S_TOKEN,ONEAPP_K8S_HASH,ONEAPP_K8S_NODENAME,ONEAPP_K8S_PORT,ONEAPP_K8S_TAINTED_MASTER,ONEAPP_K8S_PODS_NETWORK,ONEAPP_K8S_ADMIN_USERNAME,ONEAPP_K8S_METALLB_RANGE,ONEAPP_K8S_METALLB_CONFIG",
                  "ONEGATE_K8S_NODE_NAME": "oneke-ip-172-20-0-102",
                  "READY": "YES",
                  "ROLE_NAME": "storage",
                  "SERVICE_ID": "21",
                  "USER_INPUTS": {
                    "ONEAPP_K8S_ADDRESS": "O|text|Master node address",
                    "ONEAPP_K8S_HASH": "O|text|Secret hash (to join node into the cluster)",
                    "ONEAPP_K8S_METALLB_CONFIG": "O|text64|Custom MetalLB config",
                    "ONEAPP_K8S_METALLB_RANGE": "O|text|MetalLB IP range (default none)",
                    "ONEAPP_K8S_NODENAME": "O|text|Master node name",
                    "ONEAPP_K8S_PODS_NETWORK": "O|text|Pods network in CIDR (default 10.244.0.0/16)",
                    "ONEAPP_K8S_PORT": "O|text|Kubernetes API port (default 6443)",
                    "ONEAPP_K8S_TOKEN": "O|password|Secret token (to join node into the cluster)"
                  }
                },
                "TEMPLATE": {
                  "NIC": [
                    {
                      "IP": "172.20.0.102",
                      "MAC": "02:00:ac:14:00:66",
                      "NAME": "_NIC0",
                      "NETWORK": "service"
                    }
                  ],
                  "NIC_ALIAS": []
                }
              }
            }
        ]
        JSON
        expect(detect_invalid_nodes).to eq ['oneke-ip-172-20-0-101']
    end
end
