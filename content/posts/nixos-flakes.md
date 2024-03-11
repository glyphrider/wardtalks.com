---
title: "Nixos Flakes"
date: 2024-03-11T08:13:27-04:00
draft: true
---

Using flakes with an existing nixos installation starts with the creation of a flakes.nix file (ideally in /etc/nixos/). This file was lifted entirely from the internet...

```
{
  description = "A simple NixOS flake";

  inputs = {
    # NixOS official package source, using the nixos-23.11 branch here
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    # Please replace my-nixos with your hostname
    nixosConfigurations.HOSTNAME = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Import the previous configuration.nix we used,
        # so the old configuration file still takes effect
        ./configuration.nix
      ];
    };
  };
}
```

You will *need to replace* the string `HOSTNAME` with the actual hostname of your nixos install. Flakes are weird that way.

All this flake does is lock us into the nixos-23.11 channel. On the next `nixos-rebuild` it will create a flakes.lock file
that will further lock us into a specific hash of the 23.11 release. So our packages will become fixed (or locked). When you
are ready to take updates, just use `nix flake update` in the /etc/nixos directory, and the hash for packages will get updated.
After that point, you should use `nixos-rebuild switch --flake .` to apply the updates.


