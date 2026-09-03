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

  home.packages = with pkgs; [
    # Communication
    mattermost-desktop

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
