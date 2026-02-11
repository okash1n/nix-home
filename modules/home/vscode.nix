{ config, lib, pkgs, ... }:
let
  codeUserDir =
    if pkgs.stdenv.hostPlatform.isDarwin then
      "Library/Application Support/Code/User"
    else
      ".config/Code/User";

  # VSCodeのユーザー設定をリポジトリ内ファイルへ直結し、GUI編集をそのまま取り込む
  vscodeRepoDir = "${config.home.homeDirectory}/nix-home/home/dot_config/vscode";
  extensionsRepoFile = "${vscodeRepoDir}/extensions.txt";

  defaultVSCodeExtensions = [
    "okash1n.hanabi-theme-vscode"
  ];

  defaultExtensionList = lib.concatStringsSep "\n" defaultVSCodeExtensions;
  isDarwin = if pkgs.stdenv.hostPlatform.isDarwin then "1" else "0";
in
{
  home.file."${codeUserDir}/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${vscodeRepoDir}/settings.json";
  home.file."${codeUserDir}/keybindings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${vscodeRepoDir}/keybindings.json";
  home.file."${codeUserDir}/snippets/global.code-snippets".source =
    config.lib.file.mkOutOfStoreSymlink "${vscodeRepoDir}/snippets/global.code-snippets";

  # VS Code 拡張を同期（宣言分を導入し、VSCode側追加分をリポジトリへ取り込む）
  home.activation.setupVSCodeExtensions = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    USERNAME="$(/usr/bin/id -un 2>/dev/null || true)"
    if [ -n "$USERNAME" ]; then
      PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USERNAME/bin:$PATH"
    else
      PATH="/run/current-system/sw/bin:$PATH"
    fi

    if ! command -v code >/dev/null 2>&1; then
      echo "[nix-home] code command was not found; skipping VS Code extension setup."
    elif [ "${isDarwin}" = "1" ] && ! /usr/bin/pgrep -x WindowServer >/dev/null 2>&1; then
      echo "[nix-home] Skipping VS Code extension setup (no GUI session)."
    else
      desired_extensions_file="$(mktemp)"
      installed_extensions_file="$(mktemp)"
      merged_extensions_file="$(mktemp)"
      cleanup_extensions_sync() {
        rm -f "$desired_extensions_file" "$installed_extensions_file" "$merged_extensions_file"
      }
      trap cleanup_extensions_sync EXIT

      mkdir -p "$(dirname "${extensionsRepoFile}")"
      if [ ! -f "${extensionsRepoFile}" ]; then
        cat > "${extensionsRepoFile}" <<'EXTENSIONS'
${defaultExtensionList}
EXTENSIONS
      fi

      # 宣言ファイルを正規化（空行除去・重複除去）
      /usr/bin/awk '{
        sub(/[[:space:]]+$/, "", $0);
        if (length($0) > 0) print $0;
      }' "${extensionsRepoFile}" | sort -fu > "$desired_extensions_file"

      # code の呼び出しに失敗した場合は空扱いにする
      if ! code --list-extensions > "$installed_extensions_file" 2>/dev/null; then
        : > "$installed_extensions_file"
      fi
      sort -fu "$installed_extensions_file" -o "$installed_extensions_file"

      # 宣言済み拡張の不足分をインストール
      while IFS= read -r extension; do
        [ -n "$extension" ] || continue
        if grep -Fxiq "$extension" "$installed_extensions_file"; then
          continue
        fi
        if ! code --install-extension "$extension" --force >/dev/null 2>&1; then
          echo "[nix-home] Failed to install VS Code extension: $extension"
        fi
      done < "$desired_extensions_file"

      # 再取得して、VSCode側で追加された拡張をリポジトリへ取り込む（additive sync）
      if ! code --list-extensions > "$installed_extensions_file" 2>/dev/null; then
        : > "$installed_extensions_file"
      fi
      sort -fu "$installed_extensions_file" -o "$installed_extensions_file"

      cat "$desired_extensions_file" "$installed_extensions_file" \
        | /usr/bin/awk '{
            sub(/[[:space:]]+$/, "", $0);
            if (length($0) > 0) print $0;
          }' \
        | sort -fu > "$merged_extensions_file"

      if ! cmp -s "$merged_extensions_file" "${extensionsRepoFile}"; then
        cp "$merged_extensions_file" "${extensionsRepoFile}"
        echo "[nix-home] Synced VS Code extensions list: ${extensionsRepoFile}"
      fi

      cleanup_extensions_sync
      trap - EXIT
    fi
  '';
}
