{ config, pkgs, ... }:

let
  bluetoothStatus = pkgs.writeShellScript "waybar-bluetooth" ''
    if ! ${pkgs.bluez}/bin/bluetoothctl show | grep -q "Powered: yes"; then
      echo '{"text":"󰂲","class":"off","tooltip":"Bluetooth off"}'
      exit 0
    fi

    connected=$(${pkgs.bluez}/bin/bluetoothctl devices Connected | sed -E 's/^Device [0-9A-F:]+ //')
    if [ -n "$connected" ]; then
      tooltip=$(echo "$connected" | paste -sd ', ')
      echo "{\"text\":\"󰂱\",\"class\":\"connected\",\"tooltip\":\"$tooltip\"}"
    else
      echo '{"text":"󰂯","class":"on","tooltip":"Bluetooth on, no device connected"}'
    fi
  '';
in

{
  programs.waybar = {
    enable = true;

    # macOS menu bar: full width, flush with the top edge, translucent
    # (Hyprland blurs what's behind it, see layer_rule in hyprland.nix).
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        spacing = 0;

        modules-left   = [ "custom/logo" "hyprland/window" "hyprland/workspaces" ];
        modules-center = [ ];
        modules-right  = [
          "tray" "network#vpn" "custom/bluetooth" "network#wired" "network#wifi"
          "pulseaudio" "battery" "clock"
        ];

        # NixOS snowflake in place of the Apple menu.
        "custom/logo" = {
          format = "";
          tooltip = false;
          on-click = "vicinae toggle";
        };

        # Bold name of the focused app, like the frontmost-app menu.
        "hyprland/window" = {
          format = "{class}";
          separate-outputs = true;
          max-length = 30;
          rewrite = {
            "^$" = "Desktop";
            "kitty" = "Terminal";
            "librewolf" = "LibreWolf";
            "org\\.gnome\\.Nautilus" = "Files";
            "code" = "Code";
            "signal" = "Signal";
            "com\\.discordapp\\.Discord|discord" = "Discord";
            "com\\.spotify\\.Client|[Ss]potify" = "Spotify";
            "com\\.mattermost\\.Desktop|Mattermost" = "Mattermost";
          };
        };

        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          format = "{id}";
        };

        "clock" = {
          locale = "en_US.UTF-8";
          format = "{:%a %b %-d  %H:%M}";
          format-alt = "{:%A, %B %-d, %Y  %H:%M:%S}";
          interval = 1;
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "month";
            format.today = "<span color='#0a84ff'><b>{}</b></span>";
          };
        };

        "battery" = {
          states = {
            warning = 20;
            critical = 10;
          };
          format = "{capacity}%  {icon}";
          format-charging = "{capacity}%  󰂄";
          format-plugged = "{capacity}%  󰚥";
          format-icons = [ "󰂎" "󰁻" "󰁽" "󰁿" "󰂁" "󰁹" ];
          tooltip-format = "{timeTo}";
        };

        # One module per physical link type, each pinned to its interfaces:
        # left on auto, waybar follows the IPv6 default route, which
        # ProtonVPN's leak guard (ipv6leakintrf0, a dummy) owns while the
        # VPN is up, and shows that interface's name instead of an icon.
        "network#wifi" = {
          interface = "wl*";
          format-wifi       = "{icon}";
          format-icons      = [ "󰤟" "󰤢" "󰤥" "󰤨" ];
          format-linked     = "󰤫";
          format-disconnected = "󰤭";
          tooltip-format-wifi = "{essid} ({signalStrength}%)\n{ipaddr}";
          tooltip-format-disconnected = "Wi-Fi disconnected";
          on-click          = "nm-connection-editor";
        };

        # Hidden unless a cable (or the USB-C dock) is plugged in.
        "network#wired" = {
          interface = "en*";
          format-ethernet   = "󰈀";
          format-linked     = "󰈀";
          format-disconnected = "";
          tooltip-format-ethernet = "{ifname}: {ipaddr}";
          on-click          = "nm-connection-editor";
        };

        # Shield while ProtonVPN's tunnel is up, hidden otherwise.
        "network#vpn" = {
          interface = "proton0";
          format = "󰦝";
          format-disconnected = "";
          tooltip-format = "ProtonVPN: {ipaddr}";
          tooltip-format-disconnected = "";
        };

        "custom/bluetooth" = {
          exec = "${bluetoothStatus}";
          return-type = "json";
          interval = 5;
          on-click = "${pkgs.blueman}/bin/blueman-manager";
        };

        "pulseaudio" = {
          format       = "{icon}";
          format-muted = "󰝟";
          format-icons = {
            default = [ "󰕿" "󰖀" "󰕾" ];
          };
          tooltip-format = "{desc}: {volume}%";
          on-click = "pavucontrol";
          on-scroll-up = "swayosd-client --output-volume raise";
          on-scroll-down = "swayosd-client --output-volume lower";
        };

        "tray" = {
          spacing = 10;
          icon-size = 15;
        };
      };
    };

    style = ''
      * {
        font-family: "Inter", "JetBrainsMono Nerd Font", sans-serif;
        font-size: 13px;
        min-height: 0;
        border: none;
        border-radius: 0;
        transition: all 0.15s ease;
      }

      window#waybar {
        background: rgba(28, 28, 30, 0.42);
        color: #ffffff;
        border-bottom: 1px solid rgba(255, 255, 255, 0.06);
      }

      /* Menu-bar items: highlighted on hover like macOS. */
      #custom-logo,
      #window,
      #workspaces button,
      #tray,
      #custom-bluetooth,
      #network,
      #pulseaudio,
      #battery,
      #clock {
        padding: 0 9px;
        margin: 3px 1px;
        border-radius: 6px;
        color: rgba(255, 255, 255, 0.92);
      }

      #custom-logo:hover,
      #workspaces button:hover,
      #custom-bluetooth:hover,
      #network:hover,
      #pulseaudio:hover,
      #battery:hover,
      #clock:hover {
        background: rgba(255, 255, 255, 0.14);
      }

      #custom-logo {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 16px;
        padding: 0 12px 0 14px;
      }

      #window {
        font-weight: bold;
        padding-right: 14px;
      }

      #workspaces {
        margin: 0;
      }

      #workspaces button {
        padding: 0 6px;
        background: transparent;
        color: rgba(255, 255, 255, 0.4);
        font-size: 12px;
      }

      #workspaces button.active {
        color: #ffffff;
        font-weight: bold;
      }

      #workspaces button.urgent {
        color: #ff453a;
      }

      #custom-bluetooth,
      #network,
      #pulseaudio {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 15px;
        padding: 0 8px;
      }

      #battery,
      #clock {
        font-feature-settings: "tnum";
      }

      #clock {
        padding-right: 14px;
      }

      #battery.charging,
      #battery.plugged  { color: #30d158; }
      #battery.warning:not(.charging)  { color: #ff9f0a; }
      #battery.critical:not(.charging) { color: #ff453a; }

      #network.disconnected,
      #pulseaudio.muted,
      #custom-bluetooth.off { color: rgba(255, 255, 255, 0.35); }

      tooltip {
        background: rgba(36, 36, 38, 0.96);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 10px;
        color: #ffffff;
      }

      tooltip label {
        padding: 2px 4px;
      }
    '';
  };
}
