{ config, pkgs, ... }:

{
  services.dunst = {
    enable = true;

    settings = {
      global = {
        follow = "mouse";
        origin = "top-right";
        offset = "12x12";
        width = 340;
        height = "0-200";
        notification_limit = 5;

        frame_width = 1;
        frame_color = "#ffffff14";
        separator_color = "#ffffff14";
        separator_height = 1;
        gap_size = 8;
        corner_radius = 14;

        padding = 14;
        horizontal_padding = 14;
        text_icon_padding = 10;

        font = "JetBrainsMono Nerd Font 10";
        line_height = 2;
        markup = "full";
        format = "<b>%s</b>\\n%b";
        alignment = "left";
        vertical_alignment = "center";
        ellipsize = "end";
        shrink = "yes";

        icon_position = "left";
        min_icon_size = 32;
        max_icon_size = 48;

        progress_bar = true;
        progress_bar_height = 8;
        progress_bar_frame_width = 0;
        progress_bar_min_width = 200;

        stack_duplicates = true;
        sticky_history = "yes";
        history_length = 20;

        mouse_left_click = "close_current";
        mouse_middle_click = "do_action, close_current";
        mouse_right_click = "close_all";
      };

      # Matches the waybar/hyprlock palette: translucent macOS-style dark
      # background, systemBlue/systemRed accent frames.
      urgency_low = {
        background = "#161618d1";
        foreground = "#ebebf5bf";
        frame_color = "#ffffff14";
        timeout = 4;
      };

      urgency_normal = {
        background = "#161618d1";
        foreground = "#ffffff";
        frame_color = "#0a84ffcc";
        timeout = 6;
      };

      urgency_critical = {
        background = "#1c1c1ef5";
        foreground = "#ffffff";
        frame_color = "#ff453acc";
        timeout = 0;
      };
    };
  };
}
