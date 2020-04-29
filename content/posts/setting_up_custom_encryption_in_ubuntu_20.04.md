---
title: "Setting Up Custom Encryption in Ubuntu 20.04 (Focal Fossa)"
date: 2020-04-27T16:49:08-04:00
draft: true
---

This post uses a lot of information from [chroot For Fun and Profit](/posts/chroot_for_fun_and_profit/).

The Ubuntu Linux distribution from Canonical gets a lot of praise; it also gets a lot of complaints. A lot of those complaints have to do with it's installer. To be fair, the desktop installer is pretty good for beginners. It walks you through a series of intelligible steps, sets up a basic system with little or no fuss, and most non-default settings can easily be tweaked after the install. But, there's always an exception....

The organization of disk storage, especially as it relates to encryption and thin provisioning of logical volumes, is a bit of a mess. If you tell the installer you want to use logical volume management, it complies by creating one logical volume that spans the entire disk. If you tell the installer you want encryption, you wind up with a similarly un-friendly configuration. So, most _advanced users_ choose to manually configure the disks prior to running the installer. But, with encryption, this results in some complexity that needs to be explained.

The boot process is sufficiently advanced to handle LVM2 without any special intervention after the install. So, if you have configured LVM2 and have your disks carved into logical volumes, everything will just work. The boot process requires some setup within the installation before encryption will work. If you setup encryption, you have to do some tinkering after the installer is done, or you will wind up with an unbootable (albeit recoverable) system.

So, here's our scenario.

##### The Hardware

We will use a single 20GB hard disk. The size is not important, but the examples will reflect that. We are going to break the disk into two partions, a small (512MB) boot parition, and the remainder of the disk in a single logical partition that will be encrypted. On that encrypted device, we will use LVM2 to allow for arbitrary partitions. These paritions will start small, but we can extend them later, via lvextend and resize2fs, should we want more space.

##### The Process

We will boot the machine (in the case of our example, a virtual machine) with the Ubuntu 20.04 _Focal Fossa_ amd64 Desktop Distribution. After booting, we will choose _Try Ubuntu_, which will allow us to do some disk setup prior to running the installer. After the installer, we will choose to _Continue Testing_ instead of immediately rebooting, which will allow us to do some tweaking of the boot process to compensate for encryption.

###### Partitioning with fdisk

After getting to the Ubuntu desktop, you can press ctrl-alt-T to launch terminal; you can also just find it in the menus. Once in the terminal, I usually type `sudo -s` to elevate privilege since everything we do will require _superuser_  permissions.

The next step is to confirm the disk device we'll be using. This is done with `fdisk -l` which lists the disks available for partitioning. In your case, the disk will almost surely be **/dev/sda**, but for our example, it's **/dev/vda**. The following screenshot captures the interaction with fdisk. The final step is to use `w` to write the new partition table and exit.

![fdisk screenshot](/img/encryption_screenshot_1.png)

```
fdisk /dev/vda
n
<default>
<default>
<default>
+512M
n
e
<default>
<default>
<default>
n
<default>
<default>
w
```