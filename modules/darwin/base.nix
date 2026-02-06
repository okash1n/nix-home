{ pkgs, ... }:
{
  nix.enable = true;
  nix.package = pkgs.nix;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  ids.gids.nixbld = 350;

  system.stateVersion = 4;
}
