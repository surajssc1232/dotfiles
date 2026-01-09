{
  description = "A very basic flake";

  inputs = {

    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    zen-browser.url = "github:0xc000022070/zen-browser-flake";

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs"; # Syncs with your nixpkgs version
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };


  };

  outputs = {  nixpkgs, home-manager, ... }@inputs:
    let
      # Define your system up here
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit inputs system;
        };

        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager

          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;

              # This imports your separate home.nix file
              users.suraj = import ./home.nix; # Replace "yourUsername" with your actual username

              # Optional: Make inputs available in home.nix (e.g., for zen-browser)
              extraSpecialArgs = { inherit inputs; };
            };
          }

        ];
      };
    };
}

