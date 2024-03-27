---
title: "NixOS Demo Script"
date: 2024-03-27T09:14:39-04:00
draft: false
---

# Install NixOS via the graphical installer

Nothing _really_ special; just remember to select Allow Non-Free near the end of the (Calamares) installation wizard. Choose the graphical desktop you'd like to use.

# Add a new package to the 

Since the default installation does *not* include `vim`, let's use `nix-shell -p vim` to temporarily make it available.

Add the `google-chrome` package to the user's package list (`sudo vim /etc/nixos/configuration.nix`).
While you're in there, rename the system via `networking.hostname = "demo";` in the config.
Also, it is important to add the settings that enable flakes ('cause we're getting there shortly); add `nix.settings.experimental-features = [ "nix-command" "flakes" ];` to the bottom of the configuration.nix file.

Then perform a `sudo nixos-rebuild switch`. Show it running!

**You will have to reboot to see the new hostname,** and you should since we'll use it below....

Exit the nix-shell and show that `vim` goes away from the user environment; remind everyone that the package and its dependencies still exist in /nix/store.

# Get Flakey!

Change directory into `/etc/nixos` and run `sudo nix flake init` to create a new instance of a basic flake template. Everything in the inputs section is good; the entirety of the outputs section can be replaced with the following:

```
nixosConfigurations.demo = nixpkgs.lib.nixosSystem { modules = [ ./configuration.nix ]; };
```

In the above, the `demo` token represents the hostname (which we changed from nixos to demo in the previous section).

Now, run `sudo nixos-rebuild boot` and a lot will happen!
If you have not yet rebooted, be sure to add `--flake .#demo` to override the hostname to flake configuration mapping.
We're using `nixos-rebuild boot` since the drastic level of change implies we should reboot (likely an update kernel, for instance).

1. The flake will lock in the current git hash of the nixos-unstable branch, and download the nixpkgs metadata for that revision
2. All packages will be updated to the current unstable version
3. The flake.lock file will be created to preserve this version of the system.

Now would be a good time to show off the lock file and display how it "follows" the nixos-unstable branch, but "locks" the particular rev.

Might be a good idea to **reboot** now (since our changes are waiting for us in the next generation).

# There's no place like Home (Manager)

After this big reboot, login as the unprivileged user.
Let's install home-manager!
I chose the **standalone** configuration to underscore the distinction between user configuration and system configuration.
There is another way (home-manager as a nixos module) which is left as an exercise for the reader.

As the user, we first need to add a **nix-channel**.
This is something that happened (for the *system* user) behind the scenes during the install.
It is also something that will be quickly surplanted by the flake we will create.
Nonetheless

```
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
```

For whatever reason (still haven't quite sorted this out, honestly), you have to log out and back in again.
Something needs to be *sourced* into the environment, but I haven't found it.

Once you're back in you can install home-manager with the following *incantation*

```
nix-shell '<home-manager>' -A install
```

This actually creates our first home-manager *generation*.
It also makes the `home-manager` tool generally available to us.
From now on out, new generations of home-manager can be created with `home-manager switch`.

# Customizing our user environment

Though the magic of **nix**, we can configure our user environment, and be reasonable isolated from the system environment.
Let's add *and configure* `vim` so we have access to it in our user environment.
First let's do our `nix-shell -p vim` trick from earlier so we don't have to fumble through using `nano`.
Then let's add the following into our home.nix file via `vim ~/.config/home-manager/home.nix`

```
  programs.vim = {
    enable = true;
    settings = {
      expandtab = true;
      tabstop = 2;
      number = true;
      relativenumber = true;
      shiftwidth = 2;
    };
  };
```

Without even needing to add the package to the list, we will have `vim` **and** it will be configured to our (well, my) liking.
A quick `home-manager switch` will make this a reality.

# A more complicated Flake for Home-Manager

The home-manager flake is more complicated than the nixos flake, because home-manager has multiple inputs (home-manager **and** nixpkgs), **and** we want to keep the two closely tied to each other.
We can start with the template, but here's the full flake.nix file after modifications... or you can just write if from scratch using `vim`

```
{
  description = "Demo Flake for Home-Manager (Standalone)";

  inputs =  {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { system = "${system}"; config.allowUnfree = true; };
  in {
    homeConfigurations."brian" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;

      modules = [ ./home.nix ];
    };
  };
}
```

As I understand it, the **follows** line indicates the the nixpkgs supporting home-manager should follow the main nixpkages input (e.g. nixos-unstable).
Again *as I understand it*, the is designed primarily to reduce system size by not duplicating packages that differ *ever so slightly*.
However, Nix is fully capable of supporting (successfully) these inputs being *disconnected*.
Any package used by one will pull in the correct versions of its dependencies, while the same package (different version) included in by the other input will pull its dependencies.

Regardless, now is the time to implement!

```
home-manager switch
```

What all the fun!
