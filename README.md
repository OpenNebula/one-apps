# one-apps
Toolchain to build OpenNebula appliances

## Usage:
Run `make help`

```
Usage examples:
    make <distro>          -- build just one distro
    make <service>         -- build just one service

    make all               -- build all distros and services
    make all -j 4          -- build all in 4 parallel tasks
    make distros           -- build all distros
    make services          -- build all services

    make context-linux     -- build context linux packages
    make context-windows   -- build windows linux packages

Available distros:
    alma8 alma9 alpine316 alpine317 alpine318 alt9 alt10 amazon2
    centos7 centos8stream debian10 debian11 debian12 devuan3 devuan4
    fedora37 fedora38 freebsd12 freebsd13 ol8 ol9 opensuse15 rocky8
    rocky9 ubuntu2004 ubuntu2004min ubuntu2204 ubuntu2204min

Available services:
    service_vnf service_wordpress service_OneKE
```

### Troubleshoot
For troubleshooting add
```
PACKER_HEADLESS    := false
PACKER_LOG         := 1
```
to your `Makefile.local`

## Requirements:
### Images build
- make
- Packer >= 1.9.4
- Qemu Packer Plugin ~> 1
- cloud-utils
- qemu-img

### context-linux packages build
* Ruby >= 1.9
* gem fpm >= 1.10.0
* dpkg utils
* rpm utils

### context-linux packages build
* latest [msitools](https://wiki.gnome.org/msitools)
* binary [nssm.exe](https://nssm.cc/) [present]
* binary [rhsrvany.exe](https://github.com/rwmjones/rhsrvany) [optional]
* mkisofs
