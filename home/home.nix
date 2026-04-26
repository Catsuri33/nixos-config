{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./hyprlock.nix
    ./wofi.nix
  ];

  home.username = "lmichault";
  home.homeDirectory = "/home/lmichault";
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    # Fond d'écran
    awww

    # Terminal
    kitty

    # Notifications
    dunst
    libnotify

    # Utilitaires Wayland
    grim          # capture d'écran
    slurp         # sélection de zone
    wl-clipboard  # presse-papier Wayland

    # Média / volume
    brightnessctl
    playerctl
    pavucontrol

    # Fichiers
    xdg-utils
    nautilus

    # Navigateur
    firefox

    # Éditeur
    vscode

    # Jeux
    heroic
    mangohud
    gamemode
  ];

  # Variables d'environnement Wayland
  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    GDK_BACKEND = "wayland,x11";
    SDL_VIDEODRIVER = "wayland";
    CLUTTER_BACKEND = "wayland";
  };

  programs.home-manager.enable = true;
}
