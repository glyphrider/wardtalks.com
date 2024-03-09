---
title: "NixOS"
date: 2024-03-08T17:17:21-05:00
draft: true
---
# Introduction

Get started with [NixOS](https://nixos.org/).

# NixOS GNOME Installer

Download the installer from [here](https://channels.nixos.org/nixos-23.11/latest-nixos-gnome-x86_64-linux.iso).

# A More Complicated Install

Download the installer from [here](https://channels.nixos.org/nixos-23.11/latest-nixos-minimal-x86_64-linux.iso).

## LUKS Encryption with Btrfs subvolumes

## LVM on LUKS

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

## LUKS on LVM

Partition and format the disk. The example code uses `/dev/sda`,
but you might be using `/dev/nvme0n1` (for PCIe NVME drives)
or `/dev/vda` (for virtio disks).

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
      luks.devices.btrfs = {
        device = "/dev/disk/by-uuid/3348173a-e1dc-44ef-aeb8-cb263273719b";
        preLVM = false;
      };
      services.lvm.enable = true;
    };
  };
```

Adding encrypted swap.

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


```
#!/usr/bin/env bash

device=$1
mount=$2

echo "Setting up zpool on device ${device}"
echo "Mounting filesystems to mountpoint ${mount}"
echo "creating pool"
zpool create -O encryption=on -O keyformat=passphrase -O keylocation=prompt \
    -O compression=on -O mountpoint=none -O xattr=sa -O acltype=posixacl \
    -o ashift=12 -f zpool ${device}
echo "creating datasets"
for ds in {root,nix,var,home}
do
	zfs create -o mountpoint=legacy zpool/${ds}
done
echo "mounting root dataset"
mount -t zfs zpool/root ${mount}
echo "mounting remaining datasets"
for ds in {nix,var,home}
do
        mkdir -pv ${mount}/${ds}
	mount -t zfs zpool/${ds} ${mount}/${ds}
done
echo "zpool status"
zpool status
```

Add the following to configuration.nix
```
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    zfsSupport = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
    mirroredBoots = [
      { devices = [ "nodev" ]; path = "/boot"; }
    ];
  };
  boot.loader.efi.canTouchEfiVariables = false;

  networking.hostId = "00000000";
```

