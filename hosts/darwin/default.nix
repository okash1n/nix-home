{ pkgs, username, ... }:
{
  imports = [
    ../../modules/darwin/base.nix
  ];

  networking.hostName = "default";
  users.users.${username} = {
    home = "/Users/${username}";
    shell = pkgs.zsh;
  };
}
