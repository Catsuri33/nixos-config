{ ... }:
{
  # Baseline AC/BAT tuning so the normal "just unplugged"/"plugged in" case
  # is already battery-friendly without touching the manual toggle below.
  # On laptop-gaming this layers on top of thermal.nix's platform_profile
  # settings (different TLP keys, so both merge into the same services.tlp).
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
    };
  };

  # Lets the SUPER+SHIFT+B battery-saver toggle (modules/home/laptop.nix)
  # write these sysfs nodes as a normal user, same tmpfiles trick thermal.nix
  # uses for platform_profile. Globs match every core present at boot;
  # cpufreq/intel_pstate expose both nodes well before tmpfiles-setup.service
  # runs.
  systemd.tmpfiles.rules = [
    "z /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 0664 root wheel - -"
    "z /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference 0664 root wheel - -"
  ];
}
