# Copies the live configs into ~/dotfiles, then commits and pushes whatever
# changed. Runs from the dotfiles-sync timer in dotfiles-sync.nix.
#
# nvim is not copied: ~/.config/nvim is generated from nixos/nvim, so edits
# belong there and copying the output back would add nothing.

repo="$HOME/dotfiles"
live="$HOME/.config"
cd "$repo"

# Never commit on top of a rebase, a merge, or a side branch.
git_dir=$(git rev-parse --git-dir)
if [ -e "$git_dir/rebase-merge" ] || [ -e "$git_dir/rebase-apply" ] || [ -e "$git_dir/MERGE_HEAD" ]; then
  echo "dotfiles-sync: a rebase or merge is in progress, skipping"
  exit 0
fi
if [ "$(git branch --show-current)" != "master" ]; then
  echo "dotfiles-sync: not on master, skipping"
  exit 0
fi

# --delete would empty the repo's copy if the live directory ever went missing.
if [ -f "$live/quickshell/shell.qml" ]; then
  rsync -a --delete --exclude='.claude/' --exclude='*.bak*' "$live/quickshell/" quickshell/
fi

# Only files the repo already tracks: these directories also hold things that
# should stay private or are just noise (history, fish_variables).
for dir in alacritty fish foot fuzzel ghostty gtk-3.0 mango niri nushell; do
  while IFS= read -r -d '' file; do
    if [ "$file" != "fish/fish_variables" ] && [ -f "$live/$file" ]; then
      cp -fL "$live/$file" "$file"
    fi
  done < <(git ls-files -z -- "$dir")
done

git add -A

if ! git diff --cached --quiet; then
  # The repo is public, so a likely credential stops the whole commit.
  secrets='sk-ant-[A-Za-z0-9_-]{20,}|gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|AIza[0-9A-Za-z_-]{35}|AKIA[0-9A-Z]{16}|xox[bp]-[0-9A-Za-z-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|(api[_-]?key|token|secret)["'"'"' ]*[:=] *["'"'"'][A-Za-z0-9_-]{20,}'
  if git diff --cached | grep -E '^\+' | grep -qiE "$secrets"; then
    git reset -q
    echo "dotfiles-sync: possible secret in the changes, nothing committed"
    notify-send -u critical "Dotfiles not pushed" "A change looks like it contains a secret. Check git diff in ~/dotfiles."
    exit 1
  fi

  changed=$(git diff --cached --name-only | cut -d/ -f1 | sort -u | paste -sd ' ')
  git commit -q -m "Auto-sync: $changed"
fi

# Separate from the commit so a push that failed offline is retried next run.
if [ "$(git rev-list --count '@{upstream}..HEAD')" -gt 0 ]; then
  if ! git pull -q --rebase; then
    # A failed pull with no rebase underway just means GitHub was unreachable.
    if [ -e "$git_dir/rebase-merge" ] || [ -e "$git_dir/rebase-apply" ]; then
      git rebase --abort
      notify-send -u critical "Dotfiles not pushed" "GitHub has changes that conflict with ~/dotfiles."
    fi
    echo "dotfiles-sync: pull failed, will retry next run"
    exit 1
  fi
  git push -q
fi
