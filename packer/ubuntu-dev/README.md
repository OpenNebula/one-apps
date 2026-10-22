# Ubuntu development image

Uses the same cloud images, upgrade, boot configuration, OpenNebula context,
SSH configuration, and cleanup as `packer/ubuntu`, with those files linked to
the base image scripts. The development image has a 100 GiB disk.

`20-install-build-dependencies.sh` follows the default Ubuntu tasks from
one-infra's `microenvs/ansible/roles/packages-build-dependencies`: install
`devscripts` and `equivs`, download the OpenNebula 7.4.0 source package, and
install its build dependencies with `mk-build-deps`. This includes the XML-RPC
libraries appropriate for the selected Ubuntu release. It also installs the
role's default gRPC dependencies. The optional one-apps dependencies are excluded, as in the role's
defaults. The source package must be available in the selected OpenNebula
repository for the selected Ubuntu release.

The script configures the signed OpenNebula APT repository and pins its Node.js
package, which supplies the Node.js 20 version required by the build metadata.
APT is forbidden from removing packages while resolving build dependencies,
and `dpkg-checkbuilddeps` verifies that all source build requirements are met.
The installed `opennebula-build-deps` package retains its dependencies through
the image's final `apt-get autoremove` cleanup.

Build from the repository root (context packages are generated automatically):

```sh
make ubuntu-dev2404
```

Set `opennebula_version` (default `7.4`) in `ubuntu-dev.pkr.hcl`, or override
it with Packer's `-var` option or the `PKR_VAR_opennebula_version` environment
variable. The script always uses the initial `.0` release and packaging
release `1` (`7.4` → `7.4.0-1`). The repository path also uses the `.0`
version (`repo/7.4.0`), so newer maintenance releases do not affect it.
For example:

```sh
PKR_VAR_opennebula_version=7.2 make ubuntu-dev2404
```

The local `build-common.pkr.hcl` passes these settings to the dependency script;
the shared base build configuration is unchanged.

Targets are available for `ubuntu-dev2404` and `ubuntu-dev2604` on x86_64.
Both are also included in `distros-amd64`. Ubuntu cloud image definitions
are shared with `packer/ubuntu/variables.pkr.hcl`.
