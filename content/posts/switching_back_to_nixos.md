---
title: "Switching Back to NixOS (Again)"
date: 2026-09-15T11:30:00-04:00
draft: false
tags: [nixos, home-manager, hyprland, flake.nix]
---
# Introduction

I've bounced between distros plenty over the years — you can see the evidence scattered across this blog: Arch, Pop!_OS,
a couple flavors of Ubuntu, even a detour into resurrecting SunOS in QEMU. This summer I landed back on NixOS, and this time
I wanted the whole thing — desktop and laptop both — declared in one flake instead of scattered across shell history and
half-remembered `pacman -S` incantations. What follows is the shape that setup ended up taking, and the handful of real
hardware/software fights it took to get there.

# Sharing One Flake Across Multiple Hosts

The repo started as a single machine: my System76 Pangolin laptop, originally named `pango` and since renamed `nixie`. It's
since grown to share that flake with a second, newer machine — a GMKtec mini-PC desktop called `stealth` — through one
`flake.nix`:

```nix
mkHost = { hostname, monitors }:
  nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ./configuration.nix
      ./hosts/${hostname}/hardware-configuration.nix
      ./hosts/${hostname}/configuration.nix
      { networking.hostName = hostname; }
      home-manager.nixosModules.default
      {
        home-manager.users.brian.imports = [
          ./home.nix
          ./hosts/${hostname}/home.nix
        ];
      }
    ];
  };
```

Both machines land close enough architecturally — Ryzen mobile CPUs with mobile Radeon graphics, just different generations —
that `configuration.nix`/`home.nix` at the repo root
carry the entire shared setup, and `hosts/<name>/` only carries what's genuinely tied to one physical machine — differing disk
layouts (`stealth` is plain btrfs; `nixie` is LUKS-encrypted btrfs with a separate `/boot`), and a couple of hardware quirks
below. The discipline of keeping `hosts/<name>/configuration.nix` and `home.nix` empty unless something *actually* needs to be
there turned out to matter: `nixie`'s `home.nix` had drifted into its own stale fork with different packages before I folded it
back into sharing the root file, and untangling that wasn't fun. Once is enough.

The one thing that genuinely varies per machine and isn't just "this belongs in `hosts/<name>/`" is monitor layout, so `monitors`
is threaded through as an actual module argument (`["DP-1" "HDMI-A-1"]` for the desktop's two monitors, `["eDP-1"]` for the
laptop's single panel) rather than living in a host override file.

The other discipline that keeps two machines sharing one config sane: `configuration.nix`/`home.nix` stay minimal on purpose.
Neither is where project-specific tooling lives. A tool I reach for occasionally but don't want permanently installed gets a
shell alias that runs it through `nix run` instead — `htop = "nix run nixpkgs#htop"`, and the same for `emacs`, `fetch`,
`nvtop`, `pyfa` — so it's available on demand without adding to `home.packages` or ever going stale relative to nixpkgs. And a
tool a specific *project* needs — `terraform`, `hugo`, `awscli2`, whatever — doesn't belong here at all; it belongs in that
project's own `flake.nix`, entered with `nix develop`. `wardtalks.com`'s `terraform` has no business being globally available
on either machine just because I happen to run it there sometimes. Keeping that boundary means this shared config only grows
when something is genuinely about the *machine*, not about whatever I'm currently working on.

# Pin First, Ask Questions Later

Two things in this flake are pinned to older versions than nixpkgs would otherwise give me, and both are worth calling out
because neither pin reflects an actual preference — they're both working around upstream breakage:

- **Hyprland** is pinned to a commit before [hyprwm/Hyprland#16140](https://github.com/hyprwm/Hyprland), which dropped the
  numeric workspace `id` from `hyprctl`'s JSON output in favor of an address-based identity. Waybar's `hyprland/workspaces`
  module hadn't caught up yet, and without the pin it just shows a single "0" for every workspace.
- **`linux-firmware`** is pinned on `nixie` specifically (not the shared config) to an older tag, because a newer release broke
  DMCUB firmware load on its Rembrandt/Radeon 680M GPU — `[drm] *ERROR* Error queuing DMUB command` and a slow, glitchy boot.
  `stealth`'s desktop GPU isn't affected, so the pin lives in `nixie`'s own host overlay, not the shared file.

Both are documented right in the flake with a comment explaining exactly what to check before removing the pin — "pin and
forget" is how you end up carrying a two-year-old workaround for a bug that was fixed eighteen months ago.

# The Login Screen, The Hard Way

I went through two greeters before landing on one I was happy with. First was `regreet` under `cage` — cage is a single-app
kiosk compositor, and its only options for multiple monitors are "last" (pick one output) or "extend" (stitch every output
into one virtual desktop and stretch the greeter across all of it). On `stealth`'s two-monitor setup, "extend" meant the login
screen literally spanned both displays, which looked exactly as bad as it sounds.

I switched to SDDM via the `silent-sddm` flake input, using its bundled "nord" theme — plain Qt6/QML, so it doesn't drag in
KDE Plasma Frameworks just for a login screen. It's a real improvement, but not a total fix: SDDM's Wayland greeter backend
only draws on the primary output on multi-monitor setups ([sddm/sddm#1696](https://github.com/sddm/sddm), still open), so on
`stealth` the greeter still only shows on one monitor. The workaround for *that* would be falling back to SDDM's X11 backend
just for the greeter — which means running Xorg on an otherwise Wayland-only system purely for login-screen cosmetics. I
decided that trade wasn't worth it and left it alone.

# Hardware Has Opinions

A few fights were specific enough to particular peripherals that they only make sense living in one host's config, not the
shared one:

- Bluetooth speakers next to the desktop needed a small systemd user service that retries connecting on a loop, because
  wireplumber's A2DP audio endpoints don't exist yet at the exact moment the Bluetooth adapter powers on at boot. It's ordered
  against wireplumber specifically so it also re-fires across suspend/resume, not just at boot.
- EVE Online (a Steam/Proton game) needed a set of Hyprland window rules ordered *just right*: one to force the game window
  itself fullscreen, a separate size/position rule for its launcher window (whose self-reported dimensions reflect the
  *pre-rule* size, so the fix uses literal pixel offsets instead of relative ones), and a rule that specifically suppresses the
  launcher's own delayed fullscreen request — without which the launcher and Hyprland fight over sizing it forever.
- GE-Proton gets copied into Steam's compatibility-tools directory rather than symlinked. `home.file` with `recursive = true`
  symlinks each file individually, and GE-Proton's own `copy_pfx()` step preserves those symlinks when it creates a per-game
  wine prefix — which means the copy ends up pointing back at the read-only Nix store and crashes with `EROFS` the first time
  a game tries to write to it. A real copy, gated behind a marker file so it doesn't re-copy on every rebuild, sidesteps the
  whole problem.

None of these are NixOS-specific lessons, exactly — they're the kind of thing you'd hit on any distro — but writing them down
as Nix means they're *fixed*, not "the thing I remember to do after every reinstall."

# NFS, Shared Safely Across Two Machines

Both hosts mount the same home NAS share, and it's declared once in the shared `configuration.nix`. Two details make that safe:
the NAS only exports NFSv3 (confirmed with `rpcinfo -p` after NFSv4 mounts failed outright with "Protocol not supported"), and
the mounts are automount/idle-unmount (`x-systemd.automount`, a ten-minute idle timeout) rather than mounted eagerly at boot.
That second part is what actually makes sharing the config safe: only one of the two machines is ever guaranteed to be on the
home network at a given moment, and neither boot nor login blocks waiting for a NAS that might not be reachable.

# Home Manager Beyond Dotfiles

The home-manager side isn't just terminal/editor config. Neovim itself comes from a separate flake input
([`kickstart.nvim`](https://github.com/glyphrider/kickstart.nvim)) rather than being inlined here, `git`/`gh` are configured
declaratively (commit signing, credential helper), and — most recently — so is `~/.aws/config`, via home-manager's
`programs.awscli` module: one `[profile]` block per project I run Terraform or deploys against, generated declaratively instead
of hand-edited. `package = null` on that module keeps `awscli2` itself out of the global package list — each project's own
flake brings its own copy, so the actual CLI binary stays scoped to whatever repo you're standing in. (I wrote more about the
project side of that setup — the actual AWS roles and Terraform behind it — in the
[previous post](/posts/wardtalks_infrastructure_as_code/).)

# Where Things Stand

A laptop and a desktop, one shared flake, and `nixos-rebuild --sudo --flake .#<hostname> switch` to apply changes to whichever
one I'm sitting at. Every hardware quirk that used to live in my head now lives in a comment next to the setting that compensates for it, which
is really the whole pitch of coming back to NixOS: not that it's less work up front, but that the work you *do* is written
down, reproducible, and — critically — explains itself six months later when you've forgotten why a line of config exists at
all.

One gap that's still open, though: disk partitioning itself isn't declarative yet. `hosts/<name>/hardware-configuration.nix` is
machine-generated by `nixos-generate-config` after the disks are already partitioned and formatted by hand, so a fresh install
still means falling back to manual `parted`/LUKS commands before Nix ever gets involved. I actually tried
[`disko`](https://github.com/nix-community/disko) for this — it lets you describe the entire disk layout, LUKS and all, as
Nix and have it build the disks from that description — and reverted it after less than a day. Bringing it back properly,
rather than as a same-day experiment, is next on the list; it's the one piece of "reinstall this machine from scratch" that
still lives in muscle memory instead of the flake.

---

*Like the last post, this one was written by Claude Code — this time working from `git log` in the `nixos` repo rather than
from a session it ran itself, to reconstruct the story of how this setup came together.*
