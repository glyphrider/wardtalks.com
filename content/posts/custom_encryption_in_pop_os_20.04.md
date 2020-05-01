---
title: "Custom_encryption_in_pop_os_20"
date: 2020-05-01T14:19:10-04:00
tags: [linux, pop_os]
---

System 76 produced an Ubuntu-based Linux distribution called [Pop!_OS](https://pop.system76.com). It contains better support than vanilla Ubuntu with respect to encrypted volumes, but only by a little bit. The improvements have to do with its ability to deal with disk allocation schemes created before starting the installer; the installer itself offers the same default named decrypt device with a single logical volume filling all available space. However, we can accomplish quite a bit by doing some work up front. And, unlike the Ubuntu scenario outlined in [Setting Up Custom Encryption in Ubuntu 20.04 (Focal Fossa)](/posts/setting_up_custom_encryption_in_ubuntu_20.04), there is no need to swing back at the end to rebuild the initramfs. The only real caveat is that we have to let the installer _open_ the encrypted volume. So this time, we'll set everything up, and then close the encrypted volume before starting the installer.

Walk through the installer to configure the language and keyboard, until you reach the **Clean Install** vs **Custom (Advanced)** fork in the road.

![Install](/img/popos_encryption_screenshot_1.png)

At this point, launch a terminal window with super-T. If you're new to Linux, the super key is the _Windows key_ or the _Command/Apple key_.

In the terminal we're going to use fdisk to create a partition scheme identical to the one in the Ubuntu [article](/posts/setting_up_custom_encryption_in_ubuntu_20.04). The end result should be something like

![fdisk](/img/popos_encryption_screenshot_2.png)

Using **cryptsetup** to build or encrypted device leverages just two commands. As with Ubuntu, the **/dev/vda** device will likely be different on your machine (most likely **/dev/sda**). The final argument in the **luksOpen** line is the name you are giving to the decrypted volume. Not only can this be anything you'd like, it is completely arbitrary here; the real name will be established in the installer.

```bash
sudo cryptsetup luksFormat /dev/vda5
sudo cryptsetup luksOpen /dev/vda5 testvm
```

![cryptsetup](/img/popos_encryption_screenshot_3.png)

Now, we'll repeat the LVM2 magic from the Ubuntu article. First mark the decrypted volume as a physical volume for LVM with `pvcreate /dev/mapper/testvm`. Then create a new volume group with `vgcreate pop_os /dev/mapper/testvm`. Finally, create the three logical volumes for **root**, **home**, and **swap**.

```bash
sudo pvcreate /dev/mapper/testvm
sudo vgcreate pop_os /dev/mapper/testvm
sudo lvcreate -L 8G -n root pop_os
sudo lvcreate -L 2G -n home pop_os
sudo lvcreate -L 2G -n swap pop_os
```

![lvm2](/img/popos_encryption_screenshot_4.png)

Before continuing in the installer, we need to deactivate all these special devices. This installer **must** open these devices itself in order to work properly. So, first, deactivate the volume group with `vgchange -a n pop_os` and then close the decrypted volume with `cryptsetup luksClose testvm`.

```bash
sudo vgchange -a n pop_os
sudo cryptsetup luksClose testvm
```

![close](/img/popos_encryption_screenshot_5.png)

Back in the installer, choose **Custom (Advanced)**. When the disk layout is displayed, click on the large (luks) volume to decrypt. At this point, choose the name you want to use as the device name. Also, provide the correct password.

![decrypt](/img/popos_encryption_screenshot_6.png)

Once you click **Decrypt**, the volume group should appear along with all your defined logical volumes. Mark all the devices appropriately. Don't forget the **/boot** partition on **/dev/vda1**. Then click **Erase and Install**.

![partitions](/img/popos_encryption_screenshot_7.png)

When the installation is complete, you can click **Restart Device**.

![finished](/img/popos_encryption_screenshot_8.png)

When Pop!_OS restarts, you should be greeted by the decryption prompt.

![restart](/img/popos_encryption_screenshot_9.png)

Congratulations!

