{
  description = "nix-home";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    darwin.url = "github:LnL7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # AI CLI tools (daily updates)
    llm-agents.url = "github:numtide/llm-agents.nix";
    llm-agents.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, darwin, home-manager, llm-agents, ... }:
    let
      lib = nixpkgs.lib;
      system = "aarch64-darwin";
      defaultUsername = "okash1n";
      username =
        let fromEnv = builtins.getEnv "NIX_HOME_USERNAME";
        in if fromEnv != "" then fromEnv else defaultUsername;

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
            # AI CLI tools overlay (daily updates from numtide/llm-agents.nix)
            nixpkgs.overlays = [ llm-agents.overlays.default ];
            nixpkgs.config.allowUnfree = true;

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-bak";
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
