{ config, pkgs, ... }:

{
  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        disable_loading_bar = true;
        # No grace period: it also applied to the lock taken right before
        # suspend, so reopening the lid could unlock with a mouse move.
        grace = 0;
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

      # macOS Sonoma layout: date then a large clock near the top, user
      # name and password field near the bottom.
      label = [
        # Date
        {
          monitor = "";
          text = ''cmd[update:60000] echo "$(LC_TIME=en_US.UTF-8 date +"%A, %B %-d")"'';
          color = "rgba(255, 255, 255, 0.85)";
          font_size = 22;
          font_family = "Inter SemiBold";
          position = "0, -90";
          halign = "center";
          valign = "top";
          shadow_passes = 2;
          shadow_size = 4;
          shadow_color = "rgba(0, 0, 0, 0.3)";
        }
        # Time
        {
          monitor = "";
          # 10 s: minute-accurate without redrawing every second
          text = ''cmd[update:10000] echo "$(date +"%H:%M")"'';
          color = "rgba(255, 255, 255, 0.9)";
          font_size = 110;
          font_family = "Inter Display SemiBold";
          position = "0, -120";
          halign = "center";
          valign = "top";
          shadow_passes = 3;
          shadow_size = 6;
          shadow_color = "rgba(0, 0, 0, 0.3)";
        }
        # Username
        {
          monitor = "";
          text = "$DESC";
          color = "rgba(255, 255, 255, 0.92)";
          font_size = 14;
          font_family = "Inter SemiBold";
          position = "0, 150";
          halign = "center";
          valign = "bottom";
        }
      ];

      # Password input: small translucent pill, like macOS.
      input-field = [
        {
          monitor = "";
          size = "220, 36";
          position = "0, 100";
          halign = "center";
          valign = "bottom";

          outline_thickness = 1;
          dots_size = 0.22;
          dots_spacing = 0.5;
          dots_center = true;
          dots_rounding = -1;

          outer_color = "rgba(255, 255, 255, 0.18)";
          inner_color = "rgba(255, 255, 255, 0.16)";
          font_color = "rgba(255, 255, 255, 0.92)";
          font_family = "Inter";

          fade_on_empty = false;
          placeholder_text = "<span foreground=\"##ffffff99\">Enter Password</span>";

          hide_input = false;
          rounding = -1;

          check_color = "rgba(255, 255, 255, 0.3)";
          fail_color = "rgba(255, 69, 58, 0.6)";
          fail_text = "Incorrect password";
          fail_transition = 300;

          capslock_color = "rgba(255, 159, 10, 0.6)";
          numlock_color = -1;
          bothlock_color = -1;
        }
      ];
    };
  };
}
