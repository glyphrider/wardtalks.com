---
title: "Reliving SunOS with qemu"
date: 2020-05-21T09:17:11-04:00
draft: true
---

Back in 1990, when I transferred to [Rhodes College](https://rhodes.edu), they had recently used some grant money to acquire some Sun Workstations to enhance their Mathematics/Computer Science offering. I was my first exposure to Unix, and C, and networked workstations. Mind blown! Within a couple of years I was tumbling down Linux rabbit hole, and was slipping away from my BSD roots.

In the late 1990s and early 2000s, there was a renaissance of SunOS for me. I acquired a Sun IPC and a Sun IPX from eBay (for about $100 each). I got a sysadmin friend to install SunOS 4.1.4 on them, and began playing around. But, eventually, those workstations moved on, and I was once again _living in the shade_.

Last week, during the pandemic, I got the itch to get this stuff running. The only choice was virtualization, so I turned to [qemu](https://qemu.org). Now, I had to remember how things worked 30 years ago, somewhat aided by google and other people's efforts.

##### Thing #1

SunOS is really closely tied to the Sun hardware and firmware. So, in order to boot the OS installer, you'll need a copy of the _real_ Sun BIOS. I was able to find a copy of [ss5.bin](/software/ss5.bin), though the original (_earthlink!_) link had gone stale. Using this file, you can startup an emulated SPARCstation 5 with qemu.

```bash
qemu-system-sparc -bios ss5.bin
```

Result:

![sunos boot](/img/sunos_screenshot_1.png)

Also, you'll need a copy of the SunOS installation media. SunOS 4.1.4 is also known as Solaris 1.1.2. Sun/Oracle isn't particularly possessive over this software, so you should be able to find it _out there on the internet_. [Let me google that for you](https://lmgtfy.com/?q=solaris+1.1.2+download)!

##### Thing #2

SunOS does some really weird things with device ids and scsi ids. It wants the hard disk to be at scsi id 3, so that will map to /dev/sd0; interestingly enough, scsi id 0 will then map to /dev/sd3. If you want you computer to really emulate a Sun workstation, then you should configure your hard drive as scsi id 3. This is contrary to a lot of the other online instructions, including those at qemu.org, which have you use the _easy_ configuration of setting the hard disk at id 0 (/dev/sd3).

In a related story, /dev/sr0 (the CD Rom device) is mapped to scsi id 6. But this doesn't come into play because of...

##### Thing #3

Sun leveraged a non-standard block size for its CD Rom drives. Instead of a traditional 4k block size, they use a 512b block. This is a straight-up PITA whether you're using emulation or trying to resurrect physical hardware. On the physical side, you _have_ to use a Sun CD Rom driver -- meaning you have to find one (that works). On the emulation side, we can't even do that. So, we revert to some serious trickery.

We will map this ISO image to an alternate scsi id and mount it as if it were a hard disk. At one point, the install will fail because of this, and we'll have to use `dd` to copy some executable code off the distribution CD onto a hard disk partition on the target drive. That sounds like fun, eh?

##### Thing #4

Some little hardware/emulation issues make the installation break, and we'll need to work around them. It's not a big deal, but here's what I've found.

1. The installation works best with 32M of RAM. The default is 128M, and the max for a SS-5 is 256M. So, we'll add a `-m 32` to our command line for our initial boot to cap our available RAM at 32M.
2. The installation doesn't do very well when the emulated graphics card, the cg3, is enabled. So, we'll do the installation with the `-nographic` option to remove that hurdle.

Both of this workarounds will be stripped away once the OS has been installed.

##### Installation Phase 1

Create an image for the target drive. Use the `qemu-img` utility for this.

```bash
qemu-img create -f qcow2 ss5.img
```

Setup our devices:

1. The target disk will use the file ss5.img from above; the format is qcow2; the interface is scsi; the bus (which scsi adapter) is 0; and the unit (which scsi id) is 3; the media type is disk.
2. The source disk will use the file sunos.iso (likely not the name of the iso you find on the internet); the format is raw; the interface is scsi; the bus is 0; the unit is 1; the media is disk (non-intuitive, as you'd expect cdrom); we will set the drive to readonly, just to be safe.

Boot to the mini-root environment from the CD Rom.

```bash
qemu-system-sparc -bios ss5.bin -m 32 -nographic \
    -drive file=ss5.img,format=qcow2,if=scsi,bus=0,unit=3,media=disk \
    -drive file=sunos.iso,format=raw,if=scsi,bus=0,unit=1,media=disk,readonly=on
```

The bios tries to boot with the network adapter. We'll need to specify the source disk, and specifically the fourth partition of the disk, as the boot device.

![bios boot nographic](/img/sunos_screenshot_2.png)

If you have chosen to modify anything about the device containing the install media, the number will differ but the partition (d) will not.
```bash
ok boot disk1:d
```

![boot install media](/img/sunos_screenshot_3.png)

At this point, we want to boot to the mini-root, format the target disk, and copy enough of the OS there to reboot.

```
What would you like to do?
  1 - install SunOS mini-root
  2 - exit to single user shell
Enter a 1 or 2: 1
Beginning system installation - probing for disks.
Which disk do you want to be your miniroot system disk?
  1 - sd0:  <drive type unknown>> at esp0 slave 24
  2 - sd1:  <CD-ROM Disc for SunOS Installation> at esp0 slave 8
  3 - exit to single user shell
Enter a 1, 2 or 3: 1
selected disk unit "sd0".
Do you want to format and/or label disk "sd0"?
  1 - yes, run format
  2 - no, continue with loading miniroot
  3 - no, exit to single user shell
Enter a 1, 2, or 3: 1
```

