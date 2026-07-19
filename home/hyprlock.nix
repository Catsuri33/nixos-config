{ config, pkgs, ... }:

{
  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        disable_loading_bar = true;
        grace = 3;
        hide_cursor = true;
        no_fade_in = false;
        no_fade_out = false;
      };

      background = [
        {
          # Blurred screenshot of the desktop
          path = "screenshot";
          blur_size = 6;
          blur_passes = 4;
          noise = 0.008;
          contrast = 0.85;
          brightness = 0.75;
          vibrancy = 0.1;
          vibrancy_darkness = 0.0;
        }
      ];

      # Time
      label = [
        {
          monitor = "";
          text = ''cmd[update:1000] echo "$(date +"%H:%M")"'';
          color = "rgba(255, 255, 255, 0.92)";
          font_size = 88;
          font_family = "JetBrainsMono Nerd Font Bold";
          position = "0, 180";
          halign = "center";
          valign = "center";
          shadow_passes = 3;
          shadow_size = 6;
          shadow_color = "rgba(0, 0, 0, 0.4)";
        }
        # Date
        {
          monitor = "";
          text = ''cmd[update:60000] echo "$(date +"%A, %B %d")"'';
          color = "rgba(235, 235, 245, 0.55)";
          font_size = 20;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 100";
          halign = "center";
          valign = "center";
        }
        # Username
        {
          monitor = "";
          text = "$USER";
          color = "rgba(235, 235, 245, 0.4)";
          font_size = 13;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, -48";
          halign = "center";
          valign = "center";
        }
      ];

      # Password input
      input-field = [
        {
          monitor = "";
          size = "280, 52";
          position = "0, -110";
          halign = "center";
          valign = "center";

          outline_thickness = 2;
          dots_size = 0.22;
          dots_spacing = 0.7;
          dots_center = true;
          dots_rounding = -1;

          outer_color = "rgba(255, 255, 255, 0.12)";
          inner_color = "rgba(22, 22, 24, 0.75)";
          font_color = "rgba(255, 255, 255, 0.85)";
          font_family = "JetBrainsMono Nerd Font";

          fade_on_empty = true;
          fade_timeout = 1000;
          placeholder_text = "Password";

          hide_input = true;
          rounding = 14;

          check_color = "rgb(48, 209, 88)";
          fail_color = "rgb(255, 69, 58)";
          fail_text = "Incorrect password";
          fail_transition = 300;

          capslock_color = "rgb(255, 159, 10)";
          numlock_color = "rgb(10, 132, 255)";

          shadow_passes = 3;
          shadow_size = 8;
          shadow_color = "rgba(0, 0, 0, 0.3)";
        }
      ];
    };
  };
}
