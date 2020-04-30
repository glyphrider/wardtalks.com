---
title: "Managing Thin Provisioned LV Devices"
date: 2020-04-30T07:36:39-04:00
draft: true
---
The Logical Volume Manager in Linux gives us a lot of new-found flexibility when it comes to dealing with disk. The thing I find most useful is _thin provisioning_. This is the concept of very conservative allocation of available disk, leaving a large amount held back for future growth. We rarely understand the way we're going to need disk when we first create the system. We have to get it breathe, grow, and evolve before those patterns become obvious. So, it makes a lot of sense to keep most of the disk in reserve until we begin to recognize our system's true needs. I usually do this by allocating nearly all disk space into a large **volume group**, but using only a small portion for the actual **logical volumes**.

So, LVM2, the logical volume manager included with most Linux distributions, is build around three main concepts
1. Physical Volumes -- these are existing disks or disk partitions that are placed under the control of LVM
1. Volume Groups -- a collection of one or more physical volumes that are grouped together into a pool of available storage space
1. Logical Volumes -- these are carved out of volume groups and are analogous to partitions in traditional disk management.

The exciting thing about LVM2 is that we can always _add_ more physical volumes to existing volume groups without disrupting existing disk allocation, or restarting the system (unless you need to shutdown to physically install a new disk). Further we can not only create new logical volumes _on the fly_, but we can extend (enlarge) existing ones, provided we have unused space in the volume group.
