# Secure Boot with your own keys, via lanzaboote — the desktop analogue of
# GrapheneOS's verified boot. NOT imported for laptop-gaming: that host is
# live, and enabling this requires a manual, physical step first (put the
# firmware in Setup Mode, enroll keys with sbctl) — see README.md for the
# runbook. Wiring this in blind would risk an unattended nixos-rebuild
# (system.autoUpgrade runs weekly) breaking the boot chain.
{ pkgs, lib, ... }:
{
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/etc/secureboot";
  };

  environment.systemPackages = [ pkgs.sbctl ];
}
