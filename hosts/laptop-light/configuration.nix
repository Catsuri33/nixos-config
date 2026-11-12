{ pkgs, lib, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/power-saving.nix
  ];

  networking.hostName = "laptop-light";
  networking.hosts."162.38.114.139" = [ "gitlab.polytech.umontpellier.fr" ];
  hardware.enableRedistributableFirmware = true;

  # Thermal: the shared power-saving.nix puts AC on the "performance"
  # governor, which under intel_pstate pins EPP to performance and keeps
  # this 15W Core Ultra 7 165U boosting to 4.9 GHz at the slightest load,
  # riding ~90°C in a thin chassis. intel_pstate's "powersave" is still
  # fully dynamic (it ramps up on demand), and with balance_performance
  # EPP the cores stop sitting at max turbo when idle-ish. thermald adds
  # proactive throttling before the firmware's own trip points.
  services.tlp.settings.CPU_SCALING_GOVERNOR_ON_AC = lib.mkForce "powersave";
  services.thermald.enable = true;

  # Boot splash: the default "bgrt" theme redraws the firmware's HP logo
  # (ACPI BGRT) with the Nix snowflake underneath, like Arch/Debian do.
  # Also gives a graphical LUKS passphrase prompt (systemd initrd).
  # Kernel/initrd output is silenced so it doesn't scribble over the splash.
  boot.plymouth.enable = true;
  boot.consoleLogLevel = 3;
  boot.kernelParams = [ "quiet" "splash" "udev.log_level=3" "systemd.show_status=auto" ];
  # Early KMS: plymouth ignores simpledrm and waits for a real DRM driver,
  # so without i915 in the initrd it only gets a display ~1s before greetd
  # starts, leaving a black screen for the whole boot. The modules closure
  # pulls i915's firmware (GuC/DMC) into the initrd along with it.
  boot.initrd.kernelModules = [ "i915" ];

  # Lets wireshark capture packets without running as root (dumpcap gets
  # CAP_NET_RAW/CAP_NET_ADMIN, restricted to the wireshark group).
  programs.wireshark.enable = true;
  # Deliberately not in "libvirtd": that group is root-equivalent (it can
  # define a VM with the host's own disk attached). virt-manager asks for
  # the password through polkit instead (hyprpolkitagent, home/home.nix).
  users.users.lmichault.extraGroups = [ "wireshark" ];

  # Polkit action checked by the discord-lock watcher (modules/home/
  # laptop-light.nix) so focusing Discord asks for the password through
  # hyprpolkitagent, like virt-manager. auth_self, not auth_self_keep:
  # the user's own password, asked again every time.
  environment.systemPackages = [
    (pkgs.writeTextDir "share/polkit-1/actions/local.discord.open.policy" ''
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE policyconfig PUBLIC "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
       "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
      <policyconfig>
        <action id="local.discord.open">
          <description>Open Discord</description>
          <message>Authentication is required to open Discord</message>
          <defaults>
            <allow_any>no</allow_any>
            <allow_inactive>no</allow_inactive>
            <allow_active>auth_self</allow_active>
          </defaults>
        </action>
      </policyconfig>
    '')
  ];

  # KVM/QEMU virtualization + GUI front-end.
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  # Boot-time USB devices go through the rules in
  # /var/lib/usbguard/rules.conf instead of being trusted blindly (see
  # services.usbguard in modules/nixos/base.nix and README.md).
  services.usbguard.presentDevicePolicy = "apply-policy";

  programs.steam.enable = true;

  system.stateVersion = "24.11";
}
