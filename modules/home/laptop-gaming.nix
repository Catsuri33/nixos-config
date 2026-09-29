{ pkgs, lib, ... }:
{
  # Fn+F5 fan-profile toggle, equivalent to the Armoury Crate
  # Silent/Balanced/Performance switch on Windows. Cycles
  # /sys/firmware/acpi/platform_profile through whatever the firmware
  # exposes in platform_profile_choices — the EC applies its own fan curve
  # + CPU power limits per profile, same mechanism modules/nixos/thermal.nix
  # sets a default for. That module also makes the file group-writable by
  # "wheel" so this needs no sudo/pkexec.
  home.file.".local/bin/fan-profile-cycle" = {
    executable = true;
    source = pkgs.writeShellScript "fan-profile-cycle" ''
      set -euo pipefail

      profile_file=/sys/firmware/acpi/platform_profile
      choices_file=/sys/firmware/acpi/platform_profile_choices

      if [ ! -e "$profile_file" ] || [ ! -e "$choices_file" ]; then
        ${pkgs.libnotify}/bin/notify-send -u critical "Ventilateur" \
          "platform_profile introuvable (asus-wmi non chargé ?)"
        exit 1
      fi

      read -r current < "$profile_file"
      read -ra choices < "$choices_file"

      next_idx=0
      for i in "''${!choices[@]}"; do
        if [ "''${choices[$i]}" = "$current" ]; then
          next_idx=$(( (i + 1) % ''${#choices[@]} ))
          break
        fi
      done
      next="''${choices[$next_idx]}"

      echo "$next" > "$profile_file"

      case "$next" in
        low-power|quiet) label="Silencieux" ;;
        balanced)         label="Équilibré" ;;
        performance)      label="Performance" ;;
        *)                label="$next" ;;
      esac

      ${pkgs.libnotify}/bin/notify-send -u low -t 2000 "Profil ventilateur" "$label"
    '';
  };

  # Best-effort key mapping: ASUS's asus-wmi driver reports this hotkey as
  # evdev KEY_PROG1, which the default xkb keymap resolves to XF86Launch1 —
  # unverified on this specific TUF model. If the key does nothing, run
  # `nix run nixpkgs#wev` on laptop-gaming, press Fn+F5, and swap in
  # whatever keysym it actually reports.
  wayland.windowManager.hyprland.settings.bind = [
    { _args = [ "XF86Launch1" (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("$HOME/.local/bin/fan-profile-cycle")'') ]; }
  ];
}
