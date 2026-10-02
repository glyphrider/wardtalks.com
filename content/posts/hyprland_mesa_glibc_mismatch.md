---
title: "When a Pinned Hyprland Meets a Moving Mesa"
date: 2026-10-02T07:45:00-04:00
draft: false
tags: [nixos, hyprland, mesa, glibc, flake.nix]
---
# The Symptom

A routine `nix flake update`, a `nixos-rebuild switch`, everything fine. A couple of days later I rebooted, typed my password
into SDDM, and never got a desktop. The greeter accepted the login and then the hand-off to Hyprland just didn't land.

SDDM was where the problem *showed up*, so that's where the investigation started. But SDDM turned out to be fine: it was doing
its job and handing off to Hyprland correctly. Hyprland was the one dying, before it drew a single frame, and its log had two lines that mattered:

```
GLIBC_2.43 not found (required by .../libgallium-....so)
CBackend::create() failed
```

The delay is the sneaky part. A `switch` doesn't restart the compositor you're already sitting in, and that compositor already
has the old Mesa mapped into memory. The broken combination only gets exercised on the next cold start, so the update that
caused it and the crash that reveals it can be days apart.

# Two nixpkgs, One Driver

In the [last NixOS post](/posts/switching_back_to_nixos/) I mentioned that Hyprland is pinned to a specific commit, because a
later change broke Waybar's workspace module. What I didn't think hard about at the time is everything else that pin freezes.
Hyprland's flake brings its *own* nixpkgs, and pinning Hyprland's commit pins that nixpkgs along with it. So the system ends up
with two package sets living side by side:

- **My nixpkgs**, which moves every time I run `nix flake update`. After the latest one, it was on glibc 2.43.
- **Hyprland's nixpkgs**, frozen at the pin. Still on glibc 2.42.

Most of the time that's fine. Two package sets can coexist in the Nix store without ever touching each other. The graphics
driver is the exception. NixOS doesn't give each program its own Mesa. It installs one system-wide copy at
`/run/opengl-driver`, and every GL/Vulkan client loads that copy at runtime: Hyprland, SDDM's greeter, Steam, the browser,
everything. That copy came from `hardware.graphics.package`, which by default means *my* nixpkgs.

Once my nixpkgs moved to a Mesa built against glibc 2.43, Hyprland, which is linked against 2.42, tried to load a library that
needed symbols its libc doesn't have. Dead on arrival.

# Keeping Everything in Sync

glibc is backward compatible but not forward compatible. A library built against an *older* glibc runs fine in a process
linked to a *newer* one. The reverse doesn't work. So the one shared driver has to be built against the *oldest* glibc of
anything that loads it. With the Hyprland pin in place, that's Hyprland's.

The obvious first idea was to go the other way and make Hyprland follow my nixpkgs:

```nix
hyprland = {
  url = "github:hyprwm/Hyprland/<pinned commit>";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

That doesn't build. The pinned Hyprland's `hyprutils` is too old for the `hyprtoolkit` that current nixpkgs ships. The pin
exists precisely because I *can't* move Hyprland forward yet, so dragging its dependencies forward runs into the same wall.

The fix that does work is the one the Hyprland wiki documents: leave Hyprland alone and take Mesa from Hyprland's nixpkgs.
Flake inputs expose their own inputs, so that nixpkgs is right there:

```nix
hardware.graphics =
  let
    hyprPkgs = inputs.hyprland.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  in
  {
    enable = true;
    enable32Bit = true;
    package = hyprPkgs.mesa;
    package32 = hyprPkgs.pkgsi686Linux.mesa;
  };
```

Now Hyprland gets a Mesa built against exactly the glibc it was linked with. Everything else on the system, SDDM's greeter
included, is built from my newer nixpkgs, and it loads that older-glibc Mesa without complaint. The driver is pinned to the
lowest common denominator, which happens to be the one input I'd already pinned. `package32` matters too: Steam and Proton
load the 32-bit driver, and leaving it on my nixpkgs would just reopen the same mismatch in 32-bit land.

# The Catch

This override only makes sense while the Hyprland pin exists. The day Waybar catches up and Hyprland goes back to following
nixpkgs, the two package sets merge back into one and the override turns into a quiet downgrade: an old Mesa on an otherwise
current system. So the comment above it in `configuration.nix` says exactly that: *drop this once the Hyprland pin is gone*.
The project notes beside the Hyprland pin say the same thing from the other direction. The pin and the override need to come
out together, so each one points at the other.

The broader lesson: pinning a flake input pins its *entire* dependency closure, not just the one package you cared about.
Usually that's invisible. It stops being invisible the moment something from the pinned side has to share a runtime-loaded
library with everything else.

---

*Like the last couple of posts, this one was written by Claude Code, working from the commit in the `nixos` repo.*
