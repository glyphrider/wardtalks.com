---
title: "NixOS"
date: 2024-03-12T12:00:00-04:00
draft: false
---
# Introduction

Get started with [NixOS](https://nixos.org/). NixOS is a _unique_ Linux Distribution. Traditional Linux distros install a single version
of a library or an application into the accepted _filesystem hierarchy_ (e.g. /bin, /lib, /usr/bin, /usr/lib, etc.). NixOS uses the
`nix` package manager to install everything into the /nix/store, and then creates links to interconnect the currently chosen packages.

This allows for an amazing rollback option, since every change to the build creates an entirely new configuration, and old configurations
_can be_ left on the system for as long as you'd like. This has some throwbacks to Microsoft's System Restore Points (the major difference
being that nix seems to actually work).

# NixOS GNOME Installer

Download the installer from [here](https://channels.nixos.org/nixos-23.11/latest-nixos-gnome-x86_64-linux.iso). This is a traditional
Calamares installer running on a GNOME Live-CD. There is one caveat, if you are using a laptop: The installer will automatically launch
before you have a chance to establish wi-fi connectivity; it will complain, not allowing you to proceed, but will never detect the
presence of the internet after that. The installer will need to be stopped and restarted after wi-fi is connected. Sorry about that.

There is also a KDE-based Live-CD which is identical, aside from the underlying desktop manager.

# A More Complicated Install

Download the **minimal** installer from [here](https://channels.nixos.org/nixos-23.11/latest-nixos-minimal-x86_64-linux.iso).

As a recovering Arch user, this is where I'm most comfortable because here I have actual control over the disk layout supporting my
installation. I have options not available in the Calamares installer. The Calamares installer will offer the option of LUKS
encryption for your files, but will only be able to create a single ext4 filesystem on the decrypted device. There is no ability
to use LVM (either on or under LUKS), or to use btrfs to supply volumes on top of LUKS, or to do something _truly nutty_ like ZFS.

Unlike Arch, the installer throws you to a prompt as an **unprivleged** user! First things first, `sudo su -`. You can't get anything
useful done unless you are root!

Just like Arch, the first challenge is getting the installer _online_ with commandline only tools. The method of choice here is
`wpa_supplicant`. You will need to start it up with `systemctl start wpa_supplicant` and then enter `wpa_cli`. Here instructions
are at a premium, but the process is straightforward.

1. create a new network configuration with `add_network`; this will return the network number (0 _zero_) which will be used below
1. identify the SSID you want with `set_network 0 ssid "TheNameOfYourSSID"` (replacing TheNameOfYourSSID with the actual name of
your SSID)
1. provide the wi-fi key with `set_network 0 psk "YourWifiPassphrase"` (replacing YourWifiPassphrase with your actuall wi-fi passphrase)
1. then finish with `enable_network 0`

Wait for the wpa_supplicant to report CONNECTED in the output, then you can `exit` the wpa_cli. At this point, the dhcp client should
take over and get you and address, gateway, nameserver, etc. There is sometimes a short delay while this is happening. Checking with
`ip a` should let you know when you have an address and are ready to proceed.

Below are my formulae for setting this up. All these examples use GRUB on UEFI, but should be just as easily implemented on legacy
(BIOS) hardware by either creaing a 1M BIOS Boot partition in the GPT, or by using a DOS partition table. Additionally, all examples
leverage a legacy SCSI/SATA drive (/dev/sda), instead of a more modern PCIe NVME drive (/dev/nvme0n1); the most notable difference
is that the SCSI driver merely appends the partition number to the end of the device name (e.g. /dev/sda1) whereas the newer driver
adds a "p" because the device name already ends in a digit (e.g. /dev/nvme0n1p1).

**NB** --> You might want to enable one of the networking packages before installing and rebooting,
especially if you are using wi-fi.
NetworkManager is the obvious choice if you are going to be using any of the graphical desktops
(though you might want to familiarize yourself with nmcli, if you're holding off on the actual desktop setup);
the other option is to use wpa_supplicant, like the minimal installer did.
But, by default, neither of these will be included in your installation
without uncommenting a line from the generated configuration.nix file.

## LUKS Encryption with Btrfs subvolumes

This scenario is the closest to what we can get with the Calamares installer. We will encrypt a single partition and put a single
filesystem on the decrypted volume. However, we will make use to btrfs subvolumes to make our installation more interesting. So,
the partitioning is pretty straightforward.

```
parted /dev/sda -- mktable gpt
parted /dev/sda -- mkpart fat32 1M 512M
parted /dev/sda -- set 1 esp on
parted /dev/sda -- mkpart linux 512M 100%
```

The next step is to create the LUKS encrypted volume (on /dev/sda2) and to get it decrypted to /dev/mapper/crypt.
The use of the name crypt is arbitrary. You can use any name you'd like; just be sure to update any reference to crypt and
/dev/mapper/crypt to use your name.

```
cryptsetup luksFormat /dev/sda2
cryptsetup open /dev/sda2 crypt
```

The formatting is a little _special_ since we incorporate the creation of btrfs subvolumes into this step. To do this, we mount the
btrfs filesystem and use the btrfs tooling to create the subvolumes; the we unmount the btrfs filesystem, so it can be remounted
appropriately (using those subvolumes we created).

```
mkfs.fat -F 32 /dev/sda1
mkfs.btrfs /dev/mapper/crypt
mount /dev/mapper/crypt /mnt
for sv in @{,nix,var,home}; do
  btrfs subv create /mnt/$sv
done
umount /mnt
```

Now it's time to get everything mounted, and kick off the install.

```
mount -o subvol=@ /dev/mapper/crypt /mnt
for sv in {nix,var,home}; do
  mount --mkdir -o subvol=@$sv /dev/mapper/crypt /mnt/$sv
done
mount --mkdir -o umask=0077 /dev/sda1 /mnt/boot

nixos-generate-config --root /mnt
```

Due to the simplicity of the configuration (read: its similarity to what the Calamares installer can do), there isn't any special
configuration to get this to work. All the magic for the LUKS encryption and the brtfs filesystems should be in
/mnt/etc/nixos/hardware-configuration.nix.

With this configuration is in place, now is the time to confirm that you have enabled a networking package, and that you have done
any additional NixOS configuration you'd like to do.

Then install (you will be prompted for a root password) and reboot. Then enjoy!

```
nixos-install
reboot
```

## LVM on LUKS

This scenario involves creating a single encrypted partition, and using the decrypted device as a physical volume for LVM.
In this configuration, we can have multiple filesystems (logical volumes) all tied to a single encrypted volume.
Begin by partitioning the disk with

```
parted /dev/sda -- mktable gpt
parted /dev/sda -- mkpart fat32 1M 512M
parted /dev/sda -- set 1 esp on
parted /dev/sda -- mkpart linux 512M 100%
```

Now we can format the EFI partition (/dev/sda1) and use `cryptsetup` to encrypt /dev/sda2; follow the prompts for cryptsetup.
In the final line, we open the encrypted partition and create named device (crypt) which will be at /dev/mapper/crypt. This is
where we will begin our LVM work.

```
mkfs.fat -F 32 /dev/sda1
cryptsetup luksFormat /dev/sda2
cryptsetup open /dev/sda2 crypt
```

Now we can use /dev/mapper/crypt as a physical volume and create a volume group (named nixos, here).

```
pvcreate /dev/mapper/crypt
vgcreate nixos /dev/mapper/crypt
```

Now we can create some logical volumes, and format them. I chose ext4, but you can use any filesystem you see fit.

```
lvcreate -L 16G -n system nixos
lvcreate -L 32G -n nix nixos
lvcreate -L 8G -n var nixos
lvcreate -L 8G -n home nixos

for lv in {system,nix,var,home}; do
  mkfs.ext4 /dev/nixos/$lv
done
```

Now comes the magical time to mount all the filesystems where we want them, and have NixOS generate an initial configuration.
We will have to update the configuration to make it work, though.

```
mount /dev/nixos/system /mnt
for lv in {nix,var,home}; do
  mount --mkdir /dev/nixos/$lv /mnt/$lv
done
mount --mkdir -o umask=0077 /dev/sda1 /mnt/boot

nixos-generate-config --root /mnt
```

Now, we need to add some carefully crafted _nix-speak_ into our newly generated /mnt/etc/nixos/configuration.nix file.
We want to find the line that says `boot.loader.systemd-boot.enable = true;` and replace it with the block below.

This will tell it to use GRUB over UEFI (instead of systemd-boot), and provide some key configuration:
1. `boot.loader.grub.enableCryptodisk = true` will allow grub to unlock the LUKS volume
1. `boot.initrd.luks.devices.crypt` identifies the name `crypt` as the decrypted volume (you can change this value if you wish)
1. `boot.initrd.luks.devices.crypt.device` identifies encrypted volume we need to decrypt, here using its UUID (you *must* change this value to the correct UUID of the /dev/sda2 partition)
1. `boot.initrd.luks.devices.crypt.preLVM = true;` tells the initrd to unlock the disk before scanning for LVM volume groups
1. `boot.initrd.services.lvm.enable = true;` tells the initrd to _do the LVM magic_

```
  boot = {
    loader = {
      systemd-boot.enable = false;
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        enableCryptodisk = true;
      };
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
    initrd = {
      luks.devices.crypt = {
        device = "/dev/disk/by-uuid/3348173a-e1dc-44ef-aeb8-cb263273719b";
        preLVM = true;
      };
      services.lvm.enable = true;
    };
  };
```

With this configuration is in place, now is the time to confirm that you have enabled a networking package, and that you have done
any additional NixOS configuration you'd like to do.

Then install (you will be prompted for a root password) and reboot. Then enjoy!

```
nixos-install
reboot
```

## LUKS on LVM

This scheme is the logical reverse of _LVM on LUKS_.
Here we setup the logical volume manager on an unencrypted partition and encrypt logical volumes, as needed.
Included here is the use of Nix's randomEncryption to create a SWAP partition (logical volume) that is dynamically encrypted with
a random key at each boot, making swap data completely unavailable (read: safe) betwwen boots.

Partition and format the disk.
This differs from previous examples only in that we tagging /dev/sda2 as a physical volume for LVM using `parted`.
Of course, we still have to do the `pvcreate` step.

```
parted /dev/sda -- mklable gpt
parted /dev/sda -- mkpart fat32 1MiB 512MiB
parted /dev/sda -- set 1 esp on
parted /dev/sda -- mkpart 512MiB 100%
parted /dev/sda -- set 2 lvm on

mkfs.fat -F 32 /dev/sda1
pvcreate /dev/sda2
```

Setup the Logical Volume Manager. Create a Volume Group named (_arbitrarily_) `nixos`.
Then we'll add a 32G Logical Volume named `crypt` for the OS and an 8G one named `swap` for the
encrypted swap.

```
vgcreate nixos /dev/sda2
lvcreate -L 32G -n crypt nixos
lvcreate -L 8G -n swap nixos
```

Now that we have a logical volume (/dev/nixos/crypt) we can use `cryptsetup` to, well, setup our encryption.

```
cryptsetup luksFormat /dev/nixos/crypt
cryptsetup open /dev/nixos/crypt system
```

Having created /dev/mapper/system, we can format (I'll use ext4 for simplicity).

```
mkfs.ext4 /dev/mapper/system

mount /dev/mapper/system /mnt
mount --mkdir -o umask=0077 /dev/sda1 /mnt/boot
```

Now we can generate the initial configuration.

```
nixos-generate-config --root /mnt
```

The following _extra_ configuration will need to go into /mnt/etc/nixos/configuration.nix, replacing the line
`boot.loader.systemd-boot.enable = true;`. Much of the explanation of this block appear in the LVM on LUKS section,
but I'll highlight the one difference

1. `boot.initrd.luks.devices.btrfs.preLVM = false;` because we want LUKS to sort itself *after* we've processed all the LVM devices

Just like the LVM on LUKS configuration, you *will need* to use the correct UUID in the device line; but this time, it's a little
simpler.

```
  boot = {
    loader = {
      systemd-boot.enable = false;
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        enableCryptodisk = true;
      };
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
    initrd = {
      luks.devices.system = {
        device = "/dev/nixos/crypt";
        preLVM = false;
      };
      services.lvm.enable = true;
    };
  };
```

Adding encrypted swap. This results in the same configuration that's outlined in the [ArchLinux Wiki](https://wiki.archlinux.org/title/dm-crypt/Encrypting_an_entire_system#LUKS_on_LVM) section 5.6 _Configuring fstab and crypttab. Of course here it's declarative, instead
of procedural.

```
  swapDevices = [
    { device = "/dev/nixos/swap";
      randomEncryption = {
        enable = true;
        cipher = "aes-xts-plain64";
        source = "/dev/urandom";
        keySize = 512;
      };
    }
  ];
```

## Encrypted ZFS

Using ZFS (with it's internal encryption) allows the best of all three of the preceding methods, but leveraging only a single
technology. That being said, ZFS on Linux is relatively niche; the understanding level is low and the number of examples is
correspondingly small.

The initial partitioning should look familiar.

```
parted /dev/sda -- mklable gpt
parted /dev/sda -- mkpart fat32 1MiB 512MiB
parted /dev/sda -- set 1 esp on
parted /dev/sda -- mkpart 512MiB 100%
```

Now we can format the /boot partition and do the ZFS magic on the second partition to create a zpool named nixos. The first three `-O`
parameters can be omitted if you do *not* want encryption.

```
mkfs.fat -F 32 /dev/sda1

zpool create -O encryption=on -O keyformat=passphrase -O keylocation=prompt \
    -O compression=on -O mountpoint=none -O xattr=sa -O acltype=posixacl \
    -o ashift=12 -f nixos /dev/sda2
```

Now, we can create ZFS _datasets_ within the zpool. Datasets are like the logical volumes of LVM (except they already have a
_filesystem_ on them).

```
for ds in {root,nix,var,home}; do
  zfs create -o mountpoint=legacy nixos/$ds
done
```

Now these datasets can be mounted for the config generation. Also, mount the /boot partition.

```
mount -t zfs nixos/root /mnt
for ds in {nix,var,home}; do
  mount --mkdir -t zfs nixos/$ds /mnt/$ds
done
mount --mkdir -o umask=0077 /dev/sda1 /mnt/boot
```

Now we can generate the initial config with

```
nixos-generate-config --root /mnt
```

And edit the config, once again replacing the `boot.loader.systemd-boot.enable = true;` line with the following.

```
  boot.loader = {
    systemd-boot.enable = false;
    grub = {
      enable = true;
      zfsSupport = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
    };
    efi = {
      canTouchEfiVariables = false;
      efiSysMountPoint = "/boot";
    };
  };

  networking.hostId = "00000000";
```

The networking.hostId is used by ZFS and should be generated with the following
[incantation](https://search.nixos.org/options?channel=23.11&show=networking.hostId).

```
head -c4 /dev/urandom | od -A none -t x4
```

FWIW, I keep my networking.hostId in a separate networking configuration (.nix); it *can* go anywhere, but you *have to* have one.

# A final word about swap space

Only one of the above examples included swap. I largely don't go in for swap,
as I seem to have enough RAM on my systems these days for whatever I want to do.
Also, these days, _all the cool kids_ are using compressed RAM swap. On Arch I used
the `zram-generator` package; on NixOS I use `zramSwap.enable = true;` in my configuration.nix file.
Feel free to add this in. It will nominally use 50% of your RAM as compressed swap.
Here's a link to some additional information about [zram](https://wiki.archlinux.org/title/Zram).

# Resources

1. [NixOS.org](https://nixos.org/) website.
1. NixOS package and configuration database [search](https://search.nixos.org/).
1. [ArchLinux Wiki](https://wiki.archlinux.org)
