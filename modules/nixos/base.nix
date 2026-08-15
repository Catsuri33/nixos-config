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
    # Loose (not strict) RPF: strict mode drops return traffic under the
    # policy routing that ProtonVPN's killswitch sets up (separate routing
    # table + fwmark rules), which silently killed all connectivity while
    # connected. Loose still blocks packets with no route at all, just not
    # ones that are asymmetric across routing tables.
    "net.ipv4.conf.all.rp_filter" = 2;
    "net.ipv4.conf.default.rp_filter" = 2;
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
  # IPv4 only: ProtonVPN's IPv6 leak-protection blackholes all IPv6 while
  # connected (its own dummy "leak" interface, by design), so an IPv6 DNS
  # server here would silently time out instead of failing over, making
  # resolution randomly hang whenever resolved picked the IPv6 address.
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = "9.9.9.9#dns.quad9.net";
      DNSOverTLS = "yes";
      DNSSEC = "allow-downgrade";
    };
  };

  # DNS-over-TLS keeps a persistent TCP/TLS session open to 9.9.9.9. When
  # ProtonVPN's killswitch rewrites the routing tables on connect/disconnect,
  # that existing session keeps trying to use the now-stale route instead of
  # failing fast, so lookups hang until resolved eventually gives up and
  # reconnects. Force a clean restart right when the tunnel interface
  # appears/disappears so it always opens a fresh connection under the
  # current routing rules.
  #
  # Root cause of the "no DNS at all while connected" bug: proton0 comes up
  # with its own pushed resolver (10.2.0.1) and a "~." routing domain, which
  # makes it a competing resolution scope for every lookup, not just a
  # fallback. Proton's resolver doesn't speak DNS-over-TLS, and DNSOverTLS
  # is set to "yes" (mandatory, no plaintext fallback) above, so any query
  # resolved routes through that scope hangs forever waiting for a TLS
  # handshake the server will never complete. Clearing proton0's own DNS/
  # domain once it's up forces all resolution through the global Quad9 DoT
  # server instead. NetworkManager keeps re-pushing proton0's own
  # DNS/domain config for as long as the connection is active, not just
  # once at startup — confirmed in practice: even a 10-second retry loop
  # still lost eventually. Run a loop that keeps re-clearing for as long
  # as proton0 exists, and launch it via systemd-run rather than a plain
  # backgrounded shell job — nm-dispatcher runs this script inside
  # NetworkManager-dispatcher.service's own cgroup, which stops within
  # ~10-20s of the script returning (confirmed via journalctl), killing
  # any child left in that cgroup. systemd-run detaches the loop into its
  # own transient unit so it survives past that.
  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = pkgs.writeShellScript "protonvpn-resolved-restart" ''
        if [ "$1" = "proton0" ] && { [ "$2" = "up" ] || [ "$2" = "down" ]; }; then
          systemctl restart systemd-resolved.service
        fi
        if [ "$1" = "proton0" ] && [ "$2" = "up" ]; then
          ${pkgs.systemd}/bin/systemd-run --collect --unit=protonvpn-dns-clear ${pkgs.bash}/bin/bash -c '
            while ${pkgs.iproute2}/bin/ip link show proton0 >/dev/null 2>&1; do
              resolvectl dns proton0 ""
              resolvectl domain proton0 ""
              sleep 2
            done
          '
        fi
      '';
    }
  ];

  # Wi-Fi MAC randomization: one random-but-stable MAC per SSID (mirrors
  # Android/GrapheneOS's default), plus always-randomized scan probes.
  # Ethernet is left alone — mostly a home network, randomizing it risks
  # breaking the Jellyfin NAS's DHCP reservation for little privacy gain.
  networking.networkmanager.wifi.macAddress = "stable";
  networking.networkmanager.wifi.scanRandMacAddress = true;

  networking.networkmanager.enable = true;

  # Jellyfin NAS media share, mounted on-demand for all hosts.
  services.rpcbind.enable = true;
  boot.supportedFilesystems = [ "nfs" ];

  fileSystems."/mnt/jellyfin" = {
    device = "192.168.1.152:/tank/jellyfin/media";
    fsType = "nfs";
    options = [ "nfsvers=4" "noatime" "x-systemd.automount" "noauto" "x-systemd.idle-timeout=600" ];
  };

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

  # zsh enabled system-wide so it lands in /etc/shells (required for it to
  # be a valid login shell) — actual dotfile config lives in home-manager
  # (home/home.nix, programs.zsh).
  programs.zsh.enable = true;

  users.users.lmichault = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
    shell = pkgs.zsh;
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
    # Off by default at boot; toggled on manually via the waybar module.
    powerOnBoot = false;
  };
  services.blueman.enable = true;
  # Disable the blueman applet (duplicate tray icon): keep the
  # daemon/blueman-manager, our custom waybar module already shows status.
  environment.etc."xdg/autostart/blueman.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';

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
    openssl
    dnsutils
    unzip

    # Dev tooling
    uv
    nodejs
    pnpm
    opentofu

    # Rust (gcc provides the linker cargo/rustc need at build time)
    cargo
    rustc
    rust-analyzer
    clippy
    rustfmt
    pkg-config
    gcc
  ];

  # Rootless Docker: daemon runs as the user (no root-owned socket/daemon),
  # containers are mapped into the user's subuid/subgid range instead of
  # real root. DOCKER_HOST is exported automatically for normal users.
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

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
