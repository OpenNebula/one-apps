# OpenNebula Windows VM Contextualization

## Description

This addon provides contextualization package for the Windows
guest virtual machines running in the OpenNebula cloud. Based
on the provided contextualization parameters, the packages prepare the
networking in the running guest virt. machine, set
passwords, run custom start scripts, and many others.

## Download

Latest versions can be downloaded from the
[release page](https://github.com/OpenNebula/addon-context-windows/releases).
Check the supported OpenNebula versions for each release.

## Install

Documentation on packages installation and guest contextualization can
be found in the latest stable
[OpenNebula Operation Guide](http://docs.opennebula.org/stable/operation/vm_setup/context_overview.html).
For beta releases, refer to the latest
[development documentation](http://docs.opennebula.org/devel/operation/vm_setup/context_overview.html).

## Build own package

### Requirements

* **Linux host**
* latest [msitools](https://wiki.gnome.org/msitools)
* binary [nssm.exe](https://nssm.cc/) [present]
* binary [rhsrvany.exe](https://github.com/rwmjones/rhsrvany) [optional]
* `mkisofs`

The service manager **NSSM** is the preferred tool to manage services because
it handles long running services better and more correctly (srvany/rhsrvany
fails to terminate its child processes on stop). NSSM is in public domain and
the binary is part of this repo. There are both 32bit and 64bit versions -
currently 32bit version is used because it covers broader set of systems.

If you wish to use rhsrvany instead then you must set the shell variable
`SRV_MANAGER` to `rhsrvany` otherwise it will default to `nssm`.

On RHEL (CentOS) and Fedora systems, the required binary
[rhsrvany.exe](https://github.com/rwmjones/rhsrvany) is distributed as part
of the package `virt-v2v` and placed into `/usr/share/virt-tools/rhsrvany.exe`.
Please copy the EXE into your local repository clone before creating the MSI.

### Steps

Script `generate.sh` builds the MSI package. It's a wrapper around
the `wixl` command from `msitools`. It reads the `package.wxs`, a package
definition in the WiX-like XML format. Package name or version can be
overridden by env. variables `NAME` and `VERSION`. For example:

```
$ TARGET=msi ./generate.sh
$ NAME=one-context TARGET=msi ./generate.sh
$ VERSION=1.0.0 TARGET=msi ./generate.sh
```

New package is created as `${NAME}-${VERSION}.msi`,
e.g. `one-context-1.0.0.msi` in the `out/` directory.

You can also built both the iso and msi targets like this:

```
$ ./generate-all.sh
```

Or with a different service manager and explicit version:

```
$ env SRV_MANAGER=rhsrvany VERSION=5.13 ./generate-all.sh
```

Please ignore following assertion on package build, which is caused
by skipping the attribute `Start` in tag `ServiceControl`. The parameter
is optional in WiX specification, but the `msitools` still counts with it.
Despite that, the package is built.

```
(wixl:22764): wixl-CRITICAL **: wixl_wix_builder_install_mode_to_event: assertion 'modeString != NULL' failed
```

## Acknowledgements

This addon is largely based upon the work by André Monteiro and Tiago Batista in the [DETI/IEETA Universidade de Aveiro](http://www.ua.pt/). The original guide is available here: [OpenNebula - IEETA](http://wiki.ieeta.pt/wiki/index.php/OpenNebula)

## License

Copyright 2002-2021, OpenNebula Project, OpenNebula Systems (formerly C12G Labs)

Licensed under the Apache License, Version 2.0 (the "License"); you may
not use this file except in compliance with the License. You may obtain
a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
