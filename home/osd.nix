{ config, pkgs, ... }:

# Volume/brightness HUD (swayosd), styled like the macOS Sonoma pill that
# drops under the menu bar. Driven by the media keys in hyprland.nix.

{
  services.swayosd = {
    enable = true;
    topMargin = 0.06;
    stylePath = pkgs.writeText "swayosd.css" ''
      window#osd {
        border-radius: 18px;
        border: 1px solid rgba(255, 255, 255, 0.12);
        background: rgba(40, 40, 44, 0.55);
      }

      window#osd #container {
        margin: 12px 18px;
      }

      window#osd image,
      window#osd label {
        color: rgba(255, 255, 255, 0.92);
        font-family: "Inter";
      }

      window#osd progressbar:disabled,
      window#osd image:disabled {
        opacity: 0.45;
      }

      window#osd progressbar,
      window#osd segmentedprogress {
        min-height: 6px;
        min-width: 180px;
        border-radius: 999px;
        background: transparent;
        border: none;
      }

      window#osd trough,
      window#osd segment {
        min-height: inherit;
        border-radius: inherit;
        border: none;
        background: rgba(255, 255, 255, 0.2);
      }

      window#osd progress,
      window#osd segment.active {
        min-height: inherit;
        border-radius: inherit;
        border: none;
        background: #ffffff;
      }
    '';
  };
}
