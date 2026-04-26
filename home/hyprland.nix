{ config, pkgs, inputs, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;

    settings = {
      monitor = ",preferred,auto,1";

      exec-once = [
        "awww ~/.config/wallpaper.jpg"
        "waybar"
        "dunst"
      ];

      env = [
        "XCURSOR_SIZE,24"
        "XCURSOR_THEME,Adwaita"
      ];

      input = {
        kb_layout = "fr";
        follow_mouse = 1;
        sensitivity = 0;
        touchpad = {
          natural_scroll = true;
          disable_while_typing = true;
        };
      };

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgba(89b4faee) rgba(cba6f7ee) 45deg";
        "col.inactive_border" = "rgba(45475aaa)";
        layout = "dwindle";
        resize_on_border = true;
      };

      decoration = {
        rounding = 10;
        blur = {
          enabled = true;
          size = 5;
          passes = 2;
          new_optimizations = true;
        };
        shadow = {
          enabled = true;
          range = 8;
          render_power = 3;
          color = "rgba(1a1a2eee)";
        };
      };

      animations = {
        enabled = true;
        bezier = [
          "easeOut, 0.05, 0.9, 0.1, 1.05"
          "linear, 0.0, 0.0, 1.0, 1.0"
        ];
        animation = [
          "windows,     1, 6,  easeOut"
          "windowsOut,  1, 6,  default, popin 80%"
          "border,      1, 10, default"
          "fade,        1, 7,  default"
          "workspaces,  1, 5,  default"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
      };

      "$mod" = "SUPER";

      bind = [
        # Applications
        "$mod, Return, exec, kitty"
        "$mod, R,      exec, wofi --show drun"
        "$mod, L,      exec, hyprlock"

        # Gestion des fenêtres
        "$mod, Q,      killactive"
        "$mod, M,      exit"
        "$mod, V,      togglefloating"
        "$mod, F,      fullscreen"
        "$mod, P,      pseudo"
        "$mod, J,      togglesplit"

        # Focus
        "$mod, left,   movefocus, l"
        "$mod, right,  movefocus, r"
        "$mod, up,     movefocus, u"
        "$mod, down,   movefocus, d"
        "$mod, H,      movefocus, l"
        "$mod, L,      movefocus, r"
        "$mod, K,      movefocus, u"
        "$mod, J,      movefocus, d"

        # Déplacer les fenêtres
        "$mod SHIFT, left,  movewindow, l"
        "$mod SHIFT, right, movewindow, r"
        "$mod SHIFT, up,    movewindow, u"
        "$mod SHIFT, down,  movewindow, d"

        # Espaces de travail
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"

        # Envoyer une fenêtre vers un espace de travail
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"

        # Capture d'écran
        ", Print,       exec, grim -g \"$(slurp)\" - | wl-copy"
        "SHIFT, Print,  exec, grim - | wl-copy"
      ];

      # Touches multimédia
      bindel = [
        ", XF86AudioRaiseVolume,   exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume,   exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86MonBrightnessUp,    exec, brightnessctl set 10%+"
        ", XF86MonBrightnessDown,  exec, brightnessctl set 10%-"
      ];

      bindl = [
        ", XF86AudioMute,  exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioPlay,  exec, playerctl play-pause"
        ", XF86AudioNext,  exec, playerctl next"
        ", XF86AudioPrev,  exec, playerctl previous"
      ];

      # Souris
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      # Règles de fenêtres
      windowrule = [
        "float, class:pavucontrol"
        "float, class:nm-connection-editor"
      ];
    };
  };
}
