{ ... }:
{
  imports = [
    ../modules/home/base.nix
    ../modules/home/zsh.nix
    ../modules/home/git.nix
    ../modules/home/ai-agents.nix
    ../modules/home/vim.nix
    ../modules/home/ghostty.nix
    ../modules/home/hanabi-theme.nix
    ../modules/home/gemini-cli.nix
    ../modules/home/sops.nix
  ];
}
