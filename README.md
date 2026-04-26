# nixos-config

# Generate hardware-configuration

```bash
sudo nixos-generate-config --show-hardware-config > hosts/nixos/hardware-configuration.nix
```

# Add wallpaper

```bash
cp myimage.jpg ~/.config/wallpaper.jpg
```

# Apply config

```bash
sudo nixos-rebuild switch --flake .#asuslm
```