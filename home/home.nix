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

  config = let

    # nixpkgs' spotify crashes on launch with "double free or corruption
    # (out)" (glibc's own heap-corruption abort, not a segfault) under the
    # GrapheneOS hardened_malloc allocator that modules/nixos/base.nix
    # preloads for every process system-wide
    # (environment.memoryAllocator.provider, both the "graphene-hardened"
    # and "-light" variants apply equally here since the bug is a mismatch
    # between allocators, not a specific check). Confirmed live: with
    # hardened_malloc's libhardened_malloc.so mapped into Spotify's
    # process (visible in /proc/<pid>/maps), it reliably aborts within
    # ~1s of launch; re-running it in a private mount namespace with
    # /etc/ld-nix.so.preload (the file NixOS's patched glibc reads to
    # decide what to preload) shadowed by an empty file makes
    # libhardened_malloc.so disappear from the process's maps and Spotify
    # runs normally. Root cause is presumably a real heap bug in
    # Spotify's closed-source binary that stock glibc's malloc tolerates
    # but hardened_malloc's canaries/guard pages don't — either way, the
    # exemption is scoped to just this one binary (a few-ms bwrap
    # indirection) rather than weakening the allocator for the whole
    # system.
    spotifyLauncher = pkgs.writeShellScript "spotify-unhardened" ''
      dir=$(dirname "$(readlink -f "$0")")
      preload=$(readlink -f /etc/ld-nix.so.preload 2>/dev/null)
      if [ -n "$preload" ] && [ -e "$preload" ]; then
        exec ${pkgs.bubblewrap}/bin/bwrap --dev-bind / / \
          --ro-bind /dev/null "$preload" \
          -- "$dir/.spotify-unhardened" "$@"
      else
        exec "$dir/.spotify-unhardened" "$@"
      fi
    '';

    spotifyUnhardened = pkgs.spotify.overrideAttrs (old: {
      postFixup = (old.postFixup or "") + ''
        mv $out/share/spotify/spotify $out/share/spotify/.spotify-unhardened
        install -m755 ${spotifyLauncher} $out/share/spotify/spotify
      '';
    });

    # Wraps bin/<binName> of `inner` so it runs with /etc/ld-nix.so.preload
    # shadowed, i.e. without hardened_malloc (same trick as spotify above).
    # Only for apps whose .desktop entries call the binary by name, so they
    # go through the wrapper too.
    unhardenBin = inner: binName: pkgs.symlinkJoin {
      name = "${inner.name}-unhardened";
      paths = [ inner ];
      postBuild = ''
        rm $out/bin/${binName}
        cat > $out/bin/${binName} <<'EOF'
        #!${pkgs.runtimeShell}
        preload=$(readlink -f /etc/ld-nix.so.preload 2>/dev/null)
        if [ -n "$preload" ] && [ -e "$preload" ]; then
          exec ${pkgs.bubblewrap}/bin/bwrap --dev-bind / / \
            --ro-bind /dev/null "$preload" \
            -- ${inner}/bin/${binName} "$@"
        else
          exec ${inner}/bin/${binName} "$@"
        fi
        EOF
        chmod +x $out/bin/${binName}
      '';
    };

    # Same exemption for LibreWolf: since the 2026-10-06 nixpkgs bump it
    # aborts at startup with "fatal allocator error: invalid uninitialized
    # allocator usage" (hardened_malloc's own check) — Firefox ships its own
    # allocator (mozjemalloc) and the two now clash. Confirmed live: the
    # same binary starts normally with the preload shadowed. Little is lost
    # here, since mozjemalloc already serves the browser's allocations.
    # Wraps whatever host modules picked as custom.librewolfPackage.
    librewolfUnhardened = unhardenBin config.custom.librewolfPackage "librewolf";

    # And for VS Code: same abort since the same bump (Electron ships
    # Chromium's PartitionAlloc, like Mattermost in
    # modules/home/laptop-light.nix) — even `code --version`, which runs
    # Electron as plain Node. Confirmed live the same way.
    vscodeUnhardened = unhardenBin pkgs.vscode "code";

    # Ad-hoc version for programs outside this config, e.g.
    # `nix shell nixpkgs#chromium -c unhardened chromium` (Chromium's
    # PartitionAlloc hits the same abort). Runs any command with the
    # preload shadowed.
    unhardenedCmd = pkgs.writeShellScriptBin "unhardened" ''
      preload=$(readlink -f /etc/ld-nix.so.preload 2>/dev/null)
      if [ -n "$preload" ] && [ -e "$preload" ]; then
        exec ${pkgs.bubblewrap}/bin/bwrap --dev-bind / / \
          --ro-bind /dev/null "$preload" -- "$@"
      else
        exec "$@"
      fi
    '';

  in {

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
      wf-recorder
      hyprpicker

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
      librewolfUnhardened

      # Communication
      discord
      signal-desktop

      # Music
      spotifyUnhardened

      # Proton suite
      protonmail-desktop
      proton-vpn
      proton-authenticator

      # Application launcher
      # From nixpkgs, not the upstream flake: that one pins its own nixpkgs,
      # so its libEGL/libgbm drift from the Mesa in /run/opengl-driver after
      # a flake update and Qt aborts on "Failed to create GL context".
      vicinae

      # GPG
      gnupg
      pinentry-curses

      # Monitoring
      btop

      # Editor
      vscodeUnhardened
      claude-code
      unhardenedCmd

      # Typst
      typst
      tinymist

      # AppImage support. appimage-run's default FHS wrapper only bundles a
      # minimal library set; Tauri-based AppImages need webkit2gtk at
      # runtime (libwebkit2gtk-4.1.so.0), which isn't included by default.
      (appimage-run.override {
        extraPkgs = pkgs: [ pkgs.webkitgtk_4_1 ];
      })
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
        # kitty saves the last closed window's size *and* maximized state and
        # reapplies them to new windows; under Hyprland that maximizes every
        # new terminal over the others instead of tiling it.
        remember_window_size = "no";
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

        # kitty sets TERM=xterm-kitty, which most remote hosts don't have a
        # terminfo entry for (breaks clear/tput/vim etc over SSH). kitty's
        # ssh kitten auto-installs its terminfo on the remote on first
        # connect, so alias plain ssh to it.
        if command -v kitty >/dev/null 2>&1 && [ "$TERM" = "xterm-kitty" ]; then
          alias ssh="kitty +kitten ssh"
        fi

        # Transient prompt: once a command is submitted, redraw its two-line
        # starship prompt as a bare "❯" so scrollback stays readable; the
        # full prompt comes back for the next command. starship only does
        # this natively for fish/pwsh/cmd, hence the hand-rolled ZLE hook.
        # PROMPT is saved lazily (not at init) since starship's own init may
        # run after this block.
        autoload -Uz add-zle-hook-widget add-zsh-hook
        _transient_prompt_line_finish() {
          [[ $CONTEXT == start ]] || return 0  # skip PS2/select continuations
          _transient_saved_prompt=$PROMPT
          _transient_saved_rprompt=$RPROMPT
          PROMPT='%B%F{green}❯%f%b '
          RPROMPT=""
          zle .reset-prompt
        }
        _transient_prompt_restore() {
          [[ -v _transient_saved_prompt ]] || return 0
          PROMPT=$_transient_saved_prompt
          RPROMPT=$_transient_saved_rprompt
          unset _transient_saved_prompt _transient_saved_rprompt
        }
        add-zle-hook-widget line-finish _transient_prompt_line_finish
        add-zsh-hook precmd _transient_prompt_restore
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
          # Long MR branch names (feat/166-discord-bot-to-…) otherwise push
          # the first line past the terminal width, so it wraps and splits
          # the prompt.
          truncation_length = 32;
          truncation_symbol = "…";
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

    # Reapplies the current wallpaper to any monitor that shows up after
    # login (e.g. a USB-C dock plugged in later) — awww-daemon otherwise
    # just leaves newly-added outputs black until the next 10-minute
    # wallpaper-rotate tick. Listens on Hyprland's event socket instead of
    # polling; see https://wiki.hyprland.org/IPC/.
    home.file.".local/bin/wallpaper-monitor-watch" = {
      executable = true;
      source = pkgs.writeShellScript "wallpaper-monitor-watch" ''
        ${pkgs.socat}/bin/socat -U - UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" |
        while IFS= read -r line; do
          case "$line" in
            monitoraddedv2*)
              data="''${line#*>>}"
              name="''${data#*,}"
              name="''${name%%,*}"

              # Give awww-daemon a moment to register the new output before targeting it.
              sleep 1

              img=$(${pkgs.awww}/bin/awww query 2>/dev/null | ${pkgs.gnused}/bin/sed -n 's/.*image: //p' | head -n1)
              if [ -n "$img" ] && [ -n "$name" ]; then
                ${pkgs.awww}/bin/awww img "$img" -o "$name"
              fi
              ;;
          esac
        done
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

      # Run as a unit rather than from hyprland.start: it starts once uwsm has
      # exported the Wayland env, and gets restarted if the server dies.
      services.vicinae = {
        Unit = {
          Description = "Vicinae launcher server";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.vicinae}/bin/vicinae server --replace";
          # Capability wrapper from modules/nixos/base.nix.
          Environment = "VICINAE_INPUT_SERVER_BIN=/run/wrappers/bin/vicinae-input-server";
          Restart = "always";
          RestartSec = "2";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };

  };
}
