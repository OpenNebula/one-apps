# frozen_string_literal: true

require 'json'
require 'rspec'

require_relative 'onegate.rb'

RSpec.describe 'all_vms_show' do
    before do
        @svc = JSON.parse(<<~JSON)
        {
          "SERVICE": {
            "name": "asd",
            "id": "21",
            "state": 2,
            "roles": [
              {
                "name": "master",
                "cardinality": 1,
                "state": 2,
                "nodes": [
                  {
                    "deploy_id": 49,
                    "running": null,
                    "vm_info": {
                      "VM": {
                        "ID": "49",
                        "UID": "0",
                        "GID": "0",
                        "UNAME": "oneadmin",
                        "GNAME": "oneadmin",
                        "NAME": "master_0_(service_21)"
                      }
                    }
                  }
                ]
              },
              {
                "name": "worker",
                "cardinality": 1,
                "state": 2,
                "nodes": [
                  {
                    "deploy_id": 50,
                    "running": null,
                    "vm_info": {
                      "VM": {
                        "ID": "50",
                        "UID": "0",
                        "GID": "0",
                        "UNAME": "oneadmin",
                        "GNAME": "oneadmin",
                        "NAME": "worker_0_(service_21)"
                      }
                    }
                  }
                ]
              },
              {
                "name": "storage",
                "cardinality": 1,
                "state": 2,
                "nodes": [
                  {
                    "deploy_id": 51,
                    "running": null,
                    "vm_info": {
                      "VM": {
                        "ID": "51",
                        "UID": "0",
                        "GID": "0",
                        "UNAME": "oneadmin",
                        "GNAME": "oneadmin",
                        "NAME": "storage_0_(service_21)"
                      }
                    }
                  }
                ]
              }
            ]
          }
        }
        JSON
        @vms = []
        @vms << JSON.parse(<<~JSON)
        {
          "VM": {
            "NAME": "master_0_(service_21)",
            "ID": "49",
            "STATE": "3",
            "LCM_STATE": "3",
            "USER_TEMPLATE": {
              "INPUTS_ORDER": "ONEAPP_K8S_ADDRESS,ONEAPP_K8S_TOKEN,ONEAPP_K8S_HASH,ONEAPP_K8S_NODENAME,ONEAPP_K8S_PORT,ONEAPP_K8S_TAINTED_MASTER,ONEAPP_K8S_PODS_NETWORK,ONEAPP_K8S_ADMIN_USERNAME,ONEAPP_K8S_METALLB_RANGE,ONEAPP_K8S_METALLB_CONFIG",
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
        }
        JSON
        @vms << JSON.parse(<<~JSON)
        {
          "VM": {
            "NAME": "worker_0_(service_21)",
            "ID": "50",
            "STATE": "3",
            "LCM_STATE": "3",
            "USER_TEMPLATE": {
              "INPUTS_ORDER": "ONEAPP_K8S_ADDRESS,ONEAPP_K8S_TOKEN,ONEAPP_K8S_HASH,ONEAPP_K8S_NODENAME,ONEAPP_K8S_PORT,ONEAPP_K8S_TAINTED_MASTER,ONEAPP_K8S_PODS_NETWORK,ONEAPP_K8S_ADMIN_USERNAME,ONEAPP_K8S_METALLB_RANGE,ONEAPP_K8S_METALLB_CONFIG",
              "READY": "YES",
              "ROLE_NAME": "worker",
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
                  "IP": "172.20.0.101",
                  "MAC": "02:00:ac:14:00:65",
                  "NAME": "_NIC0",
                  "NETWORK": "service"
                }
              ],
              "NIC_ALIAS": []
            }
          }
        }
        JSON
        @vms << JSON.parse(<<~JSON)
        {
          "VM": {
            "NAME": "storage_0_(service_21)",
            "ID": "51",
            "STATE": "3",
            "LCM_STATE": "3",
            "USER_TEMPLATE": {
              "INPUTS_ORDER": "ONEAPP_K8S_ADDRESS,ONEAPP_K8S_TOKEN,ONEAPP_K8S_HASH,ONEAPP_K8S_NODENAME,ONEAPP_K8S_PORT,ONEAPP_K8S_TAINTED_MASTER,ONEAPP_K8S_PODS_NETWORK,ONEAPP_K8S_ADMIN_USERNAME,ONEAPP_K8S_METALLB_RANGE,ONEAPP_K8S_METALLB_CONFIG",
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
        JSON
    end
    it 'should return all vms belonging to svc' do
        allow(self).to receive(:onegate_service_show).and_return(@svc)
        allow(self).to receive(:onegate_vm_show).and_return(*@vms)
        expect(all_vms_show.map { |item| item['VM']['TEMPLATE']['NIC'][0]['IP'] }).to eq ['172.20.0.100', '172.20.0.101', '172.20.0.102']
    end
end

RSpec.describe 'master_vms_show' do
    before do
        @svc = JSON.parse(<<~JSON)
        {
          "SERVICE": {
            "name": "asd",
            "id": "4",
            "state": 10,
            "roles": [
              {
                "name": "vnf",
                "cardinality": 1,
                "state": 2,
                "nodes": [
                  {
                    "deploy_id": 12,
                    "running": null,
                    "vm_info": {
                      "VM": {
                        "ID": "12",
                        "UID": "0",
                        "GID": "0",
                        "UNAME": "oneadmin",
                        "GNAME": "oneadmin",
                        "NAME": "vnf_0_(service_4)"
                      }
                    }
                  }
                ]
              },
              {
                "name": "master",
                "cardinality": 3,
                "state": 10,
                "nodes": [
                  {
                    "deploy_id": 13,
                    "running": null,
                    "vm_info": {
                      "VM": {
                        "ID": "13",
                        "UID": "0",
                        "GID": "0",
                        "UNAME": "oneadmin",
                        "GNAME": "oneadmin",
                        "NAME": "master_0_(service_4)"
                      }
                    }
                  },
                  {
                    "deploy_id": 14,
                    "running": null,
                    "vm_info": {
                      "VM": {
                        "ID": "14",
                        "UID": "0",
                        "GID": "0",
                        "UNAME": "oneadmin",
                        "GNAME": "oneadmin",
                        "NAME": "master_1_(service_4)"
                      }
                    }
                  },
                  {
                    "deploy_id": 15,
                    "running": null,
                    "vm_info": {
                      "VM": {
                        "ID": "15",
                        "UID": "0",
                        "GID": "0",
                        "UNAME": "oneadmin",
                        "GNAME": "oneadmin",
                        "NAME": "master_2_(service_4)"
                      }
                    }
                  }
                ]
              },
              {
                "name": "worker",
                "cardinality": 0,
                "state": 2,
                "nodes": []
              },
              {
                "name": "storage",
                "cardinality": 0,
                "state": 2,
                "nodes": []
              }
            ]
          }
        }
        JSON
        @vms = []
        @vms << JSON.parse(<<~JSON)
        {
          "VM": {
            "NAME": "master_0_(service_4)",
            "ID": "13",
            "STATE": "3",
            "LCM_STATE": "3",
            "USER_TEMPLATE": {
              "INPUTS_ORDER": "ONEAPP_K8S_PORT,ONEAPP_K8S_PODS_NETWORK,ONEAPP_K8S_METALLB_RANGE,ONEAPP_K8S_METALLB_CONFIG",
              "ONEGATE_K8S_HASH": "c74201821cb4878b6896d3284f825be738cb11dbc2c5153e88c84da0b3d3ab04",
              "ONEGATE_K8S_KEY": "146ecb3e9d8bce9f584f55b234bd2700d2a7747177fb8fd60f42a161a48e7c07",
              "ONEGATE_K8S_MASTER": "10.2.11.201",
              "ONEGATE_K8S_NODE_NAME": "oneke-ip-10-2-11-201",
              "ONEGATE_K8S_TOKEN": "ifv2c4.h8d88lzjlyl5mkod",
              "ONEGATE_LB0_IP": "10.2.11.86",
              "ONEGATE_LB0_PORT": "6443",
              "ONEGATE_LB0_PROTOCOL": "TCP",
              "ONEGATE_LB0_SERVER_HOST": "10.2.11.201",
              "ONEGATE_LB0_SERVER_PORT": "6443",
              "READY": "YES",
              "ROLE_NAME": "master",
              "SERVICE_ID": "4",
              "USER_INPUTS": {
                "ONEAPP_K8S_METALLB_CONFIG": "O|text64|Custom MetalLB config",
                "ONEAPP_K8S_METALLB_RANGE": "O|text|MetalLB IP range (default none)",
                "ONEAPP_K8S_PODS_NETWORK": "O|text|Pods network in CIDR (default 10.244.0.0/16)",
                "ONEAPP_K8S_PORT": "O|text|Kubernetes API port (default 6443)"
              }
            },
            "TEMPLATE": {
              "NIC": [
                {
                  "IP": "10.2.11.201",
                  "MAC": "02:00:0a:02:0b:c9",
                  "NAME": "_NIC0",
                  "NETWORK": "service"
                }
              ],
              "NIC_ALIAS": []
            }
          }
        }
        JSON
        @vms << JSON.parse(<<~JSON)
        {
          "VM": {
            "NAME": "master_1_(service_4)",
            "ID": "14",
            "STATE": "3",
            "LCM_STATE": "3",
            "USER_TEMPLATE": {
              "INPUTS_ORDER": "ONEAPP_K8S_PORT,ONEAPP_K8S_PODS_NETWORK,ONEAPP_K8S_METALLB_RANGE,ONEAPP_K8S_METALLB_CONFIG",
              "ONEGATE_K8S_NODE_NAME": "oneke-ip-10-2-11-202",
              "ONEGATE_LB0_IP": "10.2.11.86",
              "ONEGATE_LB0_PORT": "6443",
              "ONEGATE_LB0_PROTOCOL": "TCP",
              "ONEGATE_LB0_SERVER_HOST": "10.2.11.202",
              "ONEGATE_LB0_SERVER_PORT": "6443",
              "READY": "YES",
              "ROLE_NAME": "master",
              "SERVICE_ID": "4",
              "USER_INPUTS": {
                "ONEAPP_K8S_METALLB_CONFIG": "O|text64|Custom MetalLB config",
                "ONEAPP_K8S_METALLB_RANGE": "O|text|MetalLB IP range (default none)",
                "ONEAPP_K8S_PODS_NETWORK": "O|text|Pods network in CIDR (default 10.244.0.0/16)",
                "ONEAPP_K8S_PORT": "O|text|Kubernetes API port (default 6443)"
              }
            },
            "TEMPLATE": {
              "NIC": [
                {
                  "IP": "10.2.11.202",
                  "MAC": "02:00:0a:02:0b:ca",
                  "NAME": "_NIC0",
                  "NETWORK": "service"
                }
              ],
              "NIC_ALIAS": []
            }
          }
        }
        JSON
        @vms << JSON.parse(<<~JSON)
        {
          "VM": {
            "NAME": "master_2_(service_4)",
            "ID": "15",
            "STATE": "3",
            "LCM_STATE": "3",
            "USER_TEMPLATE": {
              "INPUTS_ORDER": "ONEAPP_K8S_PORT,ONEAPP_K8S_PODS_NETWORK,ONEAPP_K8S_METALLB_RANGE,ONEAPP_K8S_METALLB_CONFIG",
              "ONEGATE_K8S_NODE_NAME": "oneke-ip-10-2-11-203",
              "ONEGATE_LB0_IP": "10.2.11.86",
              "ONEGATE_LB0_PORT": "6443",
              "ONEGATE_LB0_PROTOCOL": "TCP",
              "ONEGATE_LB0_SERVER_HOST": "10.2.11.203",
              "ONEGATE_LB0_SERVER_PORT": "6443",
              "READY": "YES",
              "ROLE_NAME": "master",
              "SERVICE_ID": "4",
              "USER_INPUTS": {
                "ONEAPP_K8S_METALLB_CONFIG": "O|text64|Custom MetalLB config",
                "ONEAPP_K8S_METALLB_RANGE": "O|text|MetalLB IP range (default none)",
                "ONEAPP_K8S_PODS_NETWORK": "O|text|Pods network in CIDR (default 10.244.0.0/16)",
                "ONEAPP_K8S_PORT": "O|text|Kubernetes API port (default 6443)"
              }
            },
            "TEMPLATE": {
              "NIC": [
                {
                  "IP": "10.2.11.203",
                  "MAC": "02:00:0a:02:0b:cb",
                  "NAME": "_NIC0",
                  "NETWORK": "service"
                }
              ],
              "NIC_ALIAS": []
            }
          }
        }
        JSON
    end
    it 'should return all vms belonging to the master role' do
        allow(self).to receive(:onegate_service_show).and_return(@svc)
        allow(self).to receive(:onegate_vm_show).and_return(*@vms)
        expect(master_vms_show.map { |item| item['VM']['TEMPLATE']['NIC'][0]['IP'] }).to eq ['10.2.11.201', '10.2.11.202', '10.2.11.203']
    end
end

RSpec.describe 'external_ipv4s' do
    it 'should return list of ipv4 addresses' do
        allow(self).to receive(:onegate_vm_show).and_return JSON.parse <<~JSON
        {
          "VM": {
            "TEMPLATE": {
              "NIC": [
                {
                  "IP": "172.20.0.100",
                  "MAC": "02:00:ac:14:00:64",
                  "NAME": "_NIC0",
                  "NETWORK": "service"
                }
              ]
            }
          }
        }
        JSON
        allow(self).to receive(:ip_addr_show).and_return JSON.parse <<~JSON
        [
          {
            "ifindex": 1,
            "ifname": "lo",
            "flags": [
              "LOOPBACK",
              "UP",
              "LOWER_UP"
            ],
            "mtu": 65536,
            "qdisc": "noqueue",
            "operstate": "UNKNOWN",
            "group": "default",
            "txqlen": 1000,
            "link_type": "loopback",
            "address": "00:00:00:00:00:00",
            "broadcast": "00:00:00:00:00:00",
            "addr_info": [
              {
                "family": "inet",
                "local": "127.0.0.1",
                "prefixlen": 8,
                "scope": "host",
                "label": "lo",
                "valid_life_time": 4294967295,
                "preferred_life_time": 4294967295
              },
              {
                "family": "inet6",
                "local": "::1",
                "prefixlen": 128,
                "scope": "host",
                "valid_life_time": 4294967295,
                "preferred_life_time": 4294967295
              }
            ]
          },
          {
            "ifindex": 2,
            "ifname": "eth0",
            "flags": [
              "BROADCAST",
              "MULTICAST",
              "UP",
              "LOWER_UP"
            ],
            "mtu": 1500,
            "qdisc": "pfifo_fast",
            "operstate": "UP",
            "group": "default",
            "txqlen": 1000,
            "link_type": "ether",
            "address": "02:00:ac:14:00:64",
            "broadcast": "ff:ff:ff:ff:ff:ff",
            "addr_info": [
              {
                "family": "inet",
                "local": "172.20.0.100",
                "prefixlen": 24,
                "broadcast": "172.20.0.255",
                "scope": "global",
                "label": "eth0",
                "valid_life_time": 4294967295,
                "preferred_life_time": 4294967295
              },
              {
                "family": "inet6",
                "local": "fe80::acff:fe14:64",
                "prefixlen": 64,
                "scope": "link",
                "valid_life_time": 4294967295,
                "preferred_life_time": 4294967295
              }
            ]
          },
          {
            "ifindex": 3,
            "ifname": "docker0",
            "flags": [
              "NO-CARRIER",
              "BROADCAST",
              "MULTICAST",
              "UP"
            ],
            "mtu": 1500,
            "qdisc": "noqueue",
            "operstate": "DOWN",
            "group": "default",
            "link_type": "ether",
            "address": "02:42:04:21:6f:5d",
            "broadcast": "ff:ff:ff:ff:ff:ff",
            "addr_info": [
              {
                "family": "inet",
                "local": "172.17.0.1",
                "prefixlen": 16,
                "broadcast": "172.17.255.255",
                "scope": "global",
                "label": "docker0",
                "valid_life_time": 4294967295,
                "preferred_life_time": 4294967295
              }
            ]
          }
        ]
        JSON
        expect(external_ipv4s).to eq ['172.20.0.100']
    end
end
