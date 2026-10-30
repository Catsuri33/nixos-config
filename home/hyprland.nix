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
    # uwsm (modules/nixos/base.nix) owns the session units. home-manager's
    # own hyprland-session.target stops/restarts itself on startup and
    # propagates that stop to graphical-session.target, which makes uwsm
    # tear down the compositor right after login.
    systemd.enable = false;

    settings = {
      monitor = {
        output = "";
        mode = "preferred";
        position = "auto";
        # hl.monitor's "scale" field parses a string (e.g. "auto" or "1"), not a number.
        scale = "1";
      };

      env = [
        # Apple cursor, installed by home.pointerCursor (home/theme.nix).
        { _args = [ "XCURSOR_SIZE" (toString config.home.pointerCursor.size) ]; }
        { _args = [ "XCURSOR_THEME" config.home.pointerCursor.name ]; }
      ];

      # Frosted glass behind the menu bar, notifications and OSD, like
      # macOS vibrancy. ignore_alpha keeps the blur off the fully
      # transparent margins around the notifications.
      layer_rule = [
        {
          name = "macos-vibrancy";
          match.namespace = "^(waybar|notifications|swayosd)$";
          blur = true;
          ignore_alpha = 0.1;
        }
      ];

      # Screen capture allowed without a prompt for these binaries only,
      # matched on the client's resolved executable (wrapped programs run
      # as .<name>-wrapped, hence the whole store path). The portal covers
      # screen sharing for every sandboxed app, which goes through its own
      # picker anyway; hyprlock needs it for its blurred-screenshot
      # background.
      permission = map (pkg: {
        _args = [ "${lib.escapeRegex "${pkg}"}/.*" "screencopy" "allow" ];
      }) [
        pkgs.xdg-desktop-portal-hyprland
        pkgs.grim
        pkgs.hyprpicker
        pkgs.wf-recorder
        config.programs.hyprlock.package
      ];

      # hl.config walks nested tables into dotted config keys, so this mirrors
      # the old hyprlang "general:col.active_border"-style nesting directly.
      config = {
        general = {
          gaps_in = 5;
          gaps_out = 10;
          # macOS windows only have a hairline light edge, no accent border;
          # focus shows through the shadow instead.
          border_size = 1;
          col = {
            active_border = "rgba(ffffff26)";
            inactive_border = "rgba(ffffff0f)";
          };
          layout = "dwindle";
          resize_on_border = true;
        };

        decoration = {
          rounding = 12;
          blur = {
            enabled = true;
            size = 10;
            passes = 3;
            new_optimizations = true;
            xray = false;
            # Vibrancy: blurred background keeps its colours, like macOS
            # materials, instead of turning grey.
            vibrancy = 0.25;
            noise = 0.015;
          };
          # Large, soft drop shadow: the main cue of which window is in
          # front on macOS. Inactive windows get a lighter one.
          shadow = {
            enabled = true;
            range = 36;
            render_power = 3;
            color = "rgba(00000070)";
            color_inactive = "rgba(00000038)";
          };
        };

        animations.enabled = true;

        dwindle.preserve_split = true;

        misc = {
          force_default_wallpaper = 0;
          disable_hyprland_logo = true;
        };

        # Without it any Wayland client (Flatpak apps included, they get
        # the Wayland socket) can capture the screen silently through
        # wlr-screencopy. With it, a client not allowed below gets a
        # hyprland-dialog prompt instead. See `permission` further down.
        ecosystem.enforce_permissions = true;

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
        # Apple's ease-out: fast start, long gentle settle, no overshoot.
        (mkBind "apple" ''{ type = "bezier", points = { {0.25, 1.0}, {0.5, 1.0} } }'')
      ];

      # Windows scale in/out from 90% like macOS app launch/close, and
      # workspaces slide sideways like switching Spaces.
      animation = [
        { leaf = "windows"; enabled = true; speed = 4; bezier = "apple"; style = "popin 90%"; }
        { leaf = "windowsOut"; enabled = true; speed = 3; bezier = "apple"; style = "popin 90%"; }
        { leaf = "windowsMove"; enabled = true; speed = 4; bezier = "apple"; }
        { leaf = "layers"; enabled = true; speed = 3; bezier = "apple"; style = "fade"; }
        { leaf = "border"; enabled = true; speed = 10; bezier = "default"; }
        { leaf = "fade"; enabled = true; speed = 4; bezier = "apple"; }
        { leaf = "workspaces"; enabled = true; speed = 5; bezier = "apple"; style = "slide"; }
      ];

      # exec-once equivalent; session/systemd activation is left to uwsm.
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
          (mkBind "${mod} + SHIFT + L" ''hl.dsp.exec_cmd("loginctl lock-session")'')
          # Light/dark appearance for every app (home/theme.nix)
          (mkBind "${mod} + SHIFT + D" ''hl.dsp.exec_cmd("appearance toggle")'')

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
          # swayosd-client changes the level and shows the macOS-style HUD.
          (mkBindOpts "XF86AudioRaiseVolume" ''hl.dsp.exec_cmd("swayosd-client --output-volume +5")'' { repeating = true; locked = true; })
          (mkBindOpts "XF86AudioLowerVolume" ''hl.dsp.exec_cmd("swayosd-client --output-volume -5")'' { repeating = true; locked = true; })
          (mkBindOpts "XF86MonBrightnessUp" ''hl.dsp.exec_cmd("swayosd-client --brightness +10")'' { repeating = true; locked = true; })
          (mkBindOpts "XF86MonBrightnessDown" ''hl.dsp.exec_cmd("swayosd-client --brightness -10")'' { repeating = true; locked = true; })

          # Media keys: single trigger, still works while the session is locked.
          (mkBindOpts "XF86AudioMute" ''hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle")'' { locked = true; })
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
