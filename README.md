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

## Wallpapers

Wallpapers live in the `wallpapers/` directory. They are automatically deployed to all
machines and rotate every 30 minutes with a random transition animation.

To add wallpapers, drop `.jpg`, `.jpeg` or `.png` files into `wallpapers/` and commit.

> Images sourced from [ESA Hubble — Wallpapers](https://esahubble.org/images/archive/wallpapers/)
