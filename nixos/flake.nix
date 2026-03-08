{
  description = "A very basic flake";

  inputs = {

    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    # zen-browser.url = "github:0xc000022070/zen-browser-flake";

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs"; # Syncs with your nixpkgs version
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mango = {
      url = "github:DreamMaoMao/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-gaming.url = "github:fufexan/nix-gaming";

  };

  outputs = { nixpkgs, home-manager,... }@inputs:
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

          inputs.mango.nixosModules.mango
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;

              # This imports your separate home.nix file
              users.suraj = import ./home.nix; 

              # Optional: Make inputs available in home.nix (e.g., for zen-browser)
              extraSpecialArgs = { inherit inputs; };
            };
          }

        ];
      };
    };
}

