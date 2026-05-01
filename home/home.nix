{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./hyprlock.nix
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

    # Lanceur d'applications
    inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default

    # Changement de fenêtre
    inputs.hyprswitch.packages.${pkgs.stdenv.hostPlatform.system}.default

    # GPG
    gnupg
    pinentry-curses

    # Éditeur
    vscode
    claude-code

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

  # CSS pour hyprshell (sans ce fichier la fenêtre est transparente sur Nvidia/Wayland)
  xdg.configFile."hyprshell/styles.css".text = ''
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

  xdg.configFile."hyprshell/config.ron".text = ''
    (
        version: 3,
        windows: (
            scale: 8.5,
            items_per_row: 5,
            overview: (
                launcher: (
                    default_terminal: None,
                    launch_modifier: "ctrl",
                    width: 650,
                    max_items: 5,
                    show_when_empty: true,
                    plugins: (
                        applications: (
                            run_cache_weeks: 8,
                            show_execs: true,
                            show_actions_submenu: true,
                        ),
                        terminal: (),
                        shell: (),
                        websearch: (
                            engines: [
                                (
                                    url: "https://www.google.com/search?q={}",
                                    name: "Google",
                                    key: 'g',
                                ),
                            ],
                        ),
                        calc: (),
                        path: (),
                        actions: (
                            actions: [
                                lock_screen,
                                logout,
                                reboot,
                                shutdown,
                                suspend,
                            ],
                        ),
                    ),
                ),
                key: "Tab",
                modifier: "alt",
                filter_by: [],
                hide_filtered: false,
                exclude_special_workspaces: "",
            ),
            switch: (
                modifier: "super",
                key: "Tab",
                filter_by: [
                    current_monitor,
                ],
                switch_workspaces: false,
                exclude_special_workspaces: "",
            ),
            switch_2: None,
        ),
    )
  '';

  programs.home-manager.enable = true;

  services.gpg-agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-curses;
  };
}
