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
    # Wallpaper
    awww

    # Terminal
    kitty

    # Notifications
    dunst
    libnotify

    # Wayland utilities
    grim
    slurp
    wl-clipboard

    # Media / volume
    brightnessctl
    playerctl
    pavucontrol

    # Network
    networkmanagerapplet

    # Files
    xdg-utils
    nautilus

    # Browser
    firefox

    # Communication
    discord
    signal-desktop

    # Music
    spotify

    # Proton suite
    protonmail-desktop
    proton-vpn
    proton-authenticator

    # Application launcher
    inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default

    # GPG
    gnupg
    pinentry-curses

    # Monitoring
    btop

    # Editor
    vscode
    claude-code
  ];

  # Wayland environment variables
  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    GDK_BACKEND = "wayland,x11";
    CLUTTER_BACKEND = "wayland";
  };

  # Auto-sleep via hypridle (timeouts in seconds, adjust to taste)
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd        = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd  = "hyprctl dispatch dpms on";
      };
      listener = [
        {
          timeout  = 600;   # 10 min — lock screen
          on-timeout = "loginctl lock-session";
        }
        {
          timeout  = 900;   # 15 min — turn off displays
          on-timeout = "hyprctl dispatch dpms off";
          on-resume  = "hyprctl dispatch dpms on";
        }
        {
          timeout  = 1800;  # 30 min — suspend
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };

  programs.home-manager.enable = true;

  programs.kitty = {
    enable = true;
    settings.confirm_os_window_close = 0;
  };

  programs.bash = {
    enable = true;
    initExtra = ''
      export GPG_TTY=$(tty)
    '';
  };

  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-curses;
  };
}
