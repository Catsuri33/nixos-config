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
- **secureboot** — lanzaboote Secure Boot (all hosts, see below)

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
| `laptop-gaming` | zram (encrypted-in-effect, RAM-only) | LUKS2 (disko reinstall done) |
| `desktop-gaming` | zram | not installed yet — will be LUKS from first install |
| `laptop-light` | zram | LUKS2 |

### Swap

`zramSwap.enable = true;` (in `modules/nixos/base.nix`, applies to all hosts)
replaces disk-backed swap with compressed RAM-only swap: nothing sensitive
ever gets written to disk in plaintext via swap.

### Disk (LUKS via disko)

Each host has a `hosts/<name>/disko.nix` describing a declarative partition
layout: an unencrypted ESP (`/boot`) + a LUKS2 partition containing ext4
(`/`). No disk swap/LVM — zram already covers swap. `disko` is a flake input
(`nix-community/disko`), wired into `flake.nix` for all three hosts.

**The `device` path in `desktop-gaming`'s `disko.nix` is a placeholder —
check the real disk with `lsblk` from the live ISO and edit it before
running disko.**

Install flow (fresh machine):

```bash
# from a NixOS live ISO
nix run github:nix-community/disko -- --mode disko ./hosts/<name>/disko.nix
nixos-install --flake .#<name>
# The config sets no user password (the repo is public): set it now,
# otherwise lmichault can't log in.
nixos-enter --root /mnt -c 'passwd lmichault'
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

### Security updates (`system.autoUpgrade`)

Weekly, built from the **pushed** GitHub repo
(`github:Catsuri33/nixos-config`), with `nixpkgs` overridden to the latest
`nixos-unstable` — so unpushed local commits are not applied. It no longer
builds from `~/nixos-config`: root refuses to open a git repo it doesn't
own (every run failed that way), and building as root from a user-writable
directory would let any process running as `lmichault` get root at the
next upgrade. A failed run sends a desktop notification + `wall` message
(`nixos-upgrade-notify.service`). Flatpak apps are updated separately,
daily (`flatpak-apps` user timer).

### System hardening (`modules/nixos/base.nix`)

- `boot.kernel.sysctl` — kernel info leak reduction (`kptr_restrict`,
  `dmesg_restrict`), disables `kexec` and unprivileged BPF, BPF JIT
  hardening, admin-only `ptrace` (`yama.ptrace_scope=2` — **attaching
  gdb/strace to a process you don't own now needs `sudo`**), network
  hardening (rp_filter, no ICMP redirects/source-routing), `fs.protected_*`.
- `boot.kernelParams` — KSPP memory hardening: `init_on_alloc=1
  init_on_free=1 slab_nomerge page_alloc.shuffle=1
  randomize_kstack_offset=on vsyscall=none debugfs=off`. `init_on_free`
  costs a few % of CPU; `vsyscall=none` only breaks pre-2011 static
  binaries.
- `security.protectKernelImage`, `security.sudo.execWheelOnly`,
  `systemd.coredump.enable = false`, `services.fwupd.enable` (firmware
  security updates).
- `security.apparmor.enable` — turns on the AppArmor LSM framework. nixpkgs
  ships few profiles, so actual app confinement comes from Flatpak (below).
- **Flatpak sandboxing** (`services.flatpak.enable`, `custom.flatpakApps`
  in `home/home.nix`) — Discord and Spotify (all hosts), Mattermost and
  Zoom (`laptop-light`) are installed from Flathub per user and run in
  bubblewrap sandboxes, with file access through portals. Not applied to
  LibreWolf (Firefox's own sandbox is stronger than what it can build
  nested inside Flatpak's) nor VS Code (an editor that runs compilers and
  shells on your code would need its sandbox opened entirely).
- `services.smartd` with `notifications.wall.enable` — SMART disk health
  monitoring, so a failing drive's pre-failure attributes show up as a
  warning before it actually dies. No mail server is configured on any
  host, so `wall` (broadcast to logged-in terminals) is used instead of
  email.
- `services.fstrim.enable` — weekly batched TRIM rather than continuous
  `discard`, for performance. Either way TRIM has to pass through dm-crypt
  (`allowDiscards = true` in each `disko.nix`), so the encrypted volume
  reveals which blocks are free — an accepted trade-off for SSD longevity
  and speed, not something the weekly schedule avoids.
- `environment.memoryAllocator.provider = "graphene-hardened"` —
  `hardened_malloc`, GrapheneOS's own memory allocator, packaged natively in
  NixOS. `modules/nixos/gaming.nix` overrides this to
  `"graphene-hardened-light"` on `laptop-gaming`/`desktop-gaming` (the full
  variant has a real perf cost not worth paying for gaming). LibreWolf and
  VS Code run without it (allocator clash, see `home/home.nix`).
- `services.resolved` with DNS-over-TLS to **Mullvad DNS**
  (`base.dns.mullvad.net`: no logging, blocks ads/trackers/malware;
  replaces Quad9, which is leaving France). `Domains = "~."` sends every
  lookup there, so the resolver pushed by each network's DHCP no longer
  receives a plaintext copy. LLMNR and mDNS are off (spoofable multicast
  name resolution). Caveat: a network that blocks outbound DNS to anything
  but its own resolver now gets no DNS at all.
- Vicinae's input server gets `/dev/input` + `/dev/uinput` through the
  `input`/`uinput` groups, not a `cap_dac_override` wrapper.
- Jellyfin NFS share mounted `nosuid,nodev,noexec`, rpcbind disabled
  (NFSv4 doesn't need it).
- No user password in the config (the repo is public) — set at install
  time, see above.
- Wi-Fi MAC randomization: `networking.networkmanager.wifi.macAddress =
  "stable"` (one random-but-persistent MAC per SSID, matching
  Android/GrapheneOS's default) + `scanRandMacAddress = true` for probes.
  Ethernet is left un-randomized — little privacy benefit on a home network,
  and it'd risk breaking the Jellyfin NAS's DHCP reservation.

`linuxPackages_hardened` (a hardened kernel package) was considered but
**no longer exists in nixpkgs** (removed 2026-03-18, unmaintained) — the
sysctl/kernel-parameter hardening above is the practical substitute and
doesn't fight with `gaming.nix`'s `linuxPackages_latest` pin (needed for
NTSync/Windows game compat) or the Nvidia driver.

### Secure Boot (lanzaboote)

Desktop analogue of GrapheneOS's verified boot. `modules/nixos/secureboot.nix`
+ the `lanzaboote` flake input replace `systemd-boot` with a signed boot
chain, wired into `flake.nix` for all three hosts.

On an already-installed host, enroll keys before the first rebuild with it:

```bash
# 1. In UEFI firmware settings: clear existing (OEM) Secure Boot keys,
#    switch Secure Boot to "Setup Mode" (exact wording varies by vendor).
# 2. Boot back into Linux, then:
sudo sbctl create-keys
sudo sbctl enroll-keys --microsoft   # keep Microsoft certs (Nvidia option ROMs, etc.)
sudo nixos-rebuild switch --flake ~/nixos-config#<name>
sudo sbctl verify
# 3. Back in UEFI firmware settings: re-enable Secure Boot enforcement.
```

Requires `hardware.nvidia.open = true;` (already set in `nvidia.nix`) —
unsigned proprietary kernel modules don't load once Secure Boot's lockdown
kicks in. Confirmed supported on `laptop-gaming`'s RTX 3050 Ti (Ampere).
Check any new host's GPU is Turing-generation or newer before relying on
this.

### USBGuard

Enabled on all 3 hosts (`modules/nixos/base.nix`). Blocks any USB device
inserted *after* boot until explicitly allowed (evil-maid/BadUSB
protection). Devices already connected at boot:

- `laptop-light`: `presentDevicePolicy = "apply-policy"` — only those
  listed in `/var/lib/usbguard/rules.conf` are allowed, so a device an
  attacker plugged in while the machine was off stays blocked.
- other hosts: `"allow"` (auto-trusted) until their rules file is
  generated — an empty policy with `"apply-policy"` would block a USB
  keyboard at boot. To switch a host over:

```bash
sudo usbguard generate-policy | sudo tee /var/lib/usbguard/rules.conf.new
# review, merge with any existing rules.conf, move into place, then set
# services.usbguard.presentDevicePolicy = "apply-policy"; in the host config
```

To allow a new device after the fact:

```bash
usbguard list-devices          # find its id
sudo usbguard allow-device <id> -p   # -p persists the rule
```

### Other

- `libvirtd` group is not granted (root-equivalent): virt-manager asks for
  the password through polkit (`hyprpolkitagent`).
- hyprlock has no grace period, so the lock taken before suspend can't be
  undone by a mouse move on resume.
- Steam Remote Play ports are opened on `desktop-gaming` only.

## Desktop utilities

- **Screenshots** — `grim` + `slurp` (`Print` for a region, `Shift+Print`
  for the full screen), copied to the clipboard via `wl-clipboard`.
- **Screen recording** — `wf-recorder`.
- **Color picker** — `hyprpicker`.

## Wallpapers

Wallpapers live in the `wallpapers/` directory. They are automatically deployed to all
machines and rotate every 30 minutes with a random transition animation.

To add wallpapers, drop `.jpg`, `.jpeg` or `.png` files into `wallpapers/` and commit.

> Images sourced from [ESA Hubble — Wallpapers](https://esahubble.org/images/archive/wallpapers/)
