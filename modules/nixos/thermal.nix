{ ... }:
{
  # Intel Thermal Daemon: watches the CPU/skin thermal zones and proactively
  # throttles P-states as temperature approaches the critical trip point,
  # instead of relying on the kernel's last-resort emergency shutdown. This
  # is the standard fix for a laptop CPU riding near Tjmax under sustained
  # load (e.g. gaming).
  services.thermald.enable = true;

  # TLP, used here purely for its ACPI platform-profile switching (not
  # battery tuning — this host is mostly plugged in). ASUS TUF laptops
  # expose /sys/firmware/acpi/platform_profile via the asus-wmi kernel
  # driver, and this is the same profile switch as the Windows Armoury
  # Crate "Performance/Balanced/Silent" toggle: the EC applies its own fan
  # curve + CPU power limits (PL1/PL2) per profile in firmware, so this is
  # real fan/thermal control without needing a vendor-specific daemon.
  # "balanced" on AC caps sustained power draw (and heat) below the
  # firmware's "performance" profile; switch to "performance" at runtime
  # with `sudo tlp ac` after editing this, or temporarily via
  # `echo performance | sudo tee /sys/firmware/acpi/platform_profile`
  # if a game needs the extra headroom.
  services.tlp = {
    enable = true;
    settings = {
      PLATFORM_PROFILE_ON_AC = "balanced";
      PLATFORM_PROFILE_ON_BAT = "low-power";
    };
  };

  # Let the manual Fn+F5-style toggle (modules/home/laptop-gaming.nix) write
  # this file directly as a normal user (lmichault is in "wheel", see
  # base.nix), instead of needing sudo on every press. Root-owned/0644 by
  # default. Applied by systemd-tmpfiles at boot — the asus-wmi driver that
  # creates this sysfs attribute loads well before tmpfiles-setup.service
  # runs, so the path already exists by the time this rule applies.
  systemd.tmpfiles.rules = [
    "z /sys/firmware/acpi/platform_profile 0664 root wheel - -"
  ];
}
