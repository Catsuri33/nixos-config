{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./hyprlock.nix
    ./dunst.nix
  ];

  # Lets host-specific modules (e.g. modules/home/nvidia.nix) swap in a
  # wrapped build without duplicating/colliding with the plain package below.
  options.custom.librewolfPackage = lib.mkOption {
    type = lib.types.package;
    default = pkgs.librewolf;
    description = "LibreWolf package to install.";
  };

  config = {

    home.username = "lmichault";
    home.homeDirectory = "/home/lmichault";
    home.stateVersion = "24.11";

    home.packages = with pkgs; [
      # Wallpaper
      awww

      # Terminal
      kitty

      # Notifications (dunst itself is installed by services.dunst, see dunst.nix)
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
      config.custom.librewolfPackage

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
      settings = {
        confirm_os_window_close = 0;
        # Needed for starship's prompt icons (folder, git branch, etc).
        font_family = "JetBrainsMono Nerd Font";
      };
    };

    # zsh-autosuggestions (fish-like greyed-out completion from history) +
    # syntax highlighting + Tab completion.
    programs.zsh = {
      enable = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      enableCompletion = true;
      initContent = ''
        export GPG_TTY=$(tty)
      '';
    };

    # Two-line, git-aware prompt (replaces the old "[user@host:path]$").
    programs.starship = {
      enable = true;
      settings = {
        add_newline = true;

        format = ''
          [┌─](bold green)$username$hostname$directory$git_branch$git_status$fill$time
          [└─❯](bold green) '';

        fill.symbol = " ";

        username = {
          show_always = true;
          style_user = "bold blue";
          style_root = "bold red";
          format = "[$user]($style)";
        };

        hostname = {
          ssh_only = false;
          style = "bold blue";
          format = "[@$hostname]($style) ";
        };

        directory = {
          style = "bold cyan";
          truncation_length = 3;
          truncate_to_repo = true;
          format = "[󰉋 $path]($style)[$read_only]($read_only_style) ";
        };

        git_branch = {
          symbol = " ";
          style = "bold purple";
          format = "[on](white) [$symbol$branch]($style) ";
        };

        git_status = {
          style = "bold red";
          format = "([$all_status$ahead_behind]($style) )";
        };

        time = {
          disabled = false;
          style = "bold yellow";
          time_format = "%H:%M";
          format = "[$time]($style)";
        };

        character = {
          success_symbol = "[❯](bold green)";
          error_symbol = "[❯](bold red)";
        };
      };
    };

    services.gpg-agent = {
      enable = true;
      pinentry.package = pkgs.pinentry-curses;
    };

    home.file.".config/wallpapers".source = ../wallpapers;

    home.file.".local/bin/wallpaper-rotate" = {
      executable = true;
      source = pkgs.writeShellScript "wallpaper-rotate" ''
        dir="$HOME/.config/wallpapers"

        # Wait for awww-daemon to be ready (avoids a race on login/boot)
        for i in $(seq 1 20); do
          ${pkgs.awww}/bin/awww query >/dev/null 2>&1 && break
          sleep 0.3
        done

        wall=$(${pkgs.findutils}/bin/find -L "$dir" -maxdepth 1 -type f \
          \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) \
          2>/dev/null | ${pkgs.coreutils}/bin/shuf -n1)
        if [ -n "$wall" ]; then
          ${pkgs.awww}/bin/awww img "$wall" \
            --transition-type random \
            --transition-fps 60 \
            --transition-duration 2
        else
          ${pkgs.awww}/bin/awww clear 1c1c1e
        fi
      '';
    };

    systemd.user = {
      services.wallpaper-rotate = {
        Unit = {
          Description = "Rotate desktop wallpaper";
          After = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "%h/.local/bin/wallpaper-rotate";
        };
      };

      timers.wallpaper-rotate = {
        Unit.Description = "Wallpaper rotation timer";
        Timer = {
          OnBootSec = "10min";
          OnUnitActiveSec = "10min";
        };
        Install.WantedBy = [ "timers.target" ];
      };

      services.protonvpn = {
        Unit = {
          Description = "ProtonVPN";
          After = [ "graphical-session.target" "network.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.proton-vpn}/bin/protonvpn-app";
          Restart = "on-failure";
          RestartSec = "5";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };

  };
}
