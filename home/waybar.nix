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
        modules-right  = [ "pulseaudio" "network" "custom/bluetooth" "battery" "tray" ];

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
          format-wifi       = "{icon}  {essid}";
          format-icons      = [ "󰤟" "󰤢" "󰤥" "󰤨" ];
          format-ethernet   = "󰈀 {ipaddr}";
          format-disconnected = "󰤭";
          tooltip-format    = "{ifname}: {ipaddr}\n{gwaddr}";
          on-click          = "nm-connection-editor";
        };

        "custom/bluetooth" = {
          exec = "${bluetoothStatus}";
          return-type = "json";
          interval = 5;
          on-click = "${pkgs.blueman}/bin/blueman-manager";
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
      #custom-bluetooth,
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

      #custom-bluetooth.connected { color: #0a84ff; }
      #custom-bluetooth.off       { color: rgba(235, 235, 245, 0.25); }

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
