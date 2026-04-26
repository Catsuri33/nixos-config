{ config, pkgs, ... }:

{
  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        disable_loading_bar = false;
        grace = 5;
        hide_cursor = true;
        no_fade_in = false;
      };

      background = [
        {
          # Capture le bureau et applique un flou
          path = "screenshot";
          blur_size = 7;
          blur_passes = 4;
          noise = 0.012;
          contrast = 0.89;
          brightness = 0.82;
          vibrancy = 0.17;
          vibrancy_darkness = 0.0;
        }
      ];

      # Horloge
      label = [
        {
          monitor = "";
          text = ''cmd[update:1000] echo "$(date +"%H:%M")"'';
          color = "rgba(205, 214, 244, 1.0)";
          font_size = 72;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 200";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = ''cmd[update:60000] echo "$(date +"%A %d %B %Y")"'';
          color = "rgba(166, 173, 200, 0.9)";
          font_size = 18;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 130";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = "$USER";
          color = "rgba(166, 173, 200, 0.7)";
          font_size = 14;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, -30";
          halign = "center";
          valign = "center";
        }
      ];

      # Champ de saisie du mot de passe
      input-field = [
        {
          monitor = "";
          size = "250, 50";
          position = "0, -90";
          halign = "center";
          valign = "center";

          outline_thickness = 3;
          dots_size = 0.26;
          dots_spacing = 0.64;
          dots_center = true;
          outer_color = "rgb(137, 180, 250)";
          inner_color = "rgb(30, 30, 46)";
          font_color = "rgb(205, 214, 244)";
          fade_on_empty = false;
          placeholder_text = "Mot de passe…";
          hide_input = false;
          check_color = "rgb(166, 227, 161)";
          fail_color = "rgb(243, 139, 168)";
          fail_text = "<i>Mot de passe incorrect</i>";
          capslock_color = "rgb(249, 226, 175)";
          shadow_passes = 2;
          shadow_size = 3;
        }
      ];
    };
  };
}
