{ config, pkgs, ... }:

{
  services.dunst = {
    enable = true;

    settings = {
      global = {
        follow = "mouse";
        origin = "top-right";
        offset = "12x12";
        width = 360;
        height = "0-200";
        notification_limit = 5;

        frame_width = 1;
        frame_color = "#ffffff14";
        separator_color = "#ffffff14";
        separator_height = 1;
        gap_size = 8;
        corner_radius = 16;

        padding = 14;
        horizontal_padding = 14;
        text_icon_padding = 10;

        font = "Inter 10";
        line_height = 2;
        markup = "full";
        format = "<b>%s</b>\\n%b";
        alignment = "left";
        vertical_alignment = "center";
        ellipsize = "end";
        shrink = "yes";

        icon_position = "left";
        min_icon_size = 40;
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

      # macOS notification banners: frosted glass (blurred by Hyprland,
      # see layer_rule in hyprland.nix), hairline edge, no accent colour
      # except red for critical ones.
      urgency_low = {
        background = "#2a2a2e8c";
        foreground = "#ebebf5bf";
        frame_color = "#ffffff1f";
        timeout = 4;
      };

      urgency_normal = {
        background = "#2a2a2e8c";
        foreground = "#ffffff";
        frame_color = "#ffffff1f";
        timeout = 6;
      };

      urgency_critical = {
        background = "#2a2a2ee0";
        foreground = "#ffffff";
        frame_color = "#ff453acc";
        timeout = 0;
      };
    };
  };
}
