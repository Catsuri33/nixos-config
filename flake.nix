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
      # NOTE: disko.nixosModules.disko + ./hosts/laptop-gaming/disko.nix are
      # deliberately NOT wired in here yet. This host is live, boots from a
      # plain ext4 root today, and system.autoUpgrade runs `nixos-rebuild
      # switch` weekly (modules/nixos/base.nix) — wiring disko now would make
      # the next auto-upgrade activate a config expecting
      # /dev/mapper/cryptroot, which doesn't exist until the physical LUKS
      # reinstall happens. Add the two lines back (see desktop-gaming below
      # for the pattern) only right before doing that reinstall.
      #
      # Same reasoning for lanzaboote.nixosModules.lanzaboote +
      # ./modules/nixos/secureboot.nix (Secure Boot): needs a manual key
      # enrollment step (sbctl) first — see README.md. Add both lines back
      # once that's done.
      laptop-gaming = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
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
          ])
        ];
      };

    };
  };
}
