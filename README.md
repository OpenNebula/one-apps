# OpenNebula Apps

The OpenNebula Apps project offers a comprehensive suite of tools to construct specialized appliances tailored for your OpenNebula cloud environment. Within this repository, you'll find:

* Contextualization packages designed for both Linux and Windows operating systems. These packages facilitate seamless integration of VM guests with OpenNebula by configuring networking, user accounts, SSH keys, and enabling the execution of custom startup scripts, among various other operations.
* Packer build scripts crafted to generate contextualized qcow2 disk images compatible with a variety of standard Linux OS distributions.
* The Virtual Router (VR) appliance, delivering multiple virtualized network functions (VNFs) to enhance network operations within your cloud setup.
* The OneKE appliance, streamlining the deployment of a Kubernetes platform, ensuring a more efficient and optimized experience.

The artifacts built through the OpenNebula Apps project are regularly published on the OpenNebula Marketplace, allowing you to [download them instantly](https://marketplace.opennebula.io/).

Previously, OpenNebula Team maintained two different repositories for the Linux and Windows contextualization packages:
* [addon-context-linux](https://github.com/OpenNebula/addon-context-linux)
* [addon-context-windows](https://github.com/OpenNebula/addon-context-windows)

Both of them were merged here, together with the image building tools. The original repositories has been archived, please use this one to get the latest release or to report any issues.

## Documentation
[Documentation for one-apps is in the project Wiki](https://github.com/OpenNebula/one-apps/wiki)

For a quick start, please read the [requirements](https://github.com/OpenNebula/one-apps/wiki/tool_reqs) and the [usage reference](https://github.com/OpenNebula/one-apps/wiki/tool_use).

## Contributing

* Guidelines
* [Development and issue tracking](https://github.com/OpenNebula/one-apps/issues).
* [Community Forum](https://forum.opennebula.io/c/development/one-apps).

## Contact Information

* [OpenNebula web site](https://opennebula.io).
* [Enterprise Services](https://opennebula.io/enterprise).

## License

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

## Author Information

Copyright 2002-2025, OpenNebula Project, OpenNebula Systems

## Contributors

The Linux contextualization package has benefited immensely from incredible contributions by numerous developers. We extend our thanks to: [Th0masL](https://github.com/Th0masL), [baby-gnu](https://github.com/baby-gnu), [Moin](https://github.com/5u623l20), [Remy Zandwijk](https://github.com/rpmzandwijk), [Sergio Milanese](https://github.com/openmilanese), Alexandre Derumier, Andrei Kvapil, Deyan Chepishev, and Daniel Dehennin.

The Windows contextualization package is largely based upon the work by André Monteiro and Tiago Batista in the [DETI/IEETA Universidade de Aveiro](http://www.ua.pt/). The original guide is available here: [OpenNebula - IEETA](http://wiki.ieeta.pt/wiki/index.php/OpenNebula).

## Acknowledgements

Some of the appliances included in this repository have been made possible through the funding of the following innovation project: [ONEedge5G](https://opennebula.io/innovation/oneedge5g/).
