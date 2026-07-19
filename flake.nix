{
  description = "NixOS configuration with Hyprland";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprland.url = "github:hyprwm/Hyprland";

    vicinae.url = "github:vicinaehq/vicinae";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, hyprland, vicinae, disko, lanzaboote, ... }@inputs:
  let
    system = "x86_64-linux";

    mkHome = homeModules: {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.extraSpecialArgs = { inherit inputs; };
      home-manager.users.lmichault = {
        imports = [ ./home/home.nix ] ++ homeModules;
      };
    };
  in {
    nixosConfigurations = {

      # Gaming laptop (Nvidia, Wine, Steam)
      # disko is now wired in ahead of the physical LUKS reinstall (see
      # README.md for the runbook). Until that reinstall actually happens,
      # this host still boots from plain ext4 and `hosts/laptop-gaming/
      # hardware-configuration.nix` still declares the old plaintext
      # fileSystems — building/switching this config before the reinstall
      # will fail on conflicting fileSystems."/" definitions, which is a
      # safe failure (current running system is untouched). Do NOT run
      # `nixos-rebuild switch` (including the weekly system.autoUpgrade)
      # against this host until right after the disko + nixos-install step.
      #
      # lanzaboote.nixosModules.lanzaboote + ./modules/nixos/secureboot.nix
      # (Secure Boot) are still deliberately NOT wired in — needs a manual
      # key enrollment step (sbctl) first, see README.md. Add both lines
      # once that's done.
      laptop-gaming = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          disko.nixosModules.disko
          ./hosts/laptop-gaming/disko.nix
          lanzaboote.nixosModules.lanzaboote
          ./modules/nixos/secureboot.nix
          ./hosts/laptop-gaming/configuration.nix
          home-manager.nixosModules.home-manager
          (mkHome [
            ./modules/home/nvidia.nix
            ./modules/home/gaming.nix
            ./modules/home/laptop.nix
          ])
        ];
      };

      # Gaming desktop (Nvidia, Steam) — add hardware-configuration.nix
      desktop-gaming = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          disko.nixosModules.disko
          ./hosts/desktop-gaming/disko.nix
          lanzaboote.nixosModules.lanzaboote
          ./modules/nixos/secureboot.nix
          ./hosts/desktop-gaming/configuration.nix
          home-manager.nixosModules.home-manager
          (mkHome [
            ./modules/home/nvidia.nix
            ./modules/home/gaming.nix
          ])
        ];
      };

      # Light laptop without GPU (work only)
      laptop-light = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          disko.nixosModules.disko
          ./hosts/laptop-light/disko.nix
          lanzaboote.nixosModules.lanzaboote
          ./modules/nixos/secureboot.nix
          ./hosts/laptop-light/configuration.nix
          home-manager.nixosModules.home-manager
          (mkHome [
            ./modules/home/laptop.nix
            ./modules/home/laptop-light.nix
          ])
        ];
      };

    };
  };
}
