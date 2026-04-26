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

    # Réseau
    networkmanagerapplet

    # Fichiers
    xdg-utils
    nautilus

    # Navigateur
    firefox

    # Communication
    discord

    # Musique
    spotify

    # Changement de fenêtre
    inputs.hyprswitch.packages.${pkgs.system}.default

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
    # SDL_VIDEODRIVER = "wayland" retiré : casse les jeux Proton/XWayland (écran noir)
    CLUTTER_BACKEND = "wayland";
  };

  # CSS pour hyprswitch (sans ce fichier la fenêtre est transparente sur Nvidia/Wayland)
  xdg.configFile."hyprswitch/style.css".text = ''
    .client-image {
      margin: 15px;
    }
    .client-index {
      font-size: 2rem;
      font-family: "JetBrainsMono Nerd Font";
      color: white;
      margin: 8px;
    }
    .workspace {
      font-size: 1.5rem;
      font-family: "JetBrainsMono Nerd Font";
      color: white;
      border: 2px solid rgba(89, 180, 250, 0.6);
      border-radius: 10px;
      padding: 10px;
      margin: 5px;
    }
    .workspace:selected {
      border-color: rgba(203, 166, 247, 0.9);
    }
    .client {
      border-radius: 8px;
      margin: 5px;
      padding: 5px;
      background: rgba(30, 30, 46, 0.85);
    }
    .client:selected {
      background: rgba(89, 180, 250, 0.25);
      border: 2px solid rgba(89, 180, 250, 0.9);
    }
    .window {
      background: rgba(17, 17, 27, 0.9);
      border-radius: 15px;
      border: 2px solid rgba(89, 180, 250, 0.4);
      padding: 15px;
    }
  '';

  programs.home-manager.enable = true;
}
