# Secure Boot with your own keys, via lanzaboote — the desktop analogue of
# GrapheneOS's verified boot. Imported by all three hosts (flake.nix).
# Before the first rebuild with it on a host that's already installed, the
# firmware must be put in Setup Mode and keys enrolled with sbctl — see
# README.md for the runbook — or the new boot chain won't be trusted.
{ pkgs, lib, ... }:
{
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote = {
    enable = true;
    # sbctl's actual default key location (not /etc/secureboot — sbctl 0.18
    # writes there unless told otherwise via --database-path/config file).
    pkiBundle = "/var/lib/sbctl";
  };

  environment.systemPackages = [ pkgs.sbctl ];
}
