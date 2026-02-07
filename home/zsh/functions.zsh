# fdでカレントディレクトリ以下のディレクトリを探してcdする
fcd() {
  local dir
  dir=$(fd --type d --hidden --exclude .git | fzf +m)
  cd "$dir"
}

# ghqのリポジトリリストからfzfしてcdする (find github)
fgh() {
  declare -r REPO_NAME="$(ghq list >/dev/null | fzf-tmux --reverse +m)"
  [[ -n "${REPO_NAME}" ]] && cd "$(ghq root)/${REPO_NAME}"
}

# GitHubのリモートの内容を現在のローカルで書き換え、initial commit 一つだけにする (git reset force)
grf() {
  # .gitディレクトリが存在するか確認
  if [ ! -d ".git" ]; then
    echo "Error: This command must be run from the project root (where .git directory is located)."
    return 1
  fi

  # 確認プロンプト
  echo "Warning: This command will delete all remote and local commits, replacing them with a single commit of the current local state."
  echo -n "Are you sure you want to proceed? (y/n): "
  read confirmation

  # y の場合のみ実行
  if [ "$confirmation" = "y" ]; then
    # 初期化の処理
    git checkout --orphan tmp
    git add .
    git commit -m "initial commit"
    git checkout -B main
    git push -f origin main
    git branch -d tmp
  else
    # y 以外が入力された場合
    echo "Operation aborted."
    return 1
  fi
}

# ローカルのmainブランチをリモートの最新状態に強制的に同期する (git pull force)
gpf() {
  # 確認プロンプト
  echo "Warning: This command will delete all local changes and reset the 'main' branch to match 'origin/main'."
  echo -n "Are you sure you want to proceed? (y/n): "
  read confirmation

  # y の場合のみ実行
  if [ "$confirmation" != "y" ]; then
    echo "Operation aborted."
    return 1
  fi

  # 現在のブランチがmainでない場合のみチェックアウト
  if [ "$(git rev-parse --abbrev-ref HEAD)" != "main" ]; then
    git checkout main
  fi

  # もしコンフリクトしていたら、mergeの処理を中止
  if git merge HEAD &>/dev/null; then
    echo "No ongoing merge process."
  else
    echo "Aborting merge process..."
    git merge --abort
  fi

  # リモートの最新状態を取得
  git fetch origin main

  # リセットしてリモートの状態に同期
  git reset --hard origin/main

  echo "Local main branch has been reset to match origin/main."
}

# GitHub Copilot Alias
## gh copilot suggest
ghcs() {
	FUNCNAME="$funcstack[1]"
	TARGET="shell"
	local GH_DEBUG="$GH_DEBUG"
	local GH_HOST="$GH_HOST"

	read -r -d '' __USAGE <<-EOF
	Wrapper around \`gh copilot suggest\` to suggest a command based on a natural language description of the desired output effort.
	Supports executing suggested commands if applicable.

	USAGE
	  $FUNCNAME [flags] <prompt>

	FLAGS
	  -d, --debug           Enable debugging
	  -h, --help            Display help usage
	      --hostname        The GitHub host to use for authentication
	  -t, --target target   Target for suggestion; must be shell, gh, git
	                        default: "$TARGET"

	EXAMPLES

	- Guided experience
	  $ $FUNCNAME

	- Git use cases
	  $ $FUNCNAME -t git "Undo the most recent local commits"
	  $ $FUNCNAME -t git "Clean up local branches"
	  $ $FUNCNAME -t git "Setup LFS for images"

	- Working with the GitHub CLI in the terminal
	  $ $FUNCNAME -t gh "Create pull request"
	  $ $FUNCNAME -t gh "List pull requests waiting for my review"
	  $ $FUNCNAME -t gh "Summarize work I have done in issues and pull requests for promotion"

	- General use cases
	  $ $FUNCNAME "Kill processes holding onto deleted files"
	  $ $FUNCNAME "Test whether there are SSL/TLS issues with github.com"
	  $ $FUNCNAME "Convert SVG to PNG and resize"
	  $ $FUNCNAME "Convert MOV to animated PNG"
	EOF

	local OPT OPTARG OPTIND
	while getopts "dht:-:" OPT; do
		if [ "$OPT" = "-" ]; then     # long option: reformulate OPT and OPTARG
			OPT="${OPTARG%%=*}"       # extract long option name
			OPTARG="${OPTARG#"$OPT"}" # extract long option argument (may be empty)
			OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
		fi

		case "$OPT" in
			debug | d)
				GH_DEBUG=api
				;;

			help | h)
				echo "$__USAGE"
				return 0
				;;

			hostname)
				GH_HOST="$OPTARG"
				;;

			target | t)
				TARGET="$OPTARG"
				;;
		esac
	done

	# shift so that $@, $1, etc. refer to the non-option arguments
	shift "$((OPTIND-1))"

	TMPFILE="$(mktemp -t gh-copilotXXXXXX)"
	trap 'rm -f "$TMPFILE"' EXIT
	if GH_DEBUG="$GH_DEBUG" GH_HOST="$GH_HOST" gh copilot suggest -t "$TARGET" "$@" --shell-out "$TMPFILE"; then
		if [ -s "$TMPFILE" ]; then
			FIXED_CMD="$(cat $TMPFILE)"
			print -s -- "$FIXED_CMD"
			echo
			eval -- "$FIXED_CMD"
		fi
	else
		return 1
	fi
}

## gh copilot explain
ghce() {
	FUNCNAME="$funcstack[1]"
	local GH_DEBUG="$GH_DEBUG"
	local GH_HOST="$GH_HOST"

	read -r -d '' __USAGE <<-EOF
	Wrapper around \`gh copilot explain\` to explain a given input command in natural language.

	USAGE
	  $FUNCNAME [flags] <command>

	FLAGS
	  -d, --debug      Enable debugging
	  -h, --help       Display help usage
	      --hostname   The GitHub host to use for authentication

	EXAMPLES

	# View disk usage, sorted by size
	$ $FUNCNAME 'du -sh | sort -h'

	# View git repository history as text graphical representation
	$ $FUNCNAME 'git log --oneline --graph --decorate --all'

	# Remove binary objects larger than 50 megabytes from git history
	$ $FUNCNAME 'bfg --strip-blobs-bigger-than 50M'
	EOF

	local OPT OPTARG OPTIND
	while getopts "dh-:" OPT; do
		if [ "$OPT" = "-" ]; then     # long option: reformulate OPT and OPTARG
			OPT="${OPTARG%%=*}"       # extract long option name
			OPTARG="${OPTARG#"$OPT"}" # extract long option argument (may be empty)
			OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
		fi

		case "$OPT" in
			debug | d)
				GH_DEBUG=api
				;;

			help | h)
				echo "$__USAGE"
				return 0
				;;

			hostname)
				GH_HOST="$OPTARG"
				;;
		esac
	done

	# shift so that $@, $1, etc. refer to the non-option arguments
	shift "$((OPTIND-1))"

	GH_DEBUG="$GH_DEBUG" GH_HOST="$GH_HOST" gh copilot explain "$@"
}

# dotfilesの同期処理を実行
sync-dotfiles() {
  # dotfilesディレクトリのパスを取得
  local DOTFILES_DIR="$HOME/dotfiles"
  
  # dotfilesディレクトリが存在するか確認
  if [ ! -d "$DOTFILES_DIR" ]; then
    echo "Error: dotfiles directory not found at $DOTFILES_DIR"
    return 1
  fi
  
  # sync.shスクリプトが存在するか確認
  if [ ! -f "$DOTFILES_DIR/sync.sh" ]; then
    echo "Error: sync.sh not found at $DOTFILES_DIR/sync.sh"
    return 1
  fi
  
  # sync.shを実行
  echo "Running dotfiles sync script..."
  if bash "$DOTFILES_DIR/sync.sh"; then
    echo ""
    echo "Reloading ZSH configuration..."
    
    # ZSHの設定ファイルを再読み込み
    source ~/.zshrc
    
    echo "✓ ZSH configuration reloaded successfully!"
    echo "✓ Dotfiles sync completed!"
  else
    echo "✗ Sync script failed. ZSH configuration not reloaded."
    return 1
  fi
}

