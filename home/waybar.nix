{ config, pkgs, ... }:

{
  programs.waybar = {
    enable = true;

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 40;
        margin-top = 8;
        margin-left = 10;
        margin-right = 10;
        spacing = 4;

        modules-left   = [ "hyprland/workspaces" ];
        modules-center = [ "clock" ];
        modules-right  = [ "pulseaudio" "network" "battery" "tray" ];

        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          format = "{id}";
          persistent-workspaces = {
            "*" = 5;
          };
        };

        "clock" = {
          format = "{:%H:%M}";
          format-alt = "{:%A, %B %d}";
          tooltip-format = "<big>{:%B %Y}</big>\n<tt><small>{calendar}</small></tt>";
        };

        "battery" = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity}%";
          format-charging = "󱐋 {capacity}%";
          format-icons = [ "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
        };

        "network" = {
          format-wifi       = "  {essid}";
          format-ethernet   = "󰈀 {ipaddr}";
          format-disconnected = "󰤭";
          tooltip-format    = "{ifname}: {ipaddr}\n{gwaddr}";
          on-click          = "nm-connection-editor";
        };

        "pulseaudio" = {
          format       = "{icon} {volume}%";
          format-muted = "󰝟";
          format-icons = {
            default = [ "󰕿" "󰖀" "󰕾" ];
          };
          on-click = "pavucontrol";
        };

        "tray" = {
          spacing = 8;
          icon-size = 16;
        };
      };
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", sans-serif;
        font-size: 13px;
        min-height: 0;
        border: none;
        border-radius: 0;
        transition: all 0.15s ease;
      }

      window#waybar {
        background: rgba(22, 22, 24, 0.82);
        color: #ffffff;
        border-radius: 14px;
        border: 1px solid rgba(255, 255, 255, 0.08);
        box-shadow: 0 4px 20px rgba(0, 0, 0, 0.5);
      }

      /* Workspaces */
      #workspaces {
        padding: 0 6px;
      }

      #workspaces button {
        padding: 4px 11px;
        margin: 5px 2px;
        background: transparent;
        color: rgba(235, 235, 245, 0.35);
        border-radius: 8px;
        font-size: 11px;
        font-weight: bold;
      }

      #workspaces button.active {
        background: rgba(10, 132, 255, 0.25);
        color: #0a84ff;
      }

      #workspaces button:hover {
        background: rgba(255, 255, 255, 0.07);
        color: rgba(235, 235, 245, 0.75);
      }

      #workspaces button.urgent {
        background: rgba(255, 69, 58, 0.2);
        color: #ff453a;
      }

      /* Clock — centered, prominent */
      #clock {
        color: #ffffff;
        font-size: 15px;
        font-weight: bold;
        letter-spacing: 0.5px;
        padding: 0 16px;
      }

      /* Right modules */
      #battery,
      #network,
      #pulseaudio {
        padding: 0 10px;
        color: rgba(235, 235, 245, 0.75);
      }

      #tray {
        padding: 0 10px 0 4px;
      }

      #battery.charging { color: #30d158; }
      #battery.warning  { color: #ff9f0a; }
      #battery.critical {
        color: #ff453a;
        animation: blink 1.2s ease infinite alternate;
      }

      @keyframes blink {
        to { color: rgba(255, 69, 58, 0.4); }
      }

      #network.disconnected { color: rgba(235, 235, 245, 0.25); }
      #pulseaudio.muted     { color: rgba(235, 235, 245, 0.25); }

      tooltip {
        background: rgba(28, 28, 30, 0.96);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 10px;
        color: #ffffff;
        padding: 6px;
      }
    '';
  };
}
