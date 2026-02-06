{
  description = "nix-home";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    darwin.url = "github:LnL7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, darwin, home-manager, ... }:
    let
      lib = nixpkgs.lib;
      system = "aarch64-darwin";
      username = "okash1n";

      removeSuffix = suffix: str:
        if lib.hasSuffix suffix str
        then builtins.substring 0 (builtins.stringLength str - builtins.stringLength suffix) str
        else str;

      hostFiles = lib.filter (name: lib.hasSuffix ".nix" name)
        (builtins.attrNames (builtins.readDir ./hosts/darwin));

      mkDarwin = hostname: darwin.lib.darwinSystem {
        inherit system;
        specialArgs = { inherit username; };
        modules = [
          ./hosts/darwin/${hostname}.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit username; };
            home-manager.users.${username} = import ./home/default.nix;
          }
        ];
      };

      mkHost = file:
        let host = removeSuffix ".nix" file;
        in { name = host; value = mkDarwin host; };
    in
    {
      darwinConfigurations = builtins.listToAttrs (map mkHost hostFiles);
    };
}
