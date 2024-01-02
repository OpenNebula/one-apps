# OpenNebula Apps

The OpenNebula Apps project offers a comprehensive suite of tools to construct specialized appliances tailored for your OpenNebula cloud environment. Within this repository, you'll find:

* Contextualization packages designed for both Linux and Windows operating systems. These packages facilitate seamless integration of VM guests with OpenNebula by configuring networking, user accounts, SSH keys, and enabling the execution of custom startup scripts, among various other operations.
* Packer build scripts crafted to generate contextualized qcow2 disk images compatible with a variety of standard Linux OS distributions.
* The Virtual Router (VR) appliance, delivering multiple virtualized network functions (VNFs) to enhance network operations within your cloud setup.
* The OneKE appliance, streamlining the deployment of a Kubernetes platform, ensuring a more efficient and optimized experience.

The artifacts built through the OpenNebula Apps project are regularly published on the OpenNebula Marketplace, allowing you to [download them instantly](https://marketplace.opennebula.io/).

Previously, OpenNebula Team maintained two different repositories for the Linux and Windows contextualization packages:
* [addon-contet-linux](https://github.com/OpenNebula/addon-context-linux)
* [addon-contet-windows](https://github.com/OpenNebula/addon-context-windows)

Both of them were merged here, together with the image building tools. The original repositories has been archived, please use this one to get the latest release or to report any issues.

## Contents

* Build Instructions
  * [Requirements](../../wiki/tool_reqs)
  * [Using the build tools](../../wiki/tool_use)
  * [Developer information](../../wiki/tool_dev)
* Linux Contextualization Packages
  * [Release Notes](../../wiki/linux_release)
  * [Installation](../../wiki/linux_installation)
  * [Features and usage](../../wiki/linux_feature)
  * [Context Attributes Reference](../../wiki/linux_ref)
  * [Developer information](../../wiki/linux_dev)
* Windows Contextualization Packages
  * [Release Notes](../../wiki/win_release)
  * [Installation](../../wiki/win_installation)
  * [Features and usage](../../wiki/win_feature)
  * [Context Attributes Reference](../../wiki/win_ref)
  * [Developer information](../../wiki/win_dev)
* OpenNebula Apps
  * [Overview](../../wiki/apps_intro)
  * OneKE (OpenNebula Kubernetes Edition)
    * [Release Notes](../../wiki/oneke_release)
    * [Overview](../../wiki/oneke_intro)
    * [Architecture](../../wiki/oneke_architecture)
    * [Kubernetes Components](../../wiki/oneke_components)
    * [Deploying a OneKE cluster](../../wiki/oneke_deploy)
    * [Operating OneKE](../../wiki/oneke_ops)
    * [Troubleshooting](../../wiki/oneke_troubleshoot)
  * Virtual Router
    * [Release Notes](../../wiki/vr_release)
    * [Features and usage](../../wiki/vr_feature)
  * WordPress
    * [Release Notes](../../wiki/wp_release)
    * [Features and usage](../../wiki/wp_feature)

## Contributing

* Guidelines
* [Development and issue tracking](https://github.com/OpenNebula/one-apps/issues).
* [Community Forum](https://forum.opennebula.io).

## Contact Information

* [OpenNebula web site](https://opennebula.io).
* [Enterprise Services](https://opennebula.io/enterprise).

## License

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

## Author Information

Copyright 2002-2023, OpenNebula Project, OpenNebula Systems

## Acknowledgments

* The Linux contextualization package has benefited immensely from incredible contributions by numerous developers. We extend our thanks to: [Th0masL](https://github.com/Th0masL), [baby-gnu](https://github.com/baby-gnu), [Moin](https://github.com/5u623l20), [Remy Zandwijk](https://github.com/rpmzandwijk), [Sergio Milanese](https://github.com/openmilanese), Alexandre Derumier, Andrey Kvapil, Deyan Chepishev, and Daniel Dehennin.
* The Windows contextualization package is largely based upon the work by André Monteiro and Tiago Batista in the [DETI/IEETA Universidade de Aveiro](http://www.ua.pt/). The original guide is available here: [OpenNebula - IEETA](http://wiki.ieeta.pt/wiki/index.php/OpenNebula)
