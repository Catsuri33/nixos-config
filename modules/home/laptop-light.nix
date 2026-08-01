{ pkgs, ... }:
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
  custom.librewolfPackage = pkgs.symlinkJoin {
    name = "librewolf-no-egl";
    paths = [ pkgs.librewolf ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/librewolf \
        --set __EGL_VENDOR_LIBRARY_FILENAMES /no-such-egl-vendor.json \
        --set VK_DRIVER_FILES /no-such-vulkan-icd.json \
        --set VK_ICD_FILENAMES /no-such-vulkan-icd.json
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
}
