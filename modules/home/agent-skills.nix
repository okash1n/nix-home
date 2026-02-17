{ lib, ... }:
{
  # 個人用 skill を各エージェントの skills ディレクトリへ同期する
  home.activation.setupAgentSkills = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    AGENT_SKILLS_ROOT="''${NIX_HOME_AGENT_SKILLS_DIR:-$HOME/nix-home/agent-skills}"
    CLAUDE_SKILLS_ROOT="''${CLAUDE_SKILLS_DIR:-''${CLAUDE_CONFIG_DIR:-$HOME/.config/claude}/skills}"
    CODEX_SKILLS_ROOT="''${CODEX_SKILLS_DIR:-''${CODEX_HOME:-$HOME/.config/codex}/skills}"
    GEMINI_SKILLS_ROOT="''${GEMINI_SKILLS_DIR:-''${GEMINI_CLI_HOME:-$HOME/.config/gemini}/.gemini/skills}"

    link_skill() {
      src="$1"
      dst="$2"

      if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        echo "[nix-home] Skip existing non-symlink path: $dst"
        return
      fi

      if [ -L "$dst" ]; then
        current_target="$(readlink "$dst" || true)"
        if [ "$current_target" != "$src" ]; then
          case "$current_target" in
            "$AGENT_SKILLS_ROOT"/*) ;;
            *)
              echo "[nix-home] Skip existing external symlink: $dst -> $current_target"
              return
              ;;
          esac
        fi
      fi

      ln -sfn "$src" "$dst"
    }

    cleanup_stale_links() {
      skills_root="$1"

      for link_path in "$skills_root"/*; do
        [ -L "$link_path" ] || continue
        link_target="$(readlink "$link_path" || true)"
        case "$link_target" in
          "$AGENT_SKILLS_ROOT"/*)
            skill_name="$(basename "$link_path")"
            if ! grep -Fxq "$skill_name" "$managed_skills_file"; then
              rm -f "$link_path"
              echo "[nix-home] Removed stale agent skill link: $link_path"
            fi
            ;;
        esac
      done
    }

    mkdir -p "$AGENT_SKILLS_ROOT"
    mkdir -p "$CLAUDE_SKILLS_ROOT" "$CODEX_SKILLS_ROOT" "$GEMINI_SKILLS_ROOT"
    AGENT_SKILLS_ROOT="$(cd "$AGENT_SKILLS_ROOT" && pwd)"

    managed_skills_file="$(mktemp)"
    cleanup_managed_skills_file() {
      rm -f "$managed_skills_file"
    }
    trap cleanup_managed_skills_file EXIT

    for skill_path in "$AGENT_SKILLS_ROOT"/*; do
      [ -d "$skill_path" ] || continue
      skill_name="$(basename "$skill_path")"
      case "$skill_name" in
        .*) continue ;;
      esac

      if [ ! -f "$skill_path/SKILL.md" ]; then
        echo "[nix-home] Skip invalid skill (SKILL.md missing): $skill_name"
        continue
      fi

      printf '%s\n' "$skill_name" >> "$managed_skills_file"

      link_skill "$skill_path" "$CLAUDE_SKILLS_ROOT/$skill_name"
      link_skill "$skill_path" "$CODEX_SKILLS_ROOT/$skill_name"
      link_skill "$skill_path" "$GEMINI_SKILLS_ROOT/$skill_name"
    done

    cleanup_stale_links "$CLAUDE_SKILLS_ROOT"
    cleanup_stale_links "$CODEX_SKILLS_ROOT"
    cleanup_stale_links "$GEMINI_SKILLS_ROOT"

    cleanup_managed_skills_file
    trap - EXIT
  '';
}
