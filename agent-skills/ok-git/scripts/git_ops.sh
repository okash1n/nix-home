#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  git_ops.sh inspect
  git_ops.sh start-branch --name <branch> [--base <branch>]
  git_ops.sh commit (--all | --paths <path1,path2>) --message <message> [--allow-empty]
  git_ops.sh sync [--remote <remote>] [--branch <branch>] [--push]

Examples:
  scripts/git_ops.sh inspect
  scripts/git_ops.sh start-branch --name feat/add-skill --base main
  scripts/git_ops.sh commit --all --message "Git運用スキルを追加"
  scripts/git_ops.sh commit --paths "agent-skills/ok-git/SKILL.md" --message "スキル定義を更新"
  scripts/git_ops.sh sync --push
EOF
}

require_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "[ERROR] Not inside a git repository" >&2
    exit 1
  fi
}

current_branch() {
  git symbolic-ref --quiet --short HEAD 2>/dev/null || true
}

check_message() {
  local message="$1"
  if [[ "$message" == *"Co-Authored-By:"* || "$message" == *"Co-authored-by:"* ]]; then
    echo "[ERROR] Commit message must not include Co-Authored-By trailer" >&2
    exit 1
  fi
}

global_identity() {
  local name email
  name="$(git config --global --get user.name || true)"
  email="$(git config --global --get user.email || true)"

  if [[ -z "$name" || -z "$email" ]]; then
    echo "[ERROR] git global user.name / user.email is not set" >&2
    exit 1
  fi

  printf '%s\n%s\n' "$name" "$email"
}

cmd_inspect() {
  require_repo

  local branch repo_root
  branch="$(current_branch)"
  repo_root="$(git rev-parse --show-toplevel)"

  echo "[repo] $repo_root"
  if [[ -n "$branch" ]]; then
    echo "[branch] $branch"
  else
    echo "[branch] detached HEAD"
  fi

  echo
  echo "[status]"
  git status -sb

  echo
  echo "[remotes]"
  git remote -v || true

  echo
  echo "[identity] global"
  echo "  user.name=$(git config --global --get user.name || echo '<unset>')"
  echo "  user.email=$(git config --global --get user.email || echo '<unset>')"

  echo "[identity] effective"
  echo "  user.name=$(git config --get user.name || echo '<unset>')"
  echo "  user.email=$(git config --get user.email || echo '<unset>')"
}

cmd_start_branch() {
  require_repo

  local name="" base=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)
        name="${2:-}"
        shift 2
        ;;
      --base)
        base="${2:-}"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "[ERROR] Unknown argument for start-branch: $1" >&2
        exit 1
        ;;
    esac
  done

  if [[ -z "$name" ]]; then
    echo "[ERROR] --name is required" >&2
    exit 1
  fi

  if git show-ref --verify --quiet "refs/heads/$name"; then
    echo "[ERROR] Branch already exists: $name" >&2
    exit 1
  fi

  if [[ -n "$base" ]]; then
    if git show-ref --verify --quiet "refs/heads/$base"; then
      git switch "$base"
    elif git show-ref --verify --quiet "refs/remotes/origin/$base"; then
      git switch -c "$base" "origin/$base"
    else
      echo "[ERROR] Base branch not found: $base" >&2
      exit 1
    fi
  fi

  git switch -c "$name"
  echo "[ok] created and switched: $name"
}

cmd_commit() {
  require_repo

  local mode="" paths="" message="" allow_empty=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --all)
        mode="all"
        shift
        ;;
      --paths)
        mode="paths"
        paths="${2:-}"
        shift 2
        ;;
      --message)
        message="${2:-}"
        shift 2
        ;;
      --allow-empty)
        allow_empty=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "[ERROR] Unknown argument for commit: $1" >&2
        exit 1
        ;;
    esac
  done

  if [[ -z "$mode" ]]; then
    echo "[ERROR] One of --all or --paths is required" >&2
    exit 1
  fi
  if [[ -z "$message" ]]; then
    echo "[ERROR] --message is required" >&2
    exit 1
  fi
  check_message "$message"

  if [[ "$mode" == "all" ]]; then
    git add -A
  else
    IFS=',' read -r -a split_paths <<< "$paths"
    if [[ ${#split_paths[@]} -eq 0 ]]; then
      echo "[ERROR] --paths has no values" >&2
      exit 1
    fi
    for raw in "${split_paths[@]}"; do
      p="$(echo "$raw" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
      [[ -n "$p" ]] || continue
      git add -- "$p"
    done
  fi

  if git diff --cached --quiet && [[ "$allow_empty" -eq 0 ]]; then
    echo "[ERROR] No staged changes. Use --allow-empty to force commit." >&2
    exit 1
  fi

  local identity name email
  identity="$(global_identity)"
  name="$(echo "$identity" | sed -n '1p')"
  email="$(echo "$identity" | sed -n '2p')"

  if [[ "$allow_empty" -eq 1 ]]; then
    git -c "user.name=$name" -c "user.email=$email" commit --allow-empty -m "$message"
  else
    git -c "user.name=$name" -c "user.email=$email" commit -m "$message"
  fi

  echo "[ok] committed with global identity: $name <$email>"
}

cmd_sync() {
  require_repo

  local remote="origin" branch="" push=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --remote)
        remote="${2:-}"
        shift 2
        ;;
      --branch)
        branch="${2:-}"
        shift 2
        ;;
      --push)
        push=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "[ERROR] Unknown argument for sync: $1" >&2
        exit 1
        ;;
    esac
  done

  if [[ -z "$branch" ]]; then
    branch="$(current_branch)"
  fi
  if [[ -z "$branch" ]]; then
    echo "[ERROR] Detached HEAD. Set --branch explicitly." >&2
    exit 1
  fi

  git fetch --prune "$remote"
  git pull --rebase "$remote" "$branch"

  if [[ "$push" -eq 1 ]]; then
    git push "$remote" "$branch"
    echo "[ok] synchronized and pushed: $remote/$branch"
  else
    echo "[ok] synchronized: $remote/$branch (push skipped)"
  fi
}

main() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 1
  fi

  sub="$1"
  shift

  case "$sub" in
    inspect)
      cmd_inspect "$@"
      ;;
    start-branch)
      cmd_start_branch "$@"
      ;;
    commit)
      cmd_commit "$@"
      ;;
    sync)
      cmd_sync "$@"
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "[ERROR] Unknown subcommand: $sub" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
