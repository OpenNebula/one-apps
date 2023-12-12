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

### context-windows packages build
* latest [msitools](https://wiki.gnome.org/msitools)
* binary [nssm.exe](https://nssm.cc/) [present]
* binary [rhsrvany.exe](https://github.com/rwmjones/rhsrvany) [optional]
* mkisofs


## Details

Appliances are built using the [Packer.io](https://www.packer.io/) from the templates.

Due to the number of differences each distribution has its own Packer template located in
[packer directory](https://github.com/OpenNebula/one-apps/tree/master/packer).

Different versions of the same distribution (e.g. [Debian 10, 11 and 12](https://github.com/OpenNebula/one-apps/blob/master/packer/debian/debian.pkr.hcl))
share the same Packer template and the version is passed to Packer via parameter.

Should the distribution have some kind of "cloud" image we aim to use it as an entry point and boot it (using cloud-init)
in Packer [Qemu Builder](https://developer.hashicorp.com/packer/integrations/hashicorp/qemu/latest/components/builder/qemu).
For distribution that lacks "cloud" images, we use the default one and run the installer.

The main step in this stage is to install one-context packages, apart from that we also try to update the packages and remove
potentially unnecessary things.

Next step is [post-processing](https://github.com/OpenNebula/one-apps/blob/master/packer/postprocess.sh) in Packer in which we run
[virt-sysprep](https://www.libguestfs.org/virt-sysprep.1.html) and [virt-sparsify](https://www.libguestfs.org/virt-sparsify.1.html).

As a last step the image is compressed using the `qemu-img convert -c` (although image compression is an option for Packer itself,
it turned out that adding this as a last separate step producess smaller images).

Packer builds are orchestrated by a simple [Makefile](https://github.com/OpenNebula/one-apps/tree/master/Makefile)
and most of the configuration is in [Makefile.config](https://github.com/OpenNebula/one-apps/tree/master/Makefile.config).

For local-only changes `Makefile.local` could be added with debugging options or additional distributions.


## History

Previously, OpenNebula had 2 different repositories containing contextualization packages
* [addon-contet-linux](https://github.com/OpenNebula/addon-context-linux)
* [addon-contet-windows](https://github.com/OpenNebula/addon-context-windows)

Both of them were merged here, together with the image-building tools. Original repositories will be archived later, please use this one for reporting issues
