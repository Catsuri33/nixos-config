{ config, pkgs, lib, ... }:

# macOS-like look shared by every toolkit: WhiteSur (Big Sur/Sonoma clone)
# for GTK, icons and Kvantum, Apple's own cursor, Inter as the San
# Francisco stand-in (SF Pro's licence forbids redistribution, so it isn't
# in nixpkgs).
#
# Apps are light by default; `appearance toggle` (SUPER+SHIFT+D) flips
# them to dark and back. The current mode lives in
# ~/.local/state/appearance, not in this config, so a rebuild doesn't
# undo the last toggle.

let
  cursor = {
    package = pkgs.apple-cursor;
    name = "macOS";
    size = 24;
  };

  gtkTheme = pkgs.whitesur-gtk-theme;

  # Applies light/dark to every toolkit at once:
  # - dconf color-scheme: libadwaita, GTK4, Electron/Chromium, Firefox and
  #   kitty (through the portal's Settings interface), live.
  # - dconf gtk-theme/icon-theme: GTK3 apps on Wayland read these over
  #   settings.ini, live.
  # - ~/.config/gtk-4.0/gtk.css: libadwaita ignores gtk-theme, so
  #   WhiteSur is imported as user CSS; read when an app starts.
  # - Kvantum: read when a Qt app starts.
  appearance = pkgs.writeShellApplication {
    name = "appearance";
    runtimeInputs = [ pkgs.dconf pkgs.libnotify pkgs.coreutils ];
    text = ''
      state="''${XDG_STATE_HOME:-$HOME/.local/state}/appearance"
      mode=$(cat "$state" 2>/dev/null || echo light)

      case "''${1:-apply}" in
        toggle) if [ "$mode" = dark ]; then mode=light; else mode=dark; fi ;;
        light|dark) mode=$1 ;;
        apply) ;;
        *) echo "usage: appearance [light|dark|toggle|apply]" >&2; exit 1 ;;
      esac

      if [ "$mode" = dark ]; then
        scheme=prefer-dark gtk=WhiteSur-Dark icons=WhiteSur-dark kvantum=WhiteSurDark
      else
        scheme=default gtk=WhiteSur-Light icons=WhiteSur-light kvantum=WhiteSur
      fi

      mkdir -p "$(dirname "$state")" "${config.xdg.configHome}/gtk-4.0" "${config.xdg.configHome}/Kvantum"
      echo "$mode" > "$state"

      dconf write /org/gnome/desktop/interface/color-scheme "'$scheme'"
      dconf write /org/gnome/desktop/interface/gtk-theme "'$gtk'"
      dconf write /org/gnome/desktop/interface/icon-theme "'$icons'"

      rm -f "${config.xdg.configHome}/gtk-4.0/gtk.css" "${config.xdg.configHome}/Kvantum/kvantum.kvconfig"
      echo "@import url(\"file://${gtkTheme}/share/themes/$gtk/gtk-4.0/gtk.css\");" \
        > "${config.xdg.configHome}/gtk-4.0/gtk.css"
      printf '[General]\ntheme=%s\n' "$kvantum" > "${config.xdg.configHome}/Kvantum/kvantum.kvconfig"

      if [ "''${1:-apply}" != apply ]; then
        notify-send -a Appearance -t 1500 "''${mode^} appearance"
      fi
    '';
  };
in

{
  # Without an installed cursor theme XCURSOR_THEME pointed at nothing and
  # clients fell back to the bare X core cursor, nearly invisible on a
  # dark background. Linked into ~/.icons and ~/.local/share/icons, with
  # icons/default inheriting from it for apps that ignore XCURSOR_THEME.
  home.pointerCursor = cursor // {
    enable = true;
    gtk.enable = true;
    x11.enable = true;
  };

  home.packages = [ appearance ];

  # settings.ini only holds the light defaults (fallback for apps that
  # don't read dconf); `appearance` overrides them through dconf.
  gtk = {
    enable = true;
    font = {
      name = "Inter";
      size = 11;
    };
    theme = {
      name = "WhiteSur-Light";
      package = gtkTheme;
    };
    iconTheme = {
      name = "WhiteSur-light";
      package = pkgs.whitesur-icon-theme;
    };
    gtk3.extraConfig.gtk-decoration-layout = "close,minimize,maximize:";
    # gtk-4.0/gtk.css is written by `appearance` instead: a store link
    # couldn't switch between the light and dark CSS.
    gtk4.theme = null;
    gtk4.extraConfig.gtk-decoration-layout = "close,minimize,maximize:";
  };

  # color-scheme, gtk-theme and icon-theme are left to `appearance`:
  # setting them here would reset the user's choice on every switch.
  dconf.settings."org.gnome.desktop.interface" = {
    font-name = "Inter 11";
    cursor-theme = cursor.name;
    cursor-size = cursor.size;
  };
  dconf.settings."org.gnome.desktop.wm.preferences".button-layout = "close,minimize,maximize:";

  # Reapply the saved mode after each switch: also replaces the
  # gtk-4.0/gtk.css link earlier generations left behind.
  home.activation.appearance = lib.hm.dag.entryAfter [ "linkGeneration" "dconfSettings" ] ''
    if [ -n "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
      run ${lib.getExe appearance} apply || true
    else
      run ${pkgs.dbus}/bin/dbus-run-session ${lib.getExe appearance} apply || true
    fi
  '';

  qt = {
    enable = true;
    platformTheme.name = "kvantum";
    style.name = "kvantum";
    # kvantum.kvconfig (the active theme) is written by `appearance`.
    kvantum = {
      enable = true;
      themes = [ pkgs.whitesur-kde ];
    };
  };
}
