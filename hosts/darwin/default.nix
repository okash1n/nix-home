{ pkgs, username, ... }:
{
  imports = [
    ../../modules/darwin/base.nix
  ];

  networking.hostName = "okash1n-C7FP9HQP1F";
  users.users.${username} = {
    home = "/Users/${username}";
    shell = pkgs.zsh;
  };
}
