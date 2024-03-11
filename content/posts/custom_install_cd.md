---
title: "Custom Install CD"
date: 2024-03-11T13:09:39-04:00
draft: true
---

While learning NixOS, I found myself booting the minimal installer CD _over, and over, and over again_...
Everytime, I had to remember to start up wpa_supplicant and then use wpa_cli to configure the wireless
conntection. So, after much searching and digging, I sorted out how to build a custom installer cd that
is preconfigured for my wi-fi.

Firstly, per the manual, clone the repo

```
git clone https://github.com/NixOS/nixpkgs
cd nixpkgs
git checkout nixos-23.11
```

Create a new file `modules/installer/cd-dvd/my-local-wifi.nix` and use the following content
(replacing MySSID with your SSID, and MyPSK with you passphrase).

```
{ config, lib, ... }:

{
  imports = [ ./installation-cd-minimal.nix ];

  networking.wireless = {
    enable = true;
    networks."MySSID".psk = "MyPSK";
  };
  systemd.services.wpa_supplicant.wantedBy = lib.mkForce [ "multi-user.target" ];
}
```

Then create the iso with
`nix-build -A config.system.build.isoImage -I nixos-config=modules/installer/cd-dvd/my-local-wifi.nix default.nix`. 
After this, the resultant iso will be in `result/iso` and you can use `dd` to write it to a usb stick.
