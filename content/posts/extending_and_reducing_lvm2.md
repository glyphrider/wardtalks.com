---
title: "Extending and reducing LVM2"
date: 2022-03-03T08:27:27-05:00
draft: true
tags: [linux,lvm,lvm2]
---
It happens more than you think. You're chugging along and suddenly you're out of (or at least low on) disk space. To compound matters, sometimes you need a lot a disk space to do the work to reclaim diskspace. Compressing files and resizing database files are prime examples. You've only got a little bit of disk space to work with; you'll have a lot when you're done; but to get there, you'll need a fair amount of additional _work space_.

If you've built your system with LVM, then you have options.

# What is LVM

The _Logical Volume Manager_ is a software system that allows you to merge multiple physical volumes into one or more volume groups, then carve that volume group into logical volumes. The logical volumes _appear_ as block devices, and can be formatted with a filesystem and mounted. Only the physical volumes are actually tied to disks, partitions, sectors, etc. The VGs and the LVs provide an abstraction layer that give you a lot of flexibility.

Most distributions default to using LVM. So, there's a good chance that you're ready to go with the tutorial.

## Physical Volumes

Physical volumes are existing block devices (disks and/or partitions) that have been marked for use by LVM. This _marking_ is done with `pvcreate` which takes the block device path as an argument.

## Volume Groups

Volume groups are named _collections_ of physical volumes. There must be at least one physical volume, else there's not going to be any space in the volume group. But, it gets particularly interesting when there are more than one PV in the VG. Volume groups are created with `vgcreate` passing the name of the volume group as the first argument followed by the physical volume(s) comprising the group.

## Logical Volumes

Logical volumes are carved out of volume groups, and stand in for traditional disk partitions in an LVM installation. They can be accessed in the /dev hierarchy as /dev/_vgname_/_lvname_ or /dev/mapper/_vgname_-_lvname_. You format them with `mkfs` and then `mount` them just like you would a partition. They are created with `lvcreate` which will require a size and a name for the new volume as well as the name of the volume group from which it is carved.

# The Scenario

We'll look at an old RedHat 6 VM that has its root filesystem _nearly_ full. We'll put one or more large data files in /var/log to accomplish the filling. The idea is that if we could compress these text files, we'd have plenty of space. But, we don't have enough working space to do the compression. So, we need to *add* some disk space to the root filesystem.

We will accomplish this by adding a new virtual disk to the VM, marking that disk as a physical volume, extending the existing volume group by adding the new physical volume, extending the logical volume supporting the root filesystem by allocating some of the new physical volume's capacity, and finally extending the filesystem itself to provide more working space.

Undoing this will be a little more complicated. But, we'll walk through that too.

## After the install

The virt-manager recommended a 9GB disk. RedHat created a ~500MB boot partition and put the remaining 8.5G into the volume group. The installer decided I should have about 1GB of swap, which left 7.5G for the root filesystem.  With the base installation in place, `df -h` reported 5.2G remaining in the root filesystem. Conveniently, the RedHat ISO was 3.9G which would take care of a lot of the remaining disk space. After copying that into /var/log, there's not enough free space to compress the ISO.

![Screenshot_test_2022-03-03_16:24:40.png](/img/Screenshot_test_2022-03-03_16:24:40.png)

# Making room

I used virt-manager to "plug-in" an additional 20G disk. You'll see in the output from `dmesg` that it appeared _for me_ as /dev/vdb. Different virtualization platforms will have different device names.

![Screenshot_test_2022-03-03_16:40:40.png](/img/Screenshot_test_2022-03-03_16:40:40.png)

So, it followed that up with

```
pvcreate /dev/vdb
vgextend vg_test /dev/vdb
lvextend /dev/vg_test-lv_root /dev/vdb
```

![Screenshot_test_2022-03-03_16:50:21.png](/img/Screenshot_test_2022-03-03_16:50:21.png)

Of great interest (when we go to reverse all of this, later) is that the new disk provided 7067-1948=5119 physical extents (PE). This information is readily available from `pvdisplay`. We didn't need this knowledge to extend the logical volume, because we could just provide the new physical volume as an argument (telling lvextend to extend by however much space is available on this new physical volume).