# more information is available at
# https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Installation_Guide/sect-kickstart-syntax.html
#cmdline

# System authorization information
authconfig --enableshadow --passalgo=sha512 --enablefingerprint

# Use net installation media
url --url="https://download.rockylinux.org/pub/rocky/9/BaseOS/x86_64/os/"
repo --name="BaseOS" --baseurl="https://download.rockylinux.org/pub/rocky/9/BaseOS/x86_64/os/" --cost=100
repo --name="AppStream" --baseurl="https://download.rockylinux.org/pub/rocky/9/AppStream/x86_64/os/" --cost=100
repo --name="extras" --baseurl="https://download.rockylinux.org/pub/rocky/9/extras/x86_64/os/" --cost=100

# Run the Setup Agent on first boot
firstboot --disable

# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'

# System language
lang en_US.UTF-8

# Network information
network --bootproto=dhcp --device=enp0s3 --ipv6=auto --activate
# network  --hostname=localhost.localdomain
firewall --disabled

# Root password
rootpw --iscrypted $6$rounds=4096$2RFfXKGPKTcdF.CH$dzLlW9Pg1jbeojxRxEraHwEMAPAbpChBdrMFV1SOa6etSF2CYAe.hC1dRDM1icTOk7M4yhVS1BtwJjah9essD0
#selinux --permissive
selinux

# System services
services --disabled="kdump"
%addon com_redhat_kdump --disable
%end

# System timezone
timezone UTC --isUtc

# System bootloader configuration
bootloader --location=mbr --timeout=1
zerombr

clearpart --all --initlabel
part / --fstype ext4 --size=1024 --grow

# Reboot the machine after successful installation
reboot --eject
#poweroff

%post --erroronfail
yum -C -y remove linux-firmware
echo "PermitRootLogin yes" > /etc/ssh/sshd_config.d/01-permitrootlogin.conf
%end

%packages --ignoremissing --excludedocs
@core
#deltarpm
openssh-clients
NetworkManager
dracut-config-generic
kernel
-firewalld
-aic94xx-firmware
-alsa-firmware
-alsa-lib
-alsa-tools-firmware
-biosdevname
-iprutils
#-linux-firmware
-ivtv-firmware
-iwl100-firmware
-iwl1000-firmware
-iwl105-firmware
-iwl135-firmware
-iwl2000-firmware
-iwl2030-firmware
-iwl3160-firmware
-iwl3945-firmware
-iwl4965-firmware
-iwl5000-firmware
-iwl5150-firmware
-iwl6000-firmware
-iwl6000g2a-firmware
-iwl6000g2b-firmware
-iwl6050-firmware
-iwl7260-firmware
-iwl7265-firmware
-libertas-sd8686-firmware
-libertas-sd8787-firmware
-libertas-usb8388-firmware
-plymouth
-dracut-config-rescue
-kexec-tools
-microcode_ctl
%end
