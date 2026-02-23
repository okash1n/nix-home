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
    # Secret management
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, darwin, home-manager, llm-agents, sops-nix, ... }:
    let
      lib = nixpkgs.lib;
      system = "aarch64-darwin";
      defaultUsername = "okash1n";
      unfreeNames = [
        "claude-code"
        "codex"
        "gemini-cli"
        "vscode"
        "vscode-unwrapped"
      ];
      # builtins.getEnv は --impure フラグが必須（pure evaluation では常に空文字列）
      # 使用例: NIX_HOME_USERNAME=other make switch
      username =
        let fromEnv = builtins.getEnv "NIX_HOME_USERNAME";
        in if fromEnv != "" then fromEnv else defaultUsername;

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

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-bak";
            home-manager.extraSpecialArgs = { inherit username; };
            home-manager.sharedModules = [ sops-nix.homeManagerModules.sops ];
            home-manager.users.${username} = import ./home/default.nix;
          }
        ];
      };

      mkHost = file:
        let host = lib.removeSuffix ".nix" file;
        in { name = host; value = mkDarwin host; };

      mkHomePkgs = targetSystem: import nixpkgs {
        system = targetSystem;
        overlays = [ llm-agents.overlays.default ];
        config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) unfreeNames;
      };

      mkHome = user: home-manager.lib.homeManagerConfiguration {
        pkgs = mkHomePkgs system;
        extraSpecialArgs = { username = user; };
        modules = [
          sops-nix.homeManagerModules.sops
          ./home/default.nix
        ];
      };

      mkHomeEntry = user: {
        name = user;
        value = mkHome user;
      };

      homeConfigUsers = lib.unique [
        defaultUsername
        username
      ];
    in
    {
      darwinConfigurations = builtins.listToAttrs (map mkHost hostFiles);
      homeConfigurations = builtins.listToAttrs (map mkHomeEntry homeConfigUsers);
    };
}
