# nixos-config

NixOS configuration with Hyprland, managed via flake and home-manager.

## Environments

| Host | Hostname | Modules |
|------|----------|---------|
| Gaming laptop | `laptop-gaming` | base · nvidia · gaming · NFS Jellyfin |
| Gaming desktop | `desktop-gaming` | base · nvidia · gaming |
| Light laptop | `laptop-light` | base |

### NixOS modules

- **base** — Hyprland + UWSM, greetd, pipewire, bluetooth, polkit, auto-upgrade,
  privacy/security hardening (see below)
- **nvidia** — Open-source kernel modules, kernel options and Nvidia Wayland env vars
- **gaming** — Steam, Wine, Lutris, GameMode, MangoHud
- **secureboot** — lanzaboote Secure Boot (desktop-gaming/laptop-light only, see below)

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
| `laptop-gaming` | zram (encrypted-in-effect, RAM-only) | plain ext4 — disko wired in, LUKS reinstall not yet applied |
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
- **laptop-gaming**: `disko.nixosModules.disko` and
  `hosts/laptop-gaming/disko.nix` are now wired into `flake.nix`, ahead of
  the physical reinstall. This host is still live on plain ext4 today, and
  `hosts/laptop-gaming/hardware-configuration.nix` still declares the old
  plaintext `fileSystems`, so building/switching this config
  (`nixos-rebuild build/switch`, including the weekly `system.autoUpgrade`)
  fails on a conflicting `fileSystems."/".device` definition — confirmed
  safe: the build errors out before touching the running system, it does
  not brick anything. Still, **do not run `nixos-rebuild switch` against
  `laptop-gaming` until immediately after the disko + `nixos-install` step**
  — after backing up anything not tracked by this repo (SSH/GPG keys,
  non-home-manager files in `$HOME`).

Install flow (fresh machine or after backing up `laptop-gaming`):

```bash
# from a NixOS live ISO
nix run github:nix-community/disko -- --mode disko ./hosts/<name>/disko.nix
nixos-install --flake .#<name>
```

```bash
# after first boot, enroll TPM2 auto-unlock + a recovery key
sudo systemd-cryptenroll --tpm2-device=auto /dev/disk/by-partlabel/disk-main-luks
sudo systemd-cryptenroll --recovery-key /dev/disk/by-partlabel/disk-main-luks
```

Keep the recovery key somewhere off-machine (password manager, paper) — a
forgotten LUKS passphrase with no recovery key means permanent data loss.

## Privacy & security hardening

Inspired by GrapheneOS's approach on Android: fast security patching first,
then reduce attack surface and fingerprinting. Applies to all 3 hosts unless
noted.

### Browser

Firefox was replaced by **LibreWolf** (`home/home.nix`) — Vanadium itself
can't exist on desktop (it's built on GrapheneOS's Android sandbox), and
LibreWolf is the closest match to "Firefox without the bloat": telemetry,
Pocket, sponsored tiles and studies stripped by default, while still tracking
Firefox's rapid security-release cadence (unlike e.g. ungoogled-chromium,
which historically lags upstream Chromium security patches in nixpkgs).

### System hardening (`modules/nixos/base.nix`)

- `boot.kernel.sysctl` — kernel info leak reduction (`kptr_restrict`,
  `dmesg_restrict`), disables `kexec` and unprivileged BPF, admin-only
  `ptrace` (`yama.ptrace_scope=2` — **attaching gdb/strace to a process you
  don't own now needs `sudo`**), network hardening (rp_filter, no ICMP
  redirects/source-routing), `fs.protected_*`.
- `security.protectKernelImage`, `security.sudo.execWheelOnly`,
  `systemd.coredump.enable = false`, `services.fwupd.enable` (firmware
  security updates).
- `environment.memoryAllocator.provider = "graphene-hardened"` —
  `hardened_malloc`, GrapheneOS's own memory allocator, packaged natively in
  NixOS. `modules/nixos/gaming.nix` overrides this to
  `"graphene-hardened-light"` on `laptop-gaming`/`desktop-gaming` (the full
  variant has a real perf cost not worth paying for gaming).
- `services.resolved` with DNS-over-TLS to Quad9 (privacy-respecting,
  filters known-malicious domains).
- Wi-Fi MAC randomization: `networking.networkmanager.wifi.macAddress =
  "stable"` (one random-but-persistent MAC per SSID, matching
  Android/GrapheneOS's default) + `scanRandMacAddress = true` for probes.
  Ethernet is left un-randomized — little privacy benefit on a home network,
  and it'd risk breaking the Jellyfin NAS's DHCP reservation.

`linuxPackages_hardened` (a hardened kernel package) was considered but
**no longer exists in nixpkgs** (removed 2026-03-18, unmaintained) — the
sysctl/protectKernelImage hardening above is the practical substitute and
doesn't fight with `gaming.nix`'s `linuxPackages_latest` pin (needed for
NTSync/Windows game compat) or the Nvidia driver.

### Secure Boot (lanzaboote)

Desktop analogue of GrapheneOS's verified boot. `modules/nixos/secureboot.nix`
+ the `lanzaboote` flake input replace `systemd-boot` with a signed boot
chain.

- **desktop-gaming** / **laptop-light**: already wired into `flake.nix` —
  installing either from a live ISO sets up Secure Boot from the start.
- **laptop-gaming**: deliberately **not** wired in yet (same reasoning as
  disko above — a live host with weekly `system.autoUpgrade` shouldn't have
  its boot chain change without a manual step first). To enable once ready:

  ```bash
  # 1. In UEFI firmware settings: clear existing (OEM) Secure Boot keys,
  #    switch Secure Boot to "Setup Mode" (exact wording varies by vendor).
  # 2. Boot back into Linux, then:
  sudo sbctl create-keys
  sudo sbctl enroll-keys --microsoft   # keep Microsoft certs (Nvidia option ROMs, etc.)
  # 3. Add these two lines to flake.nix's laptop-gaming modules (see
  #    desktop-gaming for the pattern):
  #      lanzaboote.nixosModules.lanzaboote
  #      ./modules/nixos/secureboot.nix
  sudo nixos-rebuild switch --flake ~/nixos-config#laptop-gaming
  sudo sbctl verify
  # 4. Back in UEFI firmware settings: re-enable Secure Boot enforcement.
  ```

Requires `hardware.nvidia.open = true;` (already set in `nvidia.nix`) —
unsigned proprietary kernel modules don't load once Secure Boot's lockdown
kicks in. Confirmed supported on `laptop-gaming`'s RTX 3050 Ti (Ampere).
Check any new host's GPU is Turing-generation or newer before relying on
this.

### USBGuard

Enabled on all 3 hosts (`modules/nixos/base.nix`). Blocks any USB device
inserted *after* boot until explicitly allowed (evil-maid/BadUSB protection
on an unattended machine), while `presentControllerPolicy`/
`presentDevicePolicy = "allow"` auto-trust whatever's already connected at
boot time — built-in keyboard/trackpad/webcam included — so enabling it
can't lock out local input.

To allow a new device after the fact:

```bash
usbguard list-devices          # find its id
sudo usbguard allow-device <id> -p   # -p persists the rule
```

## Wallpapers

Wallpapers live in the `wallpapers/` directory. They are automatically deployed to all
machines and rotate every 30 minutes with a random transition animation.

To add wallpapers, drop `.jpg`, `.jpeg` or `.png` files into `wallpapers/` and commit.

> Images sourced from [ESA Hubble — Wallpapers](https://esahubble.org/images/archive/wallpapers/)
