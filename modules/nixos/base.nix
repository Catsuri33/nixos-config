{ config, pkgs, lib, inputs, ... }:
{
  nixpkgs.config.allowUnfree = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

  # Latest mainline kernel on every host, rather than the nixpkgs default
  # LTS series: newest hardware/driver support, and NTSync (needed by the
  # gaming hosts for Windows game compatibility) only lands in mainline.
  # mkDefault so a single host can pin an older series if a kernel
  # regression ever bites, without touching this module.
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  # RAM-backed compressed swap: nothing ever touches the disk in plaintext.
  zramSwap.enable = true;

  # --- Privacy/security hardening (GrapheneOS-inspired) ---

  # hardened_malloc — GrapheneOS's own memory allocator project, packaged
  # natively in NixOS. Gaming hosts override this to the lighter variant
  # (see modules/nixos/gaming.nix) since the full version has a real perf
  # cost.
  environment.memoryAllocator.provider = lib.mkDefault "graphene-hardened";

  security.protectKernelImage = true;
  security.sudo.execWheelOnly = true;
  systemd.coredump.enable = false;

  # Disabling systemd-coredump above only stops it from catching crashes —
  # it doesn't stop crashes from dumping at all. With no coredump handler
  # registered, the kernel falls back to its own default behaviour, which
  # (found in practice via a Spotify crash loop) writes a full raw memory
  # dump named "core.<pid>" into the crashing process's cwd every time,
  # since the systemd user session still sets `ulimit -c unlimited` by
  # default. That's a worse outcome than the journal-managed dumps this
  # setting was meant to avoid: multi-hundred-MB files scattered across
  # whatever directory a shell happened to be in, readable as long as
  # they sit there. Zero out the core size limit so crashes just stop
  # (no dump anywhere), matching the actual intent of coredump.enable =
  # false.
  security.pam.loginLimits = [
    { domain = "*"; type = "hard"; item = "core"; value = "0"; }
  ];

  services.fwupd.enable = true;

  # User-writable EPP for the lock-screen wrapper (home/home.nix) and the
  # laptop battery-saver toggle.
  systemd.tmpfiles.rules = [
    "z /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference 0664 root wheel - -"
  ];

  # AppArmor LSM framework (GrapheneOS-style app confinement). This only
  # turns the framework on — nixpkgs ships few AppArmor profiles by default,
  # so actually confining a given app (browser, Discord, third-party
  # AppImages) still requires adding a profile for it.
  security.apparmor.enable = true;

  # SMART disk health monitoring: catch a failing drive via its pre-failure
  # attributes before it actually dies. No mail server is configured on any
  # host, so notify via `wall` (broadcast to logged-in terminals) instead of
  # email.
  services.smartd = {
    enable = true;
    notifications.wall.enable = true;
  };

  # Weekly TRIM instead of continuous `discard` on the LUKS-backed SSDs:
  # continuous discard leaks some used/free block info on the encrypted
  # volume and costs a bit of perf on every delete, so a batched weekly trim
  # is the standard security/performance compromise.
  services.fstrim.enable = true;

  # USBGuard: block newly-inserted USB devices by default (evil-maid/BadUSB
  # protection on an unattended machine), but auto-allow whatever's already
  # plugged in at boot (built-in keyboard/trackpad/webcam included) so it
  # can't lock out local input on activation.
  #
  # "allow" for boot-time devices is only the safe default for a host whose
  # rules file hasn't been generated yet (an empty policy + "apply-policy"
  # would block a USB keyboard at boot). It also auto-trusts anything an
  # evil maid plugged in while the machine was off, so each host should
  # switch to "apply-policy" once /var/lib/usbguard/rules.conf holds its
  # real devices (`usbguard generate-policy`, see README.md). The rules
  # file stays mutable (no services.usbguard.rules) so `allow-device -p`
  # keeps working.
  services.usbguard = {
    enable = true;
    presentControllerPolicy = "allow";
    presentDevicePolicy = lib.mkDefault "allow";
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
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    # Log packets with impossible source addresses (spoofing hints).
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.default.log_martians" = 1;
    # Only root can load TTY line disciplines (a recurring kernel exploit
    # vector via unprivileged autoload of obscure ldisc modules).
    "dev.tty.ldisc_autoload" = 0;
    "fs.protected_symlinks" = 1;
    "fs.protected_hardlinks" = 1;
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
    # Constant blinding in the BPF JIT for every user, root included
    # (JIT-spraying mitigation).
    "net.core.bpf_jit_harden" = 2;
  };

  # Kernel memory hardening (KSPP recommendations): zero pages on
  # allocation and free (no stale data leaking between allocations, at a
  # few % of CPU), no slab cache merging (keeps heap-overflow exploits
  # within one object type), randomized page allocator and kernel stack
  # offset, no legacy vsyscall page (fixed-address ROP gadgets; only
  # pre-2011 static binaries need it), and no debugfs (large, rarely
  # audited kernel interface).
  boot.kernelParams = [
    "init_on_alloc=1"
    "init_on_free=1"
    "slab_nomerge"
    "page_alloc.shuffle=1"
    "randomize_kstack_offset=on"
    "vsyscall=none"
    "debugfs=off"
  ];

  # Rarely-used network protocols with a history of kernel CVEs; none of
  # them is needed on a desktop, so stop the kernel from autoloading them.
  boot.blacklistedKernelModules = [ "dccp" "sctp" "rds" "tipc" ];

  # /tmp in RAM: wiped on every boot and can't fill up the root fs.
  # Nix builds don't land there: since Nix 2.30 the daemon builds in
  # disk-backed /nix/var/nix/builds by default. (Don't point build-dir at
  # /var/tmp — Nix refuses world-writable build dirs.)
  boot.tmp.useTmpfs = true;

  # Kernel audit trail (auditd), kept small on purpose: no exec logging,
  # which would flood the logs on a desktop. Watches changes to identity
  # and privilege files (sudo use itself is already in the journal via
  # PAM). Read with `ausearch -k <key>` / `aureport`.
  security.auditd.enable = true;
  security.audit = {
    enable = true;
    rules = [
      "-w /etc/passwd -p wa -k identity"
      "-w /etc/group -p wa -k identity"
      "-w /etc/shadow -p wa -k identity"
      "-w /etc/sudoers -p wa -k sudoers"
    ];
  };

  # DNS-over-TLS to Mullvad's "base" resolver (no logging, Swedish
  # jurisdiction, blocks ads/trackers/malware — the same role Quad9 used to
  # fill here, Quad9 being on its way out in France). Unfiltered variant:
  # 194.242.2.2#dns.mullvad.net. IPv4 only: ProtonVPN's IPv6
  # leak-protection blackholes all IPv6 while connected (its own dummy
  # "leak" interface, by design), so an IPv6 DNS server here would silently
  # time out instead of failing over, making resolution randomly hang
  # whenever resolved picked the IPv6 address.
  #
  # DNSOverTLS is "opportunistic", not "yes": networks like university
  # eduroam/wired campus links firewall off port 853 entirely, and a strict
  # requirement leaves no plaintext fallback, so DNS fails completely on
  # those networks. Opportunistic still encrypts whenever the server
  # supports it and only drops to plaintext (still to Mullvad) when TLS is
  # unreachable.
  #
  # Domains = "~." makes this global server the route for every lookup.
  # Without it, the resolver each network pushes over DHCP (a per-link
  # DefaultRoute scope) gets every query too, in plaintext, alongside the
  # DoT one. FallbackDNS replaces systemd's built-in Google/Cloudflare
  # list. LLMNR/mDNS off: both answer and trust unauthenticated multicast
  # replies, the classic spoofing vector on hostile LANs (Responder).
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = "194.242.2.4#base.dns.mullvad.net";
      FallbackDNS = "194.242.2.2#dns.mullvad.net";
      Domains = "~.";
      DNSOverTLS = "opportunistic";
      DNSSEC = "allow-downgrade";
      LLMNR = "false";
      MulticastDNS = "false";
    };
  };

  # DNS-over-TLS keeps a persistent TCP/TLS session open to Mullvad. When
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
  # fallback. Proton's resolver doesn't speak DNS-over-TLS, so even with
  # DNSOverTLS opportunistic above, queries routed through that scope would
  # silently fall back to plaintext DNS against Proton's own resolver
  # instead of Mullvad — leaking every lookup to Proton rather than just
  # dropping encryption on an unsupported server. Clearing proton0's own
  # DNS/domain once it's up forces all resolution through the global Mullvad
  # DoT server instead. NetworkManager keeps re-pushing proton0's own
  # DNS/domain config for as long as the connection is active, not just
  # once at startup — confirmed in practice: even a 10-second retry loop
  # still lost eventually. Run a loop that keeps re-clearing for as long
  # as proton0 exists, and launch it via systemd-run rather than a plain
  # backgrounded shell job — nm-dispatcher runs this script inside
  # NetworkManager-dispatcher.service's own cgroup, which stops within
  # ~10-20s of the script returning (confirmed via journalctl), killing
  # any child left in that cgroup. systemd-run detaches the loop into its
  # own transient unit so it survives past that. Absolute paths throughout:
  # that transient unit's PATH has no coreutils, so a bare `sleep` failed
  # ("command not found") and the loop spun without pause, hammering
  # resolved over D-Bus.
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
              ${pkgs.systemd}/bin/resolvectl dns proton0 ""
              ${pkgs.systemd}/bin/resolvectl domain proton0 ""
              ${pkgs.coreutils}/bin/sleep 2
            done
          '
        fi
      '';
    }
  ];

  # Same stale-DoT problem after suspend, but the restart above never fires:
  # NetworkManager keeps proton0/wg1/Wi-Fi "activated" across the sleep, so
  # no up/down events. Meanwhile resolved probes Mullvad on wake before
  # Wi-Fi has reassociated, degrades TLS -> UDP -> TCP, and DNS stays dead
  # until a VPN reconnect restarts it (confirmed in the journal: the tunnel
  # itself came back fine). Restart resolved once the link is back, retrying
  # until a lookup goes through.
  systemd.services.resolved-resume-restart = {
    description = "Restart systemd-resolved after resume";
    after = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" "suspend-then-hibernate.target" ];
    wantedBy = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" "suspend-then-hibernate.target" ];
    path = [ pkgs.systemd pkgs.coreutils ];
    script = ''
      for _ in $(seq 12); do
        sleep 5
        systemctl restart systemd-resolved.service
        sleep 1
        if timeout 10 resolvectl query --cache=no nixos.org >/dev/null 2>&1; then
          exit 0
        fi
      done
      exit 1
    '';
  };

  # Wi-Fi MAC randomization: one random-but-stable MAC per SSID (mirrors
  # Android/GrapheneOS's default), plus always-randomized scan probes.
  # Ethernet is left alone — mostly a home network, randomizing it risks
  # breaking the Jellyfin NAS's DHCP reservation for little privacy gain.
  networking.networkmanager.wifi.macAddress = "stable";
  networking.networkmanager.wifi.scanRandMacAddress = true;

  networking.networkmanager.enable = true;

  # Jellyfin NAS media share, mounted on-demand for all hosts.
  # NFSv4 needs no portmapper on the client (rpcbind/statd are NFSv3
  # only), but the nfs filesystem module turns rpcbind on regardless,
  # leaving port 111 listening on every interface.
  services.rpcbind.enable = lib.mkForce false;
  boot.supportedFilesystems = [ "nfs" ];

  # nosuid/nodev/noexec: the share is unauthenticated (AUTH_SYS) and
  # 192.168.1.0/24 is a very common subnet, so on someone else's network a
  # host sitting at .152 could serve a setuid-root binary or a device node.
  # A media library never needs any of them.
  fileSystems."/mnt/jellyfin" = {
    device = "192.168.1.152:/tank/jellyfin/media";
    fsType = "nfs";
    options = [ "nfsvers=4" "noatime" "nosuid" "nodev" "noexec" "x-systemd.automount" "noauto" "x-systemd.idle-timeout=600" ];
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
    # Full name: shown on the lock screen (hyprlock $DESC).
    description = "Louis Michault";
    # input/uinput: Vicinae's input server (see below). Accepted risk: every
    # process of this user, and Flatpak apps with devices=all, can read all
    # keyboards and inject keystrokes.
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" "uinput" ];
    shell = pkgs.zsh;
    # No initial password on purpose: this repo is public, so any password
    # set here is known to everyone until changed. Set it during install
    # instead (`nixos-enter --root /mnt -c 'passwd lmichault'`, see
    # README.md). Existing hosts keep their current password
    # (users.mutableUsers).
  };

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  programs.uwsm.enable = true;

  # Vicinae's input server reads /dev/input and writes /dev/uinput (pasting
  # from clipboard/emoji, snippet expansion). Granted through the input and
  # uinput groups (users.users.lmichault above) rather than a
  # cap_dac_override wrapper, which bypassed every file permission check on
  # the system for any user that ran it.
  hardware.uinput.enable = true;

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
    wireplumber = {
      enable = true;
      # Keep Bluetooth headsets on the high-quality A2DP profile even
      # while an app (e.g. Discord) opens a mic stream. Without this,
      # WirePlumber auto-switches to the low-quality mono HSP/HFP
      # profile whenever a microphone is requested, degrading music
      # playback too. Only sensible because we use a non-Bluetooth mic
      # (the headset's own mic won't work while forced onto A2DP).
      extraConfig."51-bluetooth-no-autoswitch" = {
        "wireplumber.settings" = {
          "bluetooth.autoswitch-to-headset-profile" = false;
        };
      };
    };
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
    # SF Pro stand-in for the macOS look (home/theme.nix).
    inter
    noto-fonts
    noto-fonts-color-emoji
  ];
  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Inter" "Noto Sans" ];
    monospace = [ "JetBrainsMono Nerd Font" ];
  };

  environment.systemPackages = with pkgs; [
    git
    wget
    curl
    grpcurl
    wireguard-tools
    openssl
    dnsutils
    unzip

    # System-wide xterm-kitty terminfo so root shells (sudo -i, su) can run
    # ncurses apps like nano/htop from kitty; per-user ~/.terminfo isn't seen.
    kitty.terminfo

    # Security auditing (run as root: `sudo lynis audit system`)
    lynis
    # Known CVEs in the system closure: `vulnix --system`
    vulnix

    # Dev tooling
    uv
    nodejs
    pnpm
    opentofu
    buildah

    # Rust (gcc provides the linker cargo/rustc need at build time)
    cargo
    rustc
    rust-analyzer
    clippy
    rustfmt
    pkg-config
    gcc
  ];

  # std sources for rust-analyzer, not shipped with nixpkgs rustc.
  environment.variables.RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";

  # Dev tools (pnpm, etc.) sometimes self-download a dynamically-linked
  # standalone build instead of using the nixpkgs-packaged version - e.g.
  # pnpm's own devEngines.packageManager version check with onFail:
  # "download" fetches a compiled binary when the local pnpm version
  # doesn't match a project's pin. NixOS has no generic-Linux dynamic
  # linker path by default, so those binaries fail to start. nix-ld
  # provides that compatibility shim.
  programs.nix-ld.enable = true;

  # Rootless Docker: daemon runs as the user (no root-owned socket/daemon),
  # containers are mapped into the user's subuid/subgid range instead of
  # real root. DOCKER_HOST is exported automatically for normal users.
  # Flatpak, used to sandbox the proprietary/Electron apps (Discord,
  # Spotify, Mattermost, Zoom — installed per user from home-manager, see
  # flatpakApps in home/home.nix). AppArmor above ships no profiles for
  # them, so the bubblewrap sandbox (own filesystem view, portals for file
  # access) is what actually confines them. Their runtime has its own /etc,
  # so the host's hardened_malloc preload doesn't reach them either, which
  # replaces the per-app "unhardened" wrappers they used to need.
  services.flatpak.enable = true;

  # Rootless containers can't reach resolved's 127.0.0.53 stub (rootlesskit
  # runs with --disable-host-loopback), so Docker falls back to the upstream
  # servers in /run/systemd/resolve/resolv.conf, i.e. Mullvad, and queries
  # them in plain DNS on port 53, which Mullvad refuses (it only serves
  # DoT/DoH): every lookup in a container or a build fails with REFUSED.
  # Instead, resolved also listens on an address outside 127.0.0.0/8, which
  # slirp4netns does let containers reach, so their lookups go through the
  # same Mullvad DoT path as the host's. 192.0.2.0/24 is TEST-NET-1, never
  # routed, so it can't collide with a real network. It sits on lo, which
  # NetworkManager leaves alone and the firewall trusts. Added by a unit of
  # its own: networking.interfaces.lo generates network-addresses-lo, but
  # with NetworkManager nothing pulls that unit in, so it never runs.
  systemd.services.resolved-container-address = {
    description = "Address for rootless containers to reach resolved";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.iproute2}/bin/ip addr replace 192.0.2.53/32 dev lo";
      ExecStop = "${pkgs.iproute2}/bin/ip addr del 192.0.2.53/32 dev lo";
    };
  };
  services.resolved.settings.Resolve.DNSStubListenerExtra = "192.0.2.53";

  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
    daemon.settings.dns = [ "192.0.2.53" ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Rebuilds the config that is already deployed (inputs.self, the flake's
  # own immutable, root-owned copy in the store) with the latest
  # nixos-unstable; every other input stays at its flake.lock revision.
  # Config changes are only ever applied by a manual `nixos-rebuild
  # switch`. Not ~/nixos-config: root refuses to open a git repo owned by
  # another user, and building as root from a user-writable directory
  # would let anything running as lmichault get root at the next upgrade.
  # Not the GitHub repo either: that would make a push to it (stolen
  # token, compromised account) root on every host within a week.
  system.autoUpgrade = {
    enable = true;
    flake = "path:${inputs.self}";
    flags = [ "--override-input" "nixpkgs" "github:NixOS/nixpkgs/nixos-unstable" ];
    dates = "weekly";
    allowReboot = false;
  };

  # The timer is Persistent, so a missed run fires right at boot — often on
  # a network that blocks DNS to Mullvad until ProtonVPN is up, which made
  # the fetch fail within two minutes. Wait (up to 15 min) for a working
  # lookup before starting.
  systemd.services.nixos-upgrade.preStart = ''
    for _ in $(${pkgs.coreutils}/bin/seq 90); do
      if ${pkgs.coreutils}/bin/timeout 10 ${pkgs.systemd}/bin/resolvectl query --cache=no channels.nixos.org >/dev/null 2>&1; then
        exit 0
      fi
      ${pkgs.coreutils}/bin/sleep 10
    done
    echo "no working DNS after 15 min" >&2
    exit 1
  '';

  # A failed upgrade used to go unnoticed for weeks: tell the logged-in
  # user (desktop notification) and every terminal (wall).
  systemd.services.nixos-upgrade.unitConfig.OnFailure = [ "nixos-upgrade-notify.service" ];
  systemd.services.nixos-upgrade-notify = {
    description = "Notify about a failed NixOS upgrade";
    serviceConfig.Type = "oneshot";
    script = ''
      msg="Automatic NixOS upgrade failed: journalctl -u nixos-upgrade"
      ${pkgs.util-linux}/bin/wall "$msg" || true
      ${pkgs.systemd}/bin/systemd-run --machine=lmichault@.host --user --collect --quiet \
        ${pkgs.libnotify}/bin/notify-send -u critical "NixOS" "$msg" || true
    '';
  };

  # Progress of a running upgrade as one low-urgency notification (dunst
  # sorts it below the others), updated in place through its stack tag.
  # Nix has no progress bar without a terminal, so count its log instead:
  # "these N paths will be fetched" / "derivations will be built" give the
  # total, each "copying path" / "building" line one more done. It counts
  # paths, not bytes, and the total grows once (nixos-rebuild is built
  # first, then the system).
  systemd.services.nixos-upgrade-progress = {
    description = "Show NixOS upgrade progress";
    wantedBy = [ "nixos-upgrade.service" ];
    path = [ pkgs.systemd pkgs.gawk pkgs.coreutils ];
    script = ''
      unit=nixos-upgrade.service
      shown=""
      notify() {
        local body=$1 value=$2 timeout=''${3:-0}
        [ "$body|$value" = "$shown" ] && return 0
        shown="$body|$value"
        args=(-u low -t "$timeout" -h string:x-dunst-stack-tag:nixos-upgrade)
        [ -n "$value" ] && args+=(-h "int:value:$value")
        systemd-run --machine=lmichault@.host --user --collect --quiet \
          ${pkgs.libnotify}/bin/notify-send "''${args[@]}" "NixOS upgrade" "$body" || true
      }

      started=0
      for tries in $(seq 1000000); do
        if [ "$(systemctl show -P ActiveState $unit)" != activating ]; then
          # Both jobs start together: give the upgrade a moment to begin.
          [ "$started" = 1 ] || [ "$tries" -gt 10 ] && break
          sleep 1
          continue
        fi
        started=1
        if [ "$(systemctl show -P SubState $unit)" = start-pre ]; then
          notify "Waiting for network…"
        else
          id=$(systemctl show -P InvocationID $unit)
          read -r total count switching < <(journalctl -q -o cat _SYSTEMD_INVOCATION_ID="$id" | awk '
            /^ *these [0-9]+ (paths will be fetched|derivations will be built)/ { t += $2 }
            /^ *this (path will be fetched|derivation will be built)/ { t += 1 }
            /^copying path / || /^building .\/nix\// { d++ }
            /^switching to system configuration/ { s = 1 }
            END { print t + 0, d + 0, s + 0 }')
          if [ "$switching" = 1 ]; then
            notify "Activating the new configuration…" 100
          elif [ "$total" -gt 0 ]; then
            pct=$(( count * 100 / total ))
            [ "$pct" -gt 99 ] && pct=99
            notify "$count / $total paths" "$pct"
          else
            notify "Checking for updates…"
          fi
        fi
        sleep 3
      done

      [ "$started" = 1 ] || exit 0
      # On failure nixos-upgrade-notify raises the critical alert: just
      # clear this one.
      if [ "$(systemctl show -P Result $unit)" = success ]; then
        notify "Done" "" 5000
      else
        notify "Failed" "" 1
      fi
    '';
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
