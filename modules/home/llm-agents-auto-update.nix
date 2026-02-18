{ lib, pkgs, ... }:
{
  # llm-agents 自動更新用 launchd agent を登録・再同期する
  home.activation.setupLlmAgentsAutoUpdate = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.bash}/bin/bash ${../../scripts/setup-llm-agents-auto-update.sh}
  '';
}

