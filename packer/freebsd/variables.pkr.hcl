variable "appliance_name" {
  type    = string
  default = "freebsd"
}

variable "version" {
  type    = string
  default = "13"
}

variable "input_dir" {
  type = string
}

variable "output_dir" {
  type = string
}

variable "headless" {
  type    = bool
  default = false
}

variable "freebsd" {
  type = map(map(string))

  default = {
    "12" = {
      iso_url      = "https://download.freebsd.org/ftp/releases/amd64/amd64/ISO-IMAGES/12.4/FreeBSD-12.4-RELEASE-amd64-disc1.iso"
      iso_checksum = "file:https://download.freebsd.org/ftp/releases/amd64/amd64/ISO-IMAGES/12.4/CHECKSUM.SHA256-FreeBSD-12.4-RELEASE-amd64"
    }

    "13" = {
      iso_url      = "https://download.freebsd.org/ftp/releases/amd64/amd64/ISO-IMAGES/13.2/FreeBSD-13.2-RELEASE-amd64-disc1.iso"
      iso_checksum = "file:https://download.freebsd.org/ftp/releases/amd64/amd64/ISO-IMAGES/13.2/CHECKSUM.SHA256-FreeBSD-13.2-RELEASE-amd64"
    }

    "14" = {
      iso_url      = "https://download.freebsd.org/ftp/releases/amd64/amd64/ISO-IMAGES/14.0/FreeBSD-14.0-RELEASE-amd64-disc1.iso"
      iso_checksum = "file:https://download.freebsd.org/ftp/releases/amd64/amd64/ISO-IMAGES/14.0/CHECKSUM.SHA256-FreeBSD-14.0-RELEASE-amd64"
    }
  }
}

variable "boot_cmd" {
  type = map(list(string))

  default = {
    "12" = [
      "I<wait>",       # Welcome: Install
      "<enter><wait>", # Keymap Selection: Continue with default

      "localhost", # Set hostname
      "<enter><wait>",

      "<enter><wait>", # Distribution Select, OK

      "<enter><wait>",                             # Partitioning Auto (UFS)
      "E<wait>",                                   # Entire Disk
      "G<enter><wait>",                            # GPT
      "<down><down><down>D<wait>",                 # Delete swap partition
      "M<wait>",                                   # Modify second partition
      "<tab><tab><down><down>rootfs<enter><wait>", # Set rootfs label on root partition
      "F<wait>",                                   # Finish
      "C<wait>",                                   # Commit

      "<wait5m>",

      "opennebula<enter><wait>", # Root password
      "opennebula<enter><wait>",

      "<enter><wait>", # Network Configuration vtnet0
      "Y<wait>",       # IPv4 yes
      "Y<wait10>",     # DHCP yes
      "N<wait>",       # IPv6 no
      "<enter><wait>", # Resolver configuration

      "0<enter><wait>", # Time Zone Selector: UTC + Time&Date
      "Y<wait>",        # Confirm
      "S<wait>",        # Skip date
      "S<wait>",        # Skip time

      "<enter><wait>",    # System Configuration, OK
      "<enter><wait>",    # System Hardening, OK
      "N<wait>",          # Add User Accounts, no
      "E<enter><wait10>", # Final Configuration, Exit

      "Y<wait>", # Manual configuration, Yes
      "sed -i '' -e 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config<enter><wait>",
      "sed -i '' -e 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config<enter><wait>",
      "sed -i '' -e 's/^.*\\([[:space:]]\\/[[:space:]]\\)/\\/dev\\/gpt\\/rootfs\\1/' /etc/fstab<enter><wait>",
      "sync<enter>exit<enter><wait>",
      "R<wait10>" # Complete: Reboot
    ]

    "13" = [
      "I<wait>",       # Welcome: Install
      "<enter><wait>", # Keymap Selection: Continue with default

      "localhost", # Set hostname
      "<enter><wait>",

      "<enter><wait>", # Distribution Select

      "<down><enter><wait>",                       # Partitioning, Auto (UFS)
      "E<wait>",                                   # Entire Disk
      "G<enter><wait>",                            # GPT
      "<down><down><down>D<wait>",                 # Delete swap partition
      "M<wait>",                                   # Modify second partition
      "<tab><tab><down><down>rootfs<enter><wait>", # Set rootfs label on root p.
      "F<wait>",                                   # Finish
      "C<wait>",                                   # Commit
      "<wait2m30s>",                               # Wait for base install

      "opennebula<enter><wait>", # Root password
      "opennebula<enter><wait>",

      "<enter><wait>", # Network, vtnet0
      "Y<wait>",       # IPv4 yes
      "Y<wait10>",     # DHCP yes
      "N<wait>",       # IPv6 no
      "<enter><wait>", # Resolver configuration

      "0<enter><wait>", # Time zone selector
      "Y<wait>",        # UTC
      "S<wait>",        # Skip date
      "S<wait>",        # Skip time

      "<enter><wait>", # System Configuration, OK
      "<enter><wait>", # System Hardening, OK

      "N<wait>",          # Add User Accounts, no
      "E<enter><wait10>", # Final Configuration, exit
      "Y<wait>",          # Yes

      # Manual Configuration
      "sed -i '' -e 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config<enter><wait>",
      "sed -i '' -e 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config<enter><wait>",
      "sed -i '' -e 's/^.*\\([[:space:]]\\/[[:space:]]\\)/\\/dev\\/gpt\\/rootfs\\1/' /etc/fstab<enter><wait>",
      "sync<enter>exit<enter><wait>",

      "R<wait10>" # Complete: Reboot
    ]

    "14" = [
      "I<wait>",       # Welcome: Install
      "<enter><wait>", # Keymap Selection: Continue with default

      "localhost",     # Set hostname
      "<enter><wait>",

      "<enter><wait>", # Distribution Select

      "<down><enter><wait>",                       # Partitioning, Auto (UFS)
      "E<wait>",                                   # Entire Disk
      "G<enter><wait>",                            # GPT
      "<down><down><down>D<wait>",                 # Delete swap partition
      "M<wait>",                                   # Modify second partition
      "<down><down><down>rootfs<tab><enter>",      # Set rootfs label on root p.
      "F<wait>",                                   # Finish
      "C<wait>",                                   # Commit
      "<wait2m30s>",                               # Wait for base install

      "opennebula<enter><wait>", # Root password
      "opennebula<enter><wait>",

      "<enter><wait>", # Network, vtnet0
      "Y<wait>",       # IPv4 yes
      "Y<wait10>",     # DHCP yes
      "N<wait>",       # IPv6 no
      "<enter><wait>", # Resolver configuration

      "11<enter><wait>", # Time zone selector
      "Y<wait>",        # UTC
      "S<wait>",        # Skip date
      "S<wait>",        # Skip time

      "<enter><wait>", # System Configuration, OK
      "<enter><wait>", # System Hardening, OK

      "N<wait>",          # Add User Accounts, no
      "E<enter><wait10>", # Final Configuration, exit
      "Y<wait>",          # Yes

      # Manual Configuration
      "sed -i '' -e 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config<enter><wait>",
      "sed -i '' -e 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config<enter><wait>",
      "sed -i '' -e 's/^.*\\([[:space:]]\\/[[:space:]]\\)/\\/dev\\/gpt\\/rootfs\\1/' /etc/fstab<enter><wait>",
      "sync<enter>exit<enter><wait>",

      "R<wait10>" # Complete: Reboot
    ]
  }
}
