---
layout: post
title: "chroot for Fun and Profit"
date:   2019-04-04 12:00:00 -0400
tags: [ubuntu, linux]
---
A fundamental part of a linux install, `chroot` is a powerful process isolation tool and one of
the precursors to today's container technology. In this article, I want to quickly cover the basic
incantation of chrooting an Ubuntu Linux install.

This can be used to do some cool stuff immediately _post-install_. It can also be critical to rescuing
a system that can no longere boot itself.

The general idea behind chroot is that "while booted into a running system, we can mount the
filesystem(s) of another _install_, and create a shell process that sees the second install as the
root filesystem." This is what gives us the name `chroot` (or change root). Once you have executed
`chroot` you will not have any access outside the provided root filesystem tree. This allows you
to behave as if you are live within the chrooted filesystem.

There is a lot of information on this out at Linux From Scratch, Gentoo, and Arch Linux. All of these
sites show you how to use chroot to create a new Linux installation from raw filesystems.

All you need to get started is a Linux machine, and a Live CD/USB. We will
1. Boot from the Live CD/USB
1. Mount the root filesystem of the installed system
1. Do some special mounting of some devices
1. `chroot` into the mount point
1. Do a little more special mounting
1. Mount the rest of the filesystem(s), if any
1. Have fun!

### Boot from the Live CD/USB

You don't really need help with this part, do you?

### Mounting the root filesystem of the installed device, the Short Form

In a simple installation, there's just one partition -- _the root partition_. We want to mount that onto
our /mnt point. So, let's pretend that /dev/sda is our installed disk, making /dev/sda1 our partition. We would then

```bash
mount /dev/sda1 /mnt
```

Now, we can continue on to [Do Some Special Mounting of Some Devices](#do-some-special-mounting-of-some-devices).

### Mounting the root filesystem of the installed device, the Long Form

Let's pretend that your installation was a little complicated. If it wasn't, then this part gets a
lot simpler. Let's say you created a /boot partition on /dev/sda1, but then you have the rest of you
install in LVM logical volumes that are hidden behind an encrypted /dev/sda5. Does that sound hokey
enough for you? OK. Let's roll.

Let's decrypt the filesystem on /dev/sda5. We'll create a dummy device called /dev/mapper/targetdisk,
by virtue of the final argument below. We'll be asked for the passphrase used when creating this disk.
If you don't have that passphrase, you can't continue. The disk really is safely encrypted/locked
behind that passphrase.

```bash
sudo cryptsetup luksOpen /dev/sda5 targetdisk
```

Since we concocted a _super complicated_ partitioning scheme, we're only about half-way through
mounting the root filesystem. Now we have to break out LVM2 and take things to the next level.
Step one is to find the logical volume that exists on /dev/mapper/targetdisk. The easiest way is
to use `vgscan` to scan for new volume groups.

```bash
sudo vgscan
```

Pay attention to the output, because you should see the name of a volume group from the newly
decrypted disk. We'll need that name when we activate the volume group with `vgchange`. For
purposes of this example, we'll pretend the volume group is called `ubuntu-vg`, which happens
to be the default name for volume groups created by the installer.

```bash
sudo vgchange -ay ubuntu-vg
```

We can now run `lvscan` to see all the new logical volumes that have become available to us.
It is also possible that you just know the names of the logical volumes, since it's probably
your system that you're playing with. Let's pretend you found the volume used as the root, and
it happens to be called `root-lv`. Now, we can mount that in a convenient place, like `/mnt`.

```bash
sudo mount /dev/ubuntu-vg/root-lv /mnt
```

### Do Some Special Mounting of Some Devices

This is a simple enough command. Simple enough to forget.

We want to mount the `/dev` filesystem into the `/mnt/dev` using the `--bind` option that will let
us mount one thing into two places. Any interaction with the /dev filesystem or the /mnt/dev
filesystem will be reflected in the other, because they are just two _views_ of the same thing.

```bash
sudo mount --bind /dev /mnt/dev
```

### chroot into the mount point

We're finally ready for the big show! And, it will be a little disappointing after the complexity of
mounting the root filesystem. But here it is...

```bash
sudo chroot /mnt
```

There is an optional parameter to define a custom program (shell) to run in the new environment, but
most likely we'll just stick with what we were running before (most likely `bash`).

What may look odd to you is that you appear to be sitting at the `/` directory. In reality, you
are at the place _formerly known as_ `/mnt`. But, now it appears as `/` from your new (chrooted)
perspective.

### Do a little more special mounting

There are three special filesystems that we wait to mount until after the chroot. These will make
your chroot environment complete.

```bash
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devpts devpts /dev/pts
```

### Mount the rest of the filesystem(s), if any

At this point, the remaining filesystem(s), if any, will be defined in `/etc/fstab` and can be
mounted quite quickly with a simple

```bash
mount -a
```

### Have fun!

No you can enjoy your chrooted environment. You can install packages. You can reinstall the bootloader.
The sky is the limit!
