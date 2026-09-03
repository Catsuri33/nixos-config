{ config, pkgs, lib, inputs, ... }:

let
  mod = "SUPER";

  mkBind = combo: dispatcher: { _args = [ combo (lib.generators.mkLuaInline dispatcher) ]; };
  mkBindOpts = combo: dispatcher: opts: { _args = [ combo (lib.generators.mkLuaInline dispatcher) opts ]; };

  # QWERTY key -> workspace number, AZERTY key -> same workspace number.
  workspaceKeys = [
    { qwerty = "1"; azerty = "ampersand"; ws = "1"; }
    { qwerty = "2"; azerty = "eacute"; ws = "2"; }
    { qwerty = "3"; azerty = "quotedbl"; ws = "3"; }
    { qwerty = "4"; azerty = "apostrophe"; ws = "4"; }
    { qwerty = "5"; azerty = "parenleft"; ws = "5"; }
    { qwerty = "6"; azerty = "minus"; ws = "6"; }
    { qwerty = "7"; azerty = "egrave"; ws = "7"; }
    { qwerty = "8"; azerty = "underscore"; ws = "8"; }
    { qwerty = "9"; azerty = "ccedilla"; ws = "9"; }
    { qwerty = "0"; azerty = "agrave"; ws = "10"; }
  ];

  focusWorkspaceBinds = builtins.concatMap (k: [
    (mkBind "${mod} + ${k.qwerty}" ''hl.dsp.focus({ workspace = "${k.ws}" })'')
    (mkBind "${mod} + ${k.azerty}" ''hl.dsp.focus({ workspace = "${k.ws}" })'')
  ]) workspaceKeys;

  moveToWorkspaceBinds = builtins.concatMap (k: [
    (mkBind "${mod} + SHIFT + ${k.qwerty}" ''hl.dsp.window.move({ workspace = "${k.ws}" })'')
    (mkBind "${mod} + SHIFT + ${k.azerty}" ''hl.dsp.window.move({ workspace = "${k.ws}" })'')
  ]) workspaceKeys;
in

{
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";

    settings = {
      monitor = {
        output = "";
        mode = "preferred";
        position = "auto";
        # hl.monitor's "scale" field parses a string (e.g. "auto" or "1"), not a number.
        scale = "1";
      };

      env = [
        { _args = [ "XCURSOR_SIZE" "24" ]; }
        { _args = [ "XCURSOR_THEME" "Adwaita" ]; }
      ];

      # hl.config walks nested tables into dotted config keys, so this mirrors
      # the old hyprlang "general:col.active_border"-style nesting directly.
      config = {
        general = {
          gaps_in = 6;
          gaps_out = 12;
          border_size = 1;
          col = {
            active_border = {
              colors = [ "rgba(0a84ffcc)" "rgba(60c3ffcc)" ];
              angle = 45;
            };
            inactive_border = "rgba(ffffff14)";
          };
          layout = "dwindle";
          resize_on_border = true;
        };

        decoration = {
          rounding = 12;
          blur = {
            enabled = true;
            size = 8;
            passes = 3;
            new_optimizations = true;
            xray = false;
          };
          shadow = {
            enabled = true;
            range = 20;
            render_power = 3;
            color = "rgba(00000055)";
            color_inactive = "rgba(00000030)";
          };
          inactive_opacity = 0.96;
        };

        animations.enabled = true;

        dwindle.preserve_split = true;

        misc = {
          force_default_wallpaper = 0;
          disable_hyprland_logo = true;
        };

        input = {
          kb_layout = "fr";
          follow_mouse = 1;
          sensitivity = 0;
          numlock_by_default = true;
          touchpad = {
            natural_scroll = true;
            disable_while_typing = true;
          };
        };
      };

      curve = [
        (mkBind "easeOut" ''{ type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } }'')
        (mkBind "linear" ''{ type = "bezier", points = { {0.0, 0.0}, {1.0, 1.0} } }'')
      ];

      animation = [
        { leaf = "windows"; enabled = true; speed = 6; bezier = "easeOut"; }
        {
          leaf = "windowsOut";
          enabled = true;
          speed = 6;
          bezier = "default";
          style = "popin 80%";
        }
        { leaf = "border"; enabled = true; speed = 10; bezier = "default"; }
        { leaf = "fade"; enabled = true; speed = 7; bezier = "default"; }
        { leaf = "workspaces"; enabled = true; speed = 5; bezier = "default"; }
      ];

      # systemd activation gets its own hl.on("hyprland.start", ...) from
      # home-manager already; this is the exec-once equivalent for the rest.
      on = [
        {
          _args = [
            "hyprland.start"
            (lib.generators.mkLuaInline ''
              function()
                hl.exec_cmd("uwsm app -- awww-daemon")
                hl.exec_cmd("uwsm app -- $HOME/.local/bin/wallpaper-rotate")
                hl.exec_cmd("uwsm app -- $HOME/.local/bin/wallpaper-monitor-watch")
                hl.exec_cmd("uwsm app -- waybar")
                hl.exec_cmd("uwsm app -- nm-applet --indicator")
                hl.exec_cmd("uwsm app -- vicinae server")
              end
            '')
          ];
        }
      ];

      bind =
        [
          # Applications
          (mkBind "${mod} + Return" ''hl.dsp.exec_cmd("kitty")'')
          (mkBind "${mod} + R" ''hl.dsp.exec_cmd("vicinae toggle")'')
          (mkBind "${mod} + SHIFT + L" ''hl.dsp.exec_cmd("hyprlock")'')

          # Window management
          (mkBind "${mod} + Q" ''hl.dsp.window.close()'')
          (mkBind "${mod} + M" ''hl.dsp.exit()'')
          (mkBind "${mod} + V" ''hl.dsp.window.float()'')
          (mkBind "${mod} + F" ''hl.dsp.window.fullscreen()'')
          (mkBind "${mod} + P" ''hl.dsp.window.pseudo()'')

          # Focus
          (mkBind "${mod} + left" ''hl.dsp.focus({ direction = "left" })'')
          (mkBind "${mod} + right" ''hl.dsp.focus({ direction = "right" })'')
          (mkBind "${mod} + up" ''hl.dsp.focus({ direction = "up" })'')
          (mkBind "${mod} + down" ''hl.dsp.focus({ direction = "down" })'')
          (mkBind "${mod} + H" ''hl.dsp.focus({ direction = "left" })'')
          (mkBind "${mod} + L" ''hl.dsp.focus({ direction = "right" })'')
          (mkBind "${mod} + K" ''hl.dsp.focus({ direction = "up" })'')
          (mkBind "${mod} + J" ''hl.dsp.focus({ direction = "down" })'')

          # Move windows
          (mkBind "${mod} + SHIFT + left" ''hl.dsp.window.move({ direction = "left" })'')
          (mkBind "${mod} + SHIFT + right" ''hl.dsp.window.move({ direction = "right" })'')
          (mkBind "${mod} + SHIFT + up" ''hl.dsp.window.move({ direction = "up" })'')
          (mkBind "${mod} + SHIFT + down" ''hl.dsp.window.move({ direction = "down" })'')
        ]
        ++ focusWorkspaceBinds
        ++ moveToWorkspaceBinds
        ++ [
          # Screenshot
          (mkBind "Print" ''hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy")'')
          (mkBind "SHIFT + Print" ''hl.dsp.exec_cmd("grim - | wl-copy")'')

          # Toggle keyboard layout (AZERTY/QWERTY)
          (mkBind "${mod} + Space" ''
            hl.dsp.exec_cmd("if hyprctl -j getoption input:kb_layout | grep -q '\"fr\"'; then hyprctl keyword input:kb_layout us; else hyprctl keyword input:kb_layout fr; fi")
          '')

          # Media keys: repeat while held, and still trigger while the session is locked.
          (mkBindOpts "XF86AudioRaiseVolume" ''hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+")'' { repeating = true; locked = true; })
          (mkBindOpts "XF86AudioLowerVolume" ''hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")'' { repeating = true; locked = true; })
          (mkBindOpts "XF86MonBrightnessUp" ''hl.dsp.exec_cmd("brightnessctl set 10%+")'' { repeating = true; locked = true; })
          (mkBindOpts "XF86MonBrightnessDown" ''hl.dsp.exec_cmd("brightnessctl set 10%-")'' { repeating = true; locked = true; })

          # Media keys: single trigger, still works while the session is locked.
          (mkBindOpts "XF86AudioMute" ''hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")'' { locked = true; })
          (mkBindOpts "XF86AudioPlay" ''hl.dsp.exec_cmd("playerctl play-pause")'' { locked = true; })
          (mkBindOpts "XF86AudioNext" ''hl.dsp.exec_cmd("playerctl next")'' { locked = true; })
          (mkBindOpts "XF86AudioPrev" ''hl.dsp.exec_cmd("playerctl previous")'' { locked = true; })

          # Mouse
          (mkBind "${mod} + mouse:272" ''hl.dsp.window.drag()'')
          (mkBind "${mod} + mouse:273" ''hl.dsp.window.resize()'')
        ];
    };
  };
}
