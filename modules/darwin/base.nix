{ lib, pkgs, username, ... }:
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
  ghosttyPkg =
    if pkgs ? ghostty-bin then pkgs.ghostty-bin
    else if pkgs ? ghostty then pkgs.ghostty
    else null;
  xdgCliEnv = {
    CLAUDE_CONFIG_DIR = "$HOME/.config/claude";
    CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
    CODEX_HOME = "$HOME/.config/codex";
    GEMINI_CLI_HOME = "$HOME/.config/gemini";
    HAPPY_HOME_DIR = "$HOME/.config/happy";
    VIMINIT = "source $HOME/.config/vim/vimrc";
  };
  xdgCliEnvLaunchd = {
    CLAUDE_CONFIG_DIR = "/Users/${username}/.config/claude";
    CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
    CODEX_HOME = "/Users/${username}/.config/codex";
    GEMINI_CLI_HOME = "/Users/${username}/.config/gemini";
    HAPPY_HOME_DIR = "/Users/${username}/.config/happy";
    VIMINIT = "source /Users/${username}/.config/vim/vimrc";
  };
in
{
  nix.enable = true;
  nix.package = pkgs.nix;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 14d";
  };
  nix.optimise.automatic = true;
  ids.gids.nixbld = 350;
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
      "codex"
      "gemini-cli"
      "vscode"
      "vscode-unwrapped"
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
  environment.systemPackages =
    (lib.optional (ghosttyPkg != null) ghosttyPkg)
    ++ [
      pkgs.vscode
      pkgs.zsh
      pkgs.bash
    ];
  environment.shells = [
    pkgs.zsh
    pkgs.bash
  ];

  # システム全体の環境変数（GUI アプリからも参照可能）
  environment.variables = xdgCliEnv;
  launchd.user.envVariables = xdgCliEnvLaunchd;

  system.defaults.screencapture = {
    "disable-shadow" = true;
  };

  system.stateVersion = 4;
}
