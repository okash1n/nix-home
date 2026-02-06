{ pkgs, ... }:
{
  nix.enable = true;
  nix.package = pkgs.nix;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = 4;
}
