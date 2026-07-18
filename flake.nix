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
  };

  outputs = { self, nixpkgs, home-manager, hyprland, vicinae, ... }@inputs:
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
