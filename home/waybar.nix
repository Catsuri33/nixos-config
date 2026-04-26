{ config, pkgs, ... }:

{
  programs.waybar = {
    enable = true;

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 32;
        spacing = 6;

        modules-left   = [ "hyprland/workspaces" "hyprland/submap" ];
        modules-center = [ "hyprland/window" ];
        modules-right  = [ "pulseaudio" "network" "battery" "clock" "tray" ];

        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          format = "{id}";
        };

        "hyprland/window" = {
          max-length = 60;
        };

        "clock" = {
          format = " {:%H:%M}";
          format-alt = " {:%Y-%m-%d %H:%M:%S}";
          tooltip-format = "<big>{:%B %Y}</big>\n<tt><small>{calendar}</small></tt>";
        };

        "battery" = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-charging = " {capacity}%";
          format-icons = [ "" "" "" "" "" ];
        };

        "network" = {
          format-wifi       = " {essid}";
          format-ethernet   = " {ipaddr}";
          format-disconnected = "⚠ Hors ligne";
          tooltip-format    = "{ifname}: {ipaddr}\n{gwaddr}";
          on-click          = "nm-connection-editor";
        };

        "pulseaudio" = {
          format       = "{icon} {volume}%";
          format-muted = " muet";
          format-icons = {
            default = [ "" "" "" ];
          };
          on-click = "pavucontrol";
        };

        "tray" = {
          spacing = 8;
        };
      };
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", monospace;
        font-size: 13px;
        min-height: 0;
        border: none;
        border-radius: 0;
      }

      window#waybar {
        background-color: rgba(30, 30, 46, 0.92);
        color: #cdd6f4;
        border-bottom: 2px solid rgba(137, 180, 250, 0.4);
      }

      #workspaces button {
        padding: 0 10px;
        background: transparent;
        color: #6c7086;
        border-bottom: 2px solid transparent;
        transition: all 0.2s ease;
      }

      #workspaces button.active {
        color: #cdd6f4;
        border-bottom: 2px solid #89b4fa;
        background: rgba(137, 180, 250, 0.1);
      }

      #workspaces button:hover {
        background: rgba(137, 180, 250, 0.08);
        color: #cdd6f4;
      }

      #window {
        color: #a6adc8;
        font-style: italic;
      }

      #clock,
      #battery,
      #network,
      #pulseaudio,
      #tray {
        padding: 0 12px;
        color: #cdd6f4;
      }

      #battery.warning { color: #fab387; }
      #battery.critical {
        color: #f38ba8;
        animation: blink 0.5s linear infinite alternate;
      }

      @keyframes blink {
        to { background-color: rgba(243, 139, 168, 0.15); }
      }
    '';
  };
}
