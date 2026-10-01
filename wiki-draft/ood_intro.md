# Overview

[Open OnDemand](https://openondemand.org/) is a web portal for HPC clusters. Users log in from a browser to manage their files, submit and watch jobs, open a terminal and start interactive apps such as Jupyter.

The **Open OnDemand** appliance runs only the portal, in one VM. It connects to one or more Slurm clusters deployed with the [OneSlurm appliance](slurm_intro). The portal runs no Slurm of its own. It sends the Slurm commands of each user to the controller of the cluster over SSH.

## How It Works

* Users log in with their account in the LDAP directory of the clusters.
* The homes of the users come from the same NFS export that the clusters mount.
* Each cluster is a `name:IP` pair in the wizard, with the IP of its controller.
* Jobs, the terminal and interactive sessions reach the clusters over SSH, with a key that the portal creates for each user in the shared home.

## Requirements

* OpenNebula 7.4.
* One or more OneSlurm clusters that use the same LDAP directory and the same NFS home (`ONEAPP_SLURM_NFS_HOME`).
* A virtual network that reaches the controllers and the nodes of the clusters.
* OneGate, to see the address of the portal in the VM attributes.

The Marketplace template creates a VM with 2 CPUs, 4 GB of memory and a 10 GB disk. Add memory for many users.

## Release Notes

### 7.4.0-0

* First release, with Open OnDemand 4.2 on Ubuntu 26.04.
* Files, jobs, terminal and the Jupyter app on OneSlurm clusters.
