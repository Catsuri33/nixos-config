{ pkgs, lib, ... }:
{
  # Low battery notifications (warning at 20%, critical at 10%, shutdown at 3%)
  services.batsignal = {
    enable = true;
    extraArgs = [ "-w" "20" "-c" "10" "-d" "3" "-n" "BAT0" ];
  };

  # SUPER+SHIFT+B: manual battery-saver toggle, independent of AC/BAT state
  # (unlike TLP's automatic switching in modules/nixos/power-saving.nix) —
  # for stretching a meeting/flight on battery on purpose. Drops every CPU
  # to the "powersave" governor + "power" energy_performance_preference and
  # dims the screen; toggling again restores exactly what was there before.
  # modules/nixos/power-saving.nix makes those sysfs nodes group-writable by
  # "wheel" so this needs no sudo/pkexec, same trick as the platform_profile
  # toggle in laptop-gaming.nix.
  home.file.".local/bin/power-saving-toggle" = {
    executable = true;
    source = pkgs.writeShellScript "power-saving-toggle" ''
      set -euo pipefail

      state_dir="''${XDG_RUNTIME_DIR:-/tmp}/power-saving"
      marker="$state_dir/on"
      governors=(/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_governor)
      epps=(/sys/devices/system/cpu/cpu[0-9]*/cpufreq/energy_performance_preference)

      notify() {
        ${pkgs.libnotify}/bin/notify-send -u low -t 2000 "Économie d'énergie" "$1"
      }

      if [ -e "$marker" ]; then
        # OFF: restore whatever was in place before activation.
        if [ -e "$state_dir/governor" ]; then
          while read -r f v; do echo "$v" > "$f" 2>/dev/null || true; done < "$state_dir/governor"
        fi
        if [ -e "$state_dir/epp" ]; then
          while read -r f v; do echo "$v" > "$f" 2>/dev/null || true; done < "$state_dir/epp"
        fi
        ${pkgs.brightnessctl}/bin/brightnessctl -r >/dev/null
        rm -rf "$state_dir"
        notify "Désactivé"
      else
        # ON: snapshot current values so they can be restored later, then
        # push everything to its most battery-friendly setting.
        mkdir -p "$state_dir"
        : > "$state_dir/governor"
        : > "$state_dir/epp"
        for f in "''${governors[@]}"; do
          [ -e "$f" ] || continue
          read -r v < "$f"
          echo "$f $v" >> "$state_dir/governor"
          echo powersave > "$f" 2>/dev/null || true
        done
        for f in "''${epps[@]}"; do
          [ -e "$f" ] || continue
          read -r v < "$f"
          echo "$f $v" >> "$state_dir/epp"
          echo power > "$f" 2>/dev/null || true
        done
        ${pkgs.brightnessctl}/bin/brightnessctl -s set 30% >/dev/null
        touch "$marker"
        notify "Activé (CPU en powersave, luminosité réduite)"
      fi
    '';
  };

  wayland.windowManager.hyprland.settings.bind = [
    { _args = [ "SUPER + SHIFT + B" (lib.generators.mkLuaInline ''hl.dsp.exec_cmd("$HOME/.local/bin/power-saving-toggle")'') ]; }
  ];
}
