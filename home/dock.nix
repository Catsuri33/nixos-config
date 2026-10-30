{ config, pkgs, lib, ... }:

# macOS-style dock: pinned apps + running ones, dot under running apps,
# frosted glass (blurred by Hyprland, see layer_rule in hyprland.nix).
# Started from hyprland.start; its flags live here so both stay in sync.

let
  # Desktop entry IDs. Right-click an icon in the dock to pin/unpin;
  # this list only seeds the file on first activation.
  pinned = [
    "org.gnome.Nautilus"
    "librewolf"
    "kitty"
    "code"
    "signal"
    "proton-mail"
    "com.discordapp.Discord"
    "com.spotify.Client"
  ];
in

{
  options.custom.dockCommand = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    description = "Command line that starts the dock.";
  };

  config = {
    # -x: exclusive zone, tiled windows stop above the dock instead of
    # sliding under it. No launcher button: Vicinae (SUPER+R, or the
    # Apple menu in waybar) plays Launchpad/Spotlight.
    custom.dockCommand = lib.concatStringsSep " " [
      "${pkgs.nwg-dock-hyprland}/bin/nwg-dock-hyprland"
      "-x" "-p bottom" "-i 44" "-mb 8" "-nolauncher"
      "-hd 0" "-s style.css"
    ];

    home.activation.seedDockPins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      pins="${config.xdg.cacheHome}/nwg-dock-pinned"
      if [ ! -e "$pins" ]; then
        run mkdir -p "$(dirname "$pins")"
        run cp ${pkgs.writeText "nwg-dock-pinned" (lib.concatLines pinned)} "$pins"
        run chmod u+w "$pins"
      fi
    '';

    xdg.configFile."nwg-dock-hyprland/style.css".text = ''
      * {
        font-family: "Inter";
      }

      window {
        background: rgba(40, 40, 44, 0.45);
        border: 1px solid rgba(255, 255, 255, 0.14);
        border-radius: 22px;
      }

      #box {
        padding: 6px 8px 2px 8px;
      }

      button, image {
        background: none;
        border-style: none;
        box-shadow: none;
      }

      button {
        padding: 2px 4px 0 4px;
        margin: 0 2px;
        border-radius: 12px;
        color: rgba(255, 255, 255, 0.8);
        font-size: 9px;
        transition: background-color 120ms ease;
      }

      button:hover {
        background-color: rgba(255, 255, 255, 0.12);
      }

      button:focus {
        box-shadow: none;
      }

      /* Running-window indicator: nwg-dock draws task-*.svg under the
         icon; keep it subtle like the macOS dot. */
      #active {
        border-bottom: none;
      }
    '';
  };
}
