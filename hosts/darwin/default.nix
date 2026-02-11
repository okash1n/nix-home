{ pkgs, username, ... }:
{
  imports = [
    ../../modules/darwin/base.nix
  ];

  system.primaryUser = username;

  users.users.${username} = {
    home = "/Users/${username}";
    shell = pkgs.zsh;
  };
}
