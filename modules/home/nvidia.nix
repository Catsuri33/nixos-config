{ pkgs, ... }:
{
  wayland.windowManager.hyprland.settings.env = [
    "LIBVA_DRIVER_NAME,nvidia"
    "GBM_BACKEND,nvidia-drm"
    "__GLX_VENDOR_LIBRARY_NAME,nvidia"
    "NVD_BACKEND,direct"
    "WLR_NO_HARDWARE_CURSORS,1"
  ];

  # GLVND's generic EGL vendor discovery (__eglLoadVendors) enumerates every
  # installed EGL ICD, not just the one apps end up using — on this hybrid
  # Intel/NVIDIA laptop that includes Mesa's, whose dlopen chain pulls in
  # libLLVM.so. Loading libLLVM.so.21.1 inside a Firefox-family process
  # (libxul.so, mozjemalloc) crashes during its own static initializers
  # ("LLVM ERROR: out of memory" / SIGSEGV in AsmWriter.cpp's global
  # constructor) even though the browser never intended to use Mesa/llvmpipe
  # — confirmed via core dump backtrace, and reproduced identically outside
  # any browser by force-loading llvmpipe directly (glxgears/glxinfo work
  # fine standalone, so libLLVM.so itself isn't broken — only loading it via
  # this dlopen path from inside Firefox is). Restricting GLVND to the
  # NVIDIA vendor file only skips Mesa's EGL vendor entirely, avoiding the
  # dlopen that triggers it.
  #
  # Scoped to just this binary (not Hyprland's session-wide env) because
  # setting it globally starves everything else in the session that still
  # needs Mesa's EGL vendor (e.g. software/llvmpipe fallback paths), which
  # made Hyprland itself fail to start right after login — greeter login
  # loop.
  #
  # MOZ_WEBRENDER=0: separate bug from the crash above — images/video
  # rendering as horizontal stripes of corrupted pixels, a known WebRender
  # texture-atlas/tiling bug that reproduces under both GPU and software
  # (SWGL) WebRender. Disabling WebRender falls back to Firefox's older
  # Basic compositor, which doesn't share that tiling code path.
  custom.librewolfPackage = pkgs.symlinkJoin {
    name = "librewolf-egl-fixed";
    paths = [ pkgs.librewolf ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/librewolf \
        --set __EGL_VENDOR_LIBRARY_FILENAMES /run/opengl-driver/share/glvnd/egl_vendor.d/10_nvidia.json \
        --set MOZ_WEBRENDER 0
    '';
  };
}
