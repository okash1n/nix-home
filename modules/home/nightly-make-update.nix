{ lib, pkgs, ... }:
{
  # `make update` 相当の夜間ジョブ（launchd）を登録・再同期する。
  home.activation.setupNightlyMakeUpdate = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash ${../../scripts/setup-nightly-make-update.sh}
  '';
}

