{ pkgs, lib, ... }:
{
  # Root cause (full investigation in git history — see prior revisions of
  # this file for the coredump/ldd/objdump trail): Firefox/LibreWolf's
  # startup graphics probing loads Mesa's EGL vendor regardless of accel
  # prefs, and initializing LLVM's JIT somewhere in that path crashes here
  # ("LLVM ERROR: out of memory" / SIGSEGV). Same failure family as the
  # Nvidia hybrid-laptop bug (modules/home/nvidia.nix) — but there's no
  # second GPU vendor to hide behind on this Intel-only machine, and a
  # custom Mesa build without llvmpipe/Lavapipe/Rusticl still didn't avoid
  # it: GBM (mesa-libgbm, used for Wayland hardware buffer allocation) has
  # its DRI driver search path (`gbm-backends-path`) baked in at Mesa's own
  # *build* time to nixpkgs' system-wide /run/opengl-driver, which no
  # per-app env var (LIBGL_DRIVERS_PATH, __EGL_VENDOR_LIBRARY_FILENAMES)
  # can redirect — confirmed via coredump that libgallium.so kept loading
  # from the system's full default Mesa no matter what this wrapper set.
  # Actually fixing that would mean replacing hardware.graphics.package for
  # the whole system (Hyprland, virt-manager, everything), not just
  # LibreWolf — decided against that scope for this bug.
  #
  # Fix: skip Mesa's EGL vendor entirely (point GLVND at a vendor file that
  # doesn't exist) so LibreWolf never reaches the code path that crashes,
  # falling back to Firefox's own bundled software rasterizer (SWGL) —
  # confirmed this starts reliably. Trade-off: no WebGL/hardware-accelerated
  # compositing/video decode in the browser, CPU rendering only. Scoped to
  # this package only, not /run/opengl-driver, so nothing else on the
  # system is affected.
  #
  # MOZ_WEBRENDER=0: separate bug — images/video rendering as horizontal
  # stripes of corrupted pixels. SWGL (the software fallback above) still
  # runs WebRender's tiling/texture-atlas code, which has a known corruption
  # bug independent of GPU vs. software rendering. Disabling WebRender
  # falls back to Firefox's older Basic compositor instead, which avoids
  # that code path entirely. Same fix applied on the Nvidia hosts
  # (modules/home/nvidia.nix), where the same stripe bug was seen.
  custom.librewolfPackage = pkgs.symlinkJoin {
    name = "librewolf-no-egl";
    paths = [ pkgs.librewolf ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/librewolf \
        --set __EGL_VENDOR_LIBRARY_FILENAMES /no-such-egl-vendor.json \
        --set VK_DRIVER_FILES /no-such-vulkan-icd.json \
        --set VK_ICD_FILENAMES /no-such-vulkan-icd.json \
        --set MOZ_WEBRENDER 0
    '';
  };

  # Communication, sandboxed via Flatpak (custom.flatpakApps in
  # home/home.nix). Mattermost used to need a hardened_malloc exemption
  # wrapper (Electron's PartitionAlloc aborts under it); the Flatpak
  # runtime's own /etc doesn't carry the host preload, so it isn't needed.
  custom.flatpakApps = [
    "com.mattermost.Desktop"
    "us.zoom.Zoom"
  ];

  # Narrowed manifests (see custom.flatpakOverrides in home/home.nix).
  # Mattermost: no $HOME (downloads only), GPU only, Wayland only. Zoom
  # keeps devices=all for the webcam.
  custom.flatpakOverrides = {
    "com.mattermost.Desktop" = {
      Context = {
        filesystems = "!home;xdg-download;";
        devices = "!all;dri;";
        sockets = "!x11;fallback-x11;";
      };
      Environment.ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    };
    "us.zoom.Zoom".Context.sockets = "!x11;fallback-x11;";
  };

  # Password prompt every time a Discord window gets focus after focus was
  # somewhere else (polkit action in hosts/laptop-light/configuration.nix,
  # answered by hyprpolkitagent). Listens on Hyprland's event socket: on
  # focus, every Discord window is moved to a hidden special workspace
  # while the prompt is up, and back where it was once authenticated. On
  # cancel they stay hidden; launching Discord again brings them back (and
  # prompts). Moving focus to any other window locks it again.
  #
  # The prompt's own dialog takes focus too, and the focus events of the
  # unlock itself are still queued when pkcheck returns: "unlocking" waits
  # for Discord's focus (or 2 s) before focus elsewhere counts as leaving.
  systemd.user.services.discord-lock = {
    Unit = {
      Description = "Ask for the password when Discord gets focus";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = pkgs.writeShellScript "discord-lock" ''
        hyprctl=${pkgs.hyprland}/bin/hyprctl
        jq=${pkgs.jq}/bin/jq
        dispatch() { "$hyprctl" dispatch "$1" > /dev/null; }

        state=locked
        since=0
        class=
        ${pkgs.socat}/bin/socat -U - UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" |
        while IFS= read -r line; do
          # Each focus change is "activewindow>>class,title" followed by
          # "activewindowv2>>address".
          case "$line" in
            "activewindow>>"*) class="''${line#*>>}"; class="''${class%%,*}"; continue ;;
            "activewindowv2>>"*) addr="0x''${line#*>>}" ;;
            *) continue ;;
          esac

          if [ "$class" != discord ]; then
            if [ "$state" = unlocked ] ||
              { [ "$state" = unlocking ] && [ $((SECONDS - since)) -ge 2 ]; }; then
              state=locked
            fi
            continue
          fi
          case "$state" in
            unlocked) continue ;;
            unlocking) state=unlocked; continue ;;
          esac

          windows=$("$hyprctl" clients -j | "$jq" -r '.[]
            | select(.class == "discord" and .workspace.name != "special:discordlock")
            | "\(.address) \(.workspace.id)"')
          printf '%s\n' "$windows" | while read -r a ws; do
            [ -n "$a" ] && dispatch "hl.dsp.window.move({ workspace = \"special:discordlock\", window = \"address:$a\", follow = false })"
          done

          if ${pkgs.polkit}/bin/pkcheck --action-id local.discord.open \
            --process $$ --allow-user-interaction > /dev/null; then
            state=unlocking
            since=$SECONDS
            printf '%s\n' "$windows" | while read -r a ws; do
              [ -n "$a" ] && dispatch "hl.dsp.window.move({ workspace = \"$ws\", window = \"address:$a\", follow = false })"
            done
            dispatch "hl.dsp.focus({ window = \"address:$addr\" })"
          fi
        done
      '';
      Restart = "always";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Launcher entry: brings back Discord windows left hidden by a cancelled
  # prompt (onto the current workspace, which focuses them and prompts
  # again), otherwise starts Discord. Same ID as the Flatpak export so it
  # shadows it in the launcher and for discord:// links. Written to
  # ~/.local/share (XDG_DATA_HOME), not through xdg.desktopEntries: that
  # lands in the per-user profile, which comes after flatpak's exports in
  # XDG_DATA_DIRS and would lose.
  xdg.dataFile."applications/com.discordapp.Discord.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Discord
    GenericName=Internet Messenger
    Icon=com.discordapp.Discord
    Exec=${pkgs.writeShellScript "discord-open" ''
      hyprctl=${pkgs.hyprland}/bin/hyprctl
      jq=${pkgs.jq}/bin/jq
      hidden=$("$hyprctl" clients -j | "$jq" -r '.[]
        | select(.class == "discord" and .workspace.name == "special:discordlock")
        | .address')
      if [ -z "$hidden" ]; then
        exec flatpak run com.discordapp.Discord "$@"
      fi
      ws=$("$hyprctl" activeworkspace -j | "$jq" -r .id)
      for a in $hidden; do
        "$hyprctl" dispatch "hl.dsp.window.move({ workspace = \"$ws\", window = \"address:$a\", follow = false })" > /dev/null
      done
      "$hyprctl" dispatch "hl.dsp.focus({ window = \"address:''${hidden%%[[:space:]]*}\" })" > /dev/null
    ''} %U
    Categories=Network;InstantMessaging;
    MimeType=x-scheme-handler/discord;
    StartupWMClass=discord
  '';

  home.packages = with pkgs; [
    # Dev tools
    dbeaver-bin

    # Network analysis
    wireshark
  ];

  # This laptop's keyboard has no dedicated "Impr écran" key, so the
  # Print/Shift+Print binds in home/hyprland.nix are unreachable here.
  # Software-only equivalents on $mod so screenshots work regardless of
  # physical keyboard layout.
  #
  # $mod+O / $mod SHIFT+O: switch focus to / move the active window to the
  # other monitor. Needed once the USB-C dock is plugged in (see workspace
  # pinning below for the other half of the multi-monitor setup).
  # hl.bind (Lua config) takes a key combo string, a dispatcher call, and an
  # optional opts table — not the single hyprlang string — see
  # home/hyprland.nix for the configType = "lua" switch.
  wayland.windowManager.hyprland.settings.bind = [
    { _args = [ "SUPER + S" (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy")'') ]; }
    { _args = [ "SUPER + SHIFT + S" (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("grim - | wl-copy")'') ]; }
    { _args = [ "SUPER + O" (lib.generators.mkLuaInline ''hl.dsp.focus({ monitor = "+1" })'') ]; }
    { _args = [ "SUPER + SHIFT + O" (lib.generators.mkLuaInline ''hl.dsp.window.move({ monitor = "+1" })'') ]; }
  ];

  # Pin workspaces to a monitor so switching workspace never "steals" it from
  # the other screen (default Hyprland behaviour: activating a workspace that
  # already lives on the other monitor just moves focus over there, which
  # feels like both screens changed since input suddenly goes to the other
  # monitor). 1-5 stay on the laptop panel, 6-10 on the docked monitor.
  #
  # Matched by description (not "DP-1"/"DP-2"/etc.) because the connector
  # name Hyprland assigns to the dock's output depends on which USB-C port
  # it's plugged into and isn't stable across replugs.
  #
  # Nix attribute name must be "workspace_rule", not "workspace" — that's
  # the actual hl.* function name for this in the Lua config (hyprlang's
  # "workspace" keyword is exposed as hl.workspace_rule, not hl.workspace).
  wayland.windowManager.hyprland.settings.workspace_rule =
    (map
      (i: {
        workspace = toString i;
        monitor = "eDP-1";
        persistent = true;
      } // lib.optionalAttrs (i == 1) { default = true; })
      [ 1 2 3 4 5 ])
    ++ (map
      (i: {
        workspace = toString i;
        monitor = "desc:Dell Inc. DELL P2422HE BGNCYB3";
        persistent = true;
      } // lib.optionalAttrs (i == 6) { default = true; })
      [ 6 7 8 9 10 ]);
}
