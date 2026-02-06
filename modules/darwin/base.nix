{ lib, pkgs, ... }:
let
  lineSeedJp = pkgs.stdenvNoCC.mkDerivation {
    pname = "line-seed-jp-font";
    version = "20251119";

    src = pkgs.fetchzip {
      url = "https://github.com/line/seed/releases/download/v20251119/seed-v20251119.zip";
      hash = "sha256-h/XOYRz9s6qyS8jv9hqhQQX9IyjanKKWlH6P5qKw5GQ=";
      stripRoot = false;
    };

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/fonts/truetype"
      find "$src" -type f -name "LINESeedJP-*.ttf" -exec install -m644 -t "$out/share/fonts/truetype" {} +
      runHook postInstall
    '';
  };
in
{
  nix.enable = true;
  nix.package = pkgs.nix;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  ids.gids.nixbld = 350;
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
      "codex"
      "gemini-cli"
    ];
  fonts.packages = [
    pkgs.hackgen-nf-font
    lineSeedJp
    (pkgs.ibm-plex.override {
      families = [
        "sans-jp"
        "mono"
      ];
    })
  ];

  system.stateVersion = 4;
}
