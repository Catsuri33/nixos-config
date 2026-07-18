{ config, pkgs, lib, inputs, ... }:
{
  nixpkgs.config.allowUnfree = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

  # RAM-backed compressed swap: nothing ever touches the disk in plaintext.
  zramSwap.enable = true;

  # systemd initrd — required for systemd-cryptenroll (TPM2 unlock) once LUKS
  # is in place. Safe on its own for non-encrypted hosts too.
  boot.initrd.systemd.enable = true;

  # --- Privacy/security hardening (GrapheneOS-inspired) ---

  # hardened_malloc — GrapheneOS's own memory allocator project, packaged
  # natively in NixOS. Gaming hosts override this to the lighter variant
  # (see modules/nixos/gaming.nix) since the full version has a real perf
  # cost.
  environment.memoryAllocator.provider = lib.mkDefault "graphene-hardened";

  security.protectKernelImage = true;
  security.sudo.execWheelOnly = true;
  systemd.coredump.enable = false;
  services.fwupd.enable = true;

  # USBGuard: block newly-inserted USB devices by default (evil-maid/BadUSB
  # protection on an unattended machine), but auto-allow whatever's already
  # plugged in at boot (built-in keyboard/trackpad/webcam included) so it
  # can't lock out local input on activation.
  services.usbguard = {
    enable = true;
    presentControllerPolicy = "allow";
    presentDevicePolicy = "allow";
  };

  boot.kernel.sysctl = {
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.unprivileged_bpf_disabled" = 1;
    # Admin-only ptrace: attaching a debugger (gdb, strace) to another
    # user's process now requires sudo.
    "kernel.yama.ptrace_scope" = 2;
    "kernel.kexec_load_disabled" = 1;
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "fs.protected_symlinks" = 1;
    "fs.protected_hardlinks" = 1;
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
  };

  # DNS-over-TLS (Quad9: privacy-respecting, filters known-malicious domains).
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = "9.9.9.9#dns.quad9.net 2620:fe::fe#dns.quad9.net";
      DNSOverTLS = "yes";
    };
  };

  # Wi-Fi MAC randomization: one random-but-stable MAC per SSID (mirrors
  # Android/GrapheneOS's default), plus always-randomized scan probes.
  # Ethernet is left alone — mostly a home network, randomizing it risks
  # breaking the Jellyfin NAS's DHCP reservation for little privacy gain.
  networking.networkmanager.wifi.macAddress = "stable";
  networking.networkmanager.wifi.scanRandMacAddress = true;

  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "fr_FR.UTF-8";
  i18n.supportedLocales = [ "fr_FR.UTF-8/UTF-8" "en_US.UTF-8/UTF-8" ];
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "fr_FR.UTF-8";
    LC_MONETARY = "fr_FR.UTF-8";
    LC_PAPER = "fr_FR.UTF-8";
    LC_TIME = "fr_FR.UTF-8";
  };

  console.keyMap = "fr";

  users.users.lmichault = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
    shell = pkgs.bash;
    initialPassword = "tobechanged";
  };

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  programs.uwsm.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd 'uwsm start hyprland-uwsm.desktop'";
        user = "greeter";
      };
    };
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # XDG portals (screen sharing, file picker, etc.)
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal-gtk ];
    configPackages = [ pkgs.hyprland ];
  };

  security.polkit.enable = true;

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
  ];

  environment.systemPackages = with pkgs; [
    git
    wget
    curl
    wireguard-tools
  ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  system.autoUpgrade = {
    enable = true;
    flake = "/home/lmichault/nixos-config";
    flags = [ "--update-input" "nixpkgs" ];
    dates = "weekly";
    allowReboot = false;
  };

  nix.settings = {
    auto-optimise-store = true;
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [ "https://cache.nixos.org" ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };
}
