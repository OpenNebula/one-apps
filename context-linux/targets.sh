case "${TARGET}" in
    'pfsense')
        NAME=${NAME:-one-context}
        RELSUFFIX=${RELSUFFIX:-}
        TYPE=${TYPE:-freebsd}
        EXT=${EXT:-txz}
        TAGS=${TAGS:-bsd pfsense_rc one sysv}
        DEPENDS=${DEPENDS:-sudo bash curl base64}
        PROVIDES=${PROVIDES:-}
        REPLACES=${REPLACES:-addon-context}
        CONFLICTS=${CONFLICTS:-${REPLACES} one-context-ec2}
        POSTIN=${POSTINST:-pkg/postinstall.freebsd}
        PREUN=${PREUN:-}
        POSTUN=${POSTUN:-}
        POSTUP=${POSTUP:-}
        ;;


    'freebsd')
        NAME=${NAME:-one-context}
        RELSUFFIX=${RELSUFFIX:-}
        TYPE=${TYPE:-freebsd}
        EXT=${EXT:-txz}
        TAGS=${TAGS:-bsd bsd_rc one sysv crond}
        DEPENDS=${DEPENDS:-sudo bash curl base64 ruby gawk virt-what}
        PROVIDES=${PROVIDES:-}
        REPLACES=${REPLACES:-addon-context}
        CONFLICTS=${CONFLICTS:-${REPLACES} one-context-ec2}
        POSTIN=${POSTINST:-pkg/postinstall}
        PREUN=${PREUN:-}
        POSTUN=${POSTUN:-}
        POSTUP=${POSTUP:-}
        ;;

    'el8')
        NAME=${NAME:-one-context}
        RELSUFFIX=${RELSUFFIX:-.el8}
        TYPE=${TYPE:-rpm}
        TAGS=${TAGS:-linux rpm systemd one network-scripts}
        DEPENDS=${DEPENDS:-util-linux bash curl bind-utils cloud-utils-growpart parted ruby rubygem-json sudo shadow-utils openssh-server qemu-guest-agent network-scripts gawk virt-what}
        RECOMMENDS=${RECOMMENDS:-}
        PROVIDES=${PROVIDES:-}
        REPLACES=${REPLACES:-cloud-init}
        CONFLICTS=${CONFLICTS:-${REPLACES} one-context-ec2}
        POSTIN=${POSTINST:-pkg/postinstall}
        PREUN=${PREUN:-pkg/preuninstall}
        POSTUN=${POSTUN:-pkg/postuninstall}
        POSTUP=${POSTUP:-pkg/postupgrade}
        ;;

    'el9')
        NAME=${NAME:-one-context}
        RELSUFFIX=${RELSUFFIX:-.el9}
        TYPE=${TYPE:-rpm}
        TAGS=${TAGS:-linux rpm systemd one}
        DEPENDS=${DEPENDS:-util-linux bash curl bind-utils cloud-utils-growpart parted ruby rubygem-json sudo shadow-utils openssh-server qemu-guest-agent gawk virt-what}
        RECOMMENDS=${RECOMMENDS:-}
        PROVIDES=${PROVIDES:-}
        REPLACES=${REPLACES:-cloud-init}
        CONFLICTS=${CONFLICTS:-${REPLACES} one-context-ec2}
        POSTIN=${POSTINST:-pkg/postinstall}
        PREUN=${PREUN:-pkg/preuninstall}
        POSTUN=${POSTUN:-pkg/postuninstall}
        POSTUP=${POSTUP:-pkg/postupgrade}
        ;;

    'el10')
        NAME=${NAME:-one-context}
        RELSUFFIX=${RELSUFFIX:-.el10}
        TYPE=${TYPE:-rpm}
        TAGS=${TAGS:-linux rpm systemd one}
        DEPENDS=${DEPENDS:-util-linux bash curl bind-utils cloud-utils-growpart parted ruby rubygem-json sudo shadow-utils openssh-server qemu-guest-agent gawk virt-what}
        RECOMMENDS=${RECOMMENDS:-}
        PROVIDES=${PROVIDES:-}
        REPLACES=${REPLACES:-cloud-init}
        CONFLICTS=${CONFLICTS:-${REPLACES} one-context-ec2}
        POSTIN=${POSTINST:-pkg/postinstall}
        PREUN=${PREUN:-pkg/preuninstall}
        POSTUN=${POSTUN:-pkg/postuninstall}
        POSTUP=${POSTUP:-pkg/postupgrade}
        ;;

    'fc')
        NAME=${NAME:-one-context}
        RELSUFFIX=${RELSUFFIX:-.fc}
        TYPE=${TYPE:-rpm}
        TAGS=${TAGS:-linux rpm systemd one}
        DEPENDS=${DEPENDS:-util-linux bash curl bind-utils btrfs-progs cloud-utils-growpart parted ruby rubygem-json sudo shadow-utils openssh-server qemu-guest-agent gawk virt-what}
        RECOMMENDS=${RECOMMENDS:-}
        PROVIDES=${PROVIDES:-}
        REPLACES=${REPLACES:-cloud-init}
        CONFLICTS=${CONFLICTS:-${REPLACES} one-context-ec2}
        POSTIN=${POSTINST:-pkg/postinstall}
        PREUN=${PREUN:-pkg/preuninstall}
        POSTUN=${POSTUN:-pkg/postuninstall}
        POSTUP=${POSTUP:-pkg/postupgrade}
        ;;

    'amzn2')
        NAME=${NAME:-one-context}
        RELSUFFIX=${RELSUFFIX:-.amzn2}
        TYPE=${TYPE:-rpm}
        TAGS=${TAGS:-linux rpm systemd one network-scripts}
        DEPENDS=${DEPENDS:-util-linux bash curl bind-utils cloud-utils-growpart parted qemu-guest-agent ruby rubygem-json sudo shadow-utils openssh-server gawk virt-what}
        RECOMMENDS=${RECOMMENDS:-}
        PROVIDES=${PROVIDES:-}
        REPLACES=${REPLACES:-cloud-init}
        CONFLICTS=${CONFLICTS:-${REPLACES} one-context-ec2}
        POSTIN=${POSTINST:-pkg/postinstall}
        PREUN=${PREUN:-pkg/preuninstall}
        POSTUN=${POSTUN:-pkg/postuninstall}
        POSTUP=${POSTUP:-pkg/postupgrade}
        ;;

    'amzn2023')
        NAME=${NAME:-one-context}
        RELSUFFIX=${RELSUFFIX:-.amzn2023}
        TYPE=${TYPE:-rpm}
        TAGS=${TAGS:-linux rpm systemd one network-scripts}
        DEPENDS=${DEPENDS:-util-linux bash curl bind-utils cloud-utils-growpart parted ruby rubygem-json sudo shadow-utils openssh-server network-scripts gawk virt-what}
        RECOMMENDS=${RECOMMENDS:-}
        PROVIDES=${PROVIDES:-}
        REPLACES=${REPLACES:-cloud-init cloud-init-cfg-onprem}
        CONFLICTS=${CONFLICTS:-${REPLACES} one-context-ec2}
        POSTIN=${POSTINST:-pkg/postinstall}
        PREUN=${PREUN:-pkg/preuninstall}
        POSTUN=${POSTUN:-pkg/postuninstall}
        POSTUP=${POSTUP:-pkg/postupgrade}
        ;;


    'alt')
        NAME=${NAME:-one-context}
        RELSUFFIX=${RELSUFFIX:-alt}
        TYPE=${TYPE:-rpm}
        TAGS=${TAGS:-linux rpm systemd one networkd}
        DEPENDS=${DEPENDS:-bind-utils btrfs-progs cloud-utils-growpart curl e2fsprogs iproute2 openssl parted passwd qemu-guest-agent ruby-json-pure sudo systemd-services wget which xfsprogs gawk virt-what}
        PROVIDES=${PROVIDES:-}
        REPLACES=${REPLACES:-cloud-init}
        CONFLICTS=${CONFLICTS:-${REPLACES} one-context-ec2}
        POSTIN=${POSTINST:-pkg/postinstall}
        PREUN=${PREUN:-pkg/preuninstall}
        POSTUN=${POSTUN:-pkg/postuninstall}
        POSTUP=${POSTUP:-pkg/postupgrade}
        ;;


    'suse')
        NAME=${NAME:-one-context}
        RELSUFFIX=${RELSUFFIX:-.suse}
        TYPE=${TYPE:-rpm}
        TAGS=${TAGS:-linux rpm systemd one network-scripts}
        DEPENDS=${DEPENDS:-util-linux bash curl bind-utils growpart parted parted ruby sudo shadow openssh qemu-guest-agent gawk virt-what} # rubygem-json}
        PROVIDES=${PROVIDES:-}
        REPLACES=${REPLACES:-cloud-init cloud-init-config-suse}
        CONFLICTS=${CONFLICTS:-${REPLACES} one-context-ec2}
        POSTIN=${POSTINST:-pkg/postinstall}
        PREUN=${PREUN:-pkg/preuninstall}
        POSTUN=${POSTUN:-pkg/postuninstall}
        POSTUP=${POSTUP:-pkg/postupgrade}
        ;;

    'deb')
        NAME=${NAME:-one-context}
        RELSUFFIX=${RELSUFFIX:-}
        TYPE=${TYPE:-deb}
        TAGS=${TAGS:-linux deb sysv systemd upstart one}
        DEPENDS=${DEPENDS:-util-linux bash curl bind9-host cloud-utils parted ruby ifupdown|ifupdown2 acpid|systemd sudo passwd dbus openssh-server qemu-guest-agent gawk virt-what}
        PROVIDES=${PROVIDES:-}
        REPLACES=${REPLACES:-cloud-init}
        CONFLICTS=${CONFLICTS:-${REPLACES} one-context-ec2}
        POSTIN=${POSTINST:-pkg/postinstall}
        PREUN=${PREUN:-pkg/preuninstall}
        POSTUN=${POSTUN:-pkg/postuninstall}
        POSTUP=${POSTUP:-pkg/postupgrade}
        ;;

    'alpine')
        NAME=${NAME:-one-context}
        RELSUFFIX=${RELSUFFIX:-}
        TYPE=${TYPE:-apk}
        TAGS=${TAGS:-linux apk one}
        DEPENDS=${DEPENDS:-util-linux bash curl udev sfdisk parted e2fsprogs-extra sudo shadow ruby ruby-json bind-tools openssh qemu-guest-agent gawk virt-what}
        PROVIDES=${PROVIDES:-}
        REPLACES=${REPLACES:-}  #not respected
        CONFLICTS=${CONFLICTS:-one-context-ec2}
        POSTIN=${POSTINST:-pkg/postinstall}
        PREUN=${PREUN:-pkg/preuninstall}
        POSTUN=${POSTUN:-pkg/postuninstall}
        POSTUP=${POSTUP:-pkg/postupgrade}
        ;;

    'iso')
        NAME=${NAME:-one-context-linux}
        TYPE=${TYPE:-iso}
        ;;

    'arch')
        NAME=${NAME:-one-context}
        RELSUFFIX=${RELSUFFIX:-}
        TYPE=${TYPE:-pacman}
        EXT=${EXT:-pkg.tar.xz}
        TAGS=${TAGS:-linux arch systemd one networkd}
        # mkinitcpio-growrootfs ruby-json
        DEPENDS=${DEPENDS:-filesystem util-linux bash curl bind-tools ruby sudo shadow qemu-guest-agent gawk virt-what}
        PROVIDES=${PROVIDES:-}
        REPLACES=${REPLACES:-cloud-init}
        CONFLICTS=${CONFLICTS:-${REPLACES} one-context-ec2}
        POSTIN=${POSTINST:-pkg/postinstall}
        PREUN=${PREUN:-pkg/preuninstall}
        POSTUN=${POSTUN:-pkg/postuninstall}
        POSTUP=${POSTUP:-pkg/postupgrade}
        echo 'ArchLinux target is currently not maintained'
        exit 1
        ;;

    *)
        echo "Invalid target ${TARGET}"
        exit 1
esac
