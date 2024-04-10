---
title: "Playing around with Incus"
date: 2024-04-10T16:32:22-04:00
draft: false
---

# LXD

Over coffee, I caught a video by Jay LaCroix (learnlinux.tv) from a few years ago about using LXD Linux Containers.
Jay is a big Ubuntu guy, and his demo all started with snaps. I knew (or thought I knew) that LXD was _generally
available_ outside of the snap store, so I was undaunted.

I spent a few minutes getting LXD support turned on in NixOS and was ready to try some of this stuff!

Then I discovered that the images: repo (https://images.linuxcontainers.org) had decided to stop supporting LXD. Their
decision, based around a lack of support from Canonical (and a bit of dislike for Canonical in the wake of some
controversial decisions), seemed valid. But that still left me with only Ubuntu server images for LXD.

A little more reading told me about incus, the replacement for LXD. All the images that used to be at
linuxcontainers.org are actually still there, but only for incus these days. So, a bit more fiddling: and
LXD was out, and incus was in.

# The Setup

Firstly, the NixOS incantation

```
{ config, lib, pkgs, ... }:
{
  virtualisation.incus = {
    enable = true;
    preseed = {};
  };
  networking.nftables.enable = true;
}
```

Importing this into my NixOS configuration.nix made incus available. Now I had to get it setup.
My first step was getting into the incus-admin group, so I could communicate with the running daemon via
its unix socket. A quick log-out and log-back-in, and I was ready to initialize the container system.

To do this, I ran `incus admin init`.

There are two big parts to this

## Part 1, The Storage Pool

If you're running on zfs or btrfs, you get to create either a zpool or a subvolume (respectively) to house your
container and config storage. Once the storage area is provisioned, it is installed under /var/lib/incus. If you're
not _one of the cool kids_ running zfs or btrfs, there are other supported solutions; but, as you might expect, you
lose out on some of the coolness that backing your containers with a COW filesystem gives you.

## Part 2, The Network Bridge

You can have incus create a network bridge for you, but I found this problematic. In my case, I already had a bridge built out
with systemd-networkd that enabled my libvirt/qemu/kvm virtual machines to run as peers on the local network. I wanted this for
my incus containers as well, so I ultimately declined the offer from the init script, and attached to my existing bridge with
the following.

```
incus profile device add default eth0 nic nictype=bridged parent=br0 name=eth0
```

This created a default *eth0* device (for my future containers) that was tied to my existing br0 bridge. Surprisingly, it
actually worked. I was expecting a lot more difficultly, TBH. My network configuration is a little obscure. It took a
long time to figure it out in Arch, and another long time to figure out how to port that over to NixOS. I was expecting a
similar _slog_ to get things working in incus, but _voila_....

# Getting started with a continer

To date I've only tried setting up Debian Bookworm containers. So, this is hardly a comprehensive tour. But, I didn't want to
forget what I had typed, so I started jotting it down here. To create a new, running container all I had to type was

```
incus launch images:debian/12 my-first-incus
```

The container's name is _my-first-incus_. It came from the images repo, and debian/12 was its image name/tag. At this point,
`incus stop my-first-incus` followed by `incus start my-first-incus` worked. And, after stopping, `incus delete my-first-incus`
cleans it all up -- though the downloaded base image remains cached in the storage area. If you want to create a new container
but *not* start it up right away, then `incus create my-next-incus` is your friend. This would allow you to make some
config tweaks before it fires up.

Once the container is running, then `incus exec my-first-incus -- bash` will give you a shell inside the container.

# Something Big

To see what I could do with this, I decided to look at replacing my Jellyfin VM with a Jellyfin incus container. This was
especially tricky, since I had not taken great notes during the installation and configuration of the Jellyfin server --
and there was *zero IaC automation*.

At a minimum, I wanted to record the steps it took to get Jellyfin up and running. In a perfect world, I'd even have automation
for it. I was thinking... _maybe ansible could help here_. And while ansible could probably be shoehorned in as a solution,
it didn't seem like a great fit.

For the first pass, I used... _a bash script_. I mean, it's better than nothing, right?

I gathered up four files I had laying around from the initial config of the Jellyfin server

1. My CA certificate
2. The signed Jellyfin certificate
3. The Jellyfin server key
4. The jellyfin.conf file that gets handed to nginx to reverse-proxy (and TLS-ify) Jellyfin

```
incus launch images:debian/12 jellyfin
```

Then, I pulled up the _How to install Jellyfin on Debian_ page at jellyfin.org and got to work.
The first part of the install got curl and gnupg installed on the target machine so I could use them to pull down
the signing key. But, it seemed easier to just do that on the host machine. Then I could just push the resultant
file into the container.

```
curl -fsSL 'https://repo.jellyfin.org/jellyfin_team.gpg.key' | gpg --dearmor -o jellyfin.gpg
incus file push ./jellyfin.gpg jellyfin/etc/apt/keyrings/jellyfin.gpg -pv
```

**EDIT**: it turns out I did need, or seemed to need `curl` and `gnupg` for stuff to work. So,

```
incus exec jellyfin -- apt-get -y install curl gnupg
```

The trailing options on the `incus file push` work exactly like `mkdir` --
any needed directory are created and the output is verbose.

Now, I needed an apt sources file. They had a complex formula for creating it. It was more reasonable to create
a file named jellyfin.sources and put the following in it

```
Types: deb
URIs: https://repo.jellyfin.org/debian
Suites: bookworm
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/jellyfin.gpg
```

After this, I could push that file into the container with

```
incus file push ./jellyfin.sources jellyfin/etc/apt/sources.list.d/jellyfin.sources -pv
```

Now the repo definition is setup, the public signing key is in place, and we're ready for some _sexy_ apt-get action!

```
incus exec jellyfin -- apt-get update
incus exec jellyfin -- apt-get -y install jellyfin
```

Now, technically, Jellyfin is up and running inside the container. But, it's time to get nginx in place. So, we should install it.
And then we should move our config files into place.

```
incus exec jellyfin -- apt-get -y install nginx

incus file push ./jellyfin.conf jellyfin/etc/nginx/conf.d/jellyfin.conf -pv
incus file push ./jellyfin.crt jellyfin/etc/nginx/ssl/jellyfin.crt -pv
incus file push ./jellyfin.key jellyfin/etc/nginx/ssl/jellyfin.key -pv
incus file push ./ca.crt jellyfin/etc/nginx/ssl/ca.crt -pv
```

## A quick diversion into NFS

I have my media served up by TrueNAS via NFS. That's how the existing Jellyfin VM gets access to it. I need figure that out.
Unsurprisingly, NFS isn't very easy to pull of with incus containers. So, it turns out that the solution is to create
special pseudo-disks that map to the places where the NFS shares are mounted on the host.

```
incus config device add jellyfin movies disk source=/srv/nfs/nas/media/movies path=/media/movies
incus config device add jellyfin shows disk source=/srv/nfs/nas/media/television path=/media/shows
```

This creates two devices in the jellyfin container. One named movies that maps the host directory /srv/nfs/nas/media/movies to the
container directory /media/movies. The other does the same for television shows, disguising the fact that TrueNAS is still
exporting the share with the _old name_ of television, but Jellyfin prefers _shows_.

## Back to your regularly scheduled nginx configuration

The final step is to remove the default website from nginx, since our configuration is all in jellyfin.conf, and restart
nginx with all this new configuration goodness. This default website configuration file
(actually a symlink) is /etc/nginx/sites-enabled/default, and we just need to tell incus to remove it. Then we'll use
systemd to restart nginx.

```
incus file delete jellyfin/etc/nginx/sites-enabled/default -v
incus exec jellyfin -- systemctl restart nginx
```

At this point, we just need to figure out where our running container is (network-wise) and use the Jellyfin web-ui to
finish setup.

```
incus list jellyfin
```

Now, point the web browser at that address.
* select your languae (e.g. English)
* create a user in Jellyfin (e.g. jellyfin)
* add a media library for movies, pointing to the /media/movies folder
* add a media library for shows, pointing to the /media/shows folder

Then, just give Jellyfin a few moments to gather up the media and download metadata, you're ready to start watching!

# The Code

I put the script, and its supporting files (minus the SSL keys) into a
[GitHub repo](https://github.com/glyphrider/incus-jellyfin.git). The jellyfin.conf file might be of interest; it is
almost entirely cribbed from a sample file at jellyfin.org. But, I've made the necessary adjustments for it to run
_out of the box_ in my solution.
