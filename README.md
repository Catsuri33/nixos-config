# nixos-config

NixOS configuration with Hyprland, managed via flake and home-manager.

## Environments

| Host | Hostname | Modules |
|------|----------|---------|
| Gaming laptop | `laptop-gaming` | base · nvidia · gaming · NFS Jellyfin |
| Gaming desktop | `desktop-gaming` | base · nvidia · gaming |
| Light laptop | `laptop-light` | base |

### NixOS modules

- **base** — Hyprland + UWSM, greetd, pipewire, bluetooth, polkit, auto-upgrade
- **nvidia** — Proprietary drivers, kernel options and Nvidia Wayland env vars
- **gaming** — Steam, Wine, Lutris, GameMode, MangoHud

### Home-manager modules

- **nvidia** — Hyprland environment variables specific to Nvidia GPUs
- **gaming** — Gaming user packages (winetricks, etc.)
- **laptop** — Battery and backlight management

## Adding a new host

1. Generate the hardware configuration:

```bash
sudo nixos-generate-config --show-hardware-config > hosts/<name>/hardware-configuration.nix
```

2. Create `hosts/<name>/configuration.nix` importing the desired modules.

3. Add the host to `flake.nix`.

4. Apply:

```bash
sudo nixos-rebuild switch --flake .#<name>
```

## Disk & memory encryption

| Host | Swap | Disk encryption |
|------|------|------------------|
| `laptop-gaming` | zram (encrypted-in-effect, RAM-only) | plain ext4 — LUKS reinstall planned, not yet applied |
| `desktop-gaming` | zram | not installed yet — will be LUKS from first install |
| `laptop-light` | zram | not installed yet — will be LUKS from first install |

### Swap

`zramSwap.enable = true;` (in `modules/nixos/base.nix`, applies to all hosts)
replaces disk-backed swap with compressed RAM-only swap: nothing sensitive
ever gets written to disk in plaintext via swap.

### Disk (LUKS via disko)

Each host has a `hosts/<name>/disko.nix` describing a declarative partition
layout: an unencrypted ESP (`/boot`) + a LUKS2 partition containing ext4
(`/`). No disk swap/LVM — zram already covers swap. `disko` is a flake input
(`nix-community/disko`).

- **desktop-gaming** / **laptop-light**: `disko.nixosModules.disko` and their
  `disko.nix` are already wired into `flake.nix` — installing either from a
  live ISO will produce a LUKS-encrypted root from the start. **The `device`
  path in each `disko.nix` is a placeholder — check the real disk with
  `lsblk` from the live ISO and edit it before running disko.**
- **laptop-gaming**: `hosts/laptop-gaming/disko.nix` exists but is
  deliberately **not** wired into `flake.nix` yet. This host is live and
  currently boots from plain ext4; `system.autoUpgrade` runs
  `nixos-rebuild switch` weekly, so wiring disko in now would make the next
  auto-upgrade activate a config expecting `/dev/mapper/cryptroot`, which
  doesn't exist until the physical reinstall happens — that would break the
  next boot. Only add the two lines back to `flake.nix` (see
  `desktop-gaming` for the pattern) immediately before doing that reinstall,
  after backing up anything not tracked by this repo (SSH/GPG keys,
  non-home-manager files in `$HOME`).

Install flow (fresh machine or after backing up `laptop-gaming`):

```bash
# from a NixOS live ISO
nix run github:nix-community/disko -- --mode disko ./hosts/<name>/disko.nix
nixos-install --flake .#<name>
```

```bash
# after first boot, enroll TPM2 auto-unlock + a recovery key
sudo systemd-cryptenroll --tpm2-device=auto /dev/disk/by-partlabel/luks
sudo systemd-cryptenroll --recovery-key /dev/disk/by-partlabel/luks
```

Keep the recovery key somewhere off-machine (password manager, paper) — a
forgotten LUKS passphrase with no recovery key means permanent data loss.

## Wallpapers

Wallpapers live in the `wallpapers/` directory. They are automatically deployed to all
machines and rotate every 30 minutes with a random transition animation.

To add wallpapers, drop `.jpg`, `.jpeg` or `.png` files into `wallpapers/` and commit.

> Images sourced from [ESA Hubble — Wallpapers](https://esahubble.org/images/archive/wallpapers/)
