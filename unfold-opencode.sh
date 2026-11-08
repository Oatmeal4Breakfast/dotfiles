#!/usr/bin/env bash
# unfold-opencode.sh — keep OpenCode's runtime secrets out of this repo.
#
# GNU Stow folds directories by default, so ~/.config/opencode can become a
# symlink to ~/dotfiles/opencode/.config/opencode. OpenCode then writes its
# private service password to ~/.config/opencode/service.json, which lands
# inside the repo. This script unfolds that directory, moves runtime files back
# into $HOME, and re-stows only the tracked config files.
#
# Usage:
#   ./unfold-opencode.sh [--yes] [--dry-run] [DOTFILES_DIR]
#
# Run this from a normal terminal, not from inside an OpenCode session:
# the script stops the background service.

set -euo pipefail

ASSUME_YES=0
DRY_RUN=0
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

usage() {
  sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes) ASSUME_YES=1 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    *) DOTFILES_DIR="$1" ;;
  esac
  shift
done

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
REPO_CONFIG_DIR="$DOTFILES_DIR/opencode/.config/opencode"
RUNTIME_FILES=(node_modules package.json package-lock.json .gitignore service.json)
CONFIG_FILES=(opencode.jsonc cli.json tui.json)

die() { echo "ERROR: $*" >&2; exit 1; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

[ -d "$DOTFILES_DIR" ] || die "dotfiles directory not found: $DOTFILES_DIR"
[ -d "$REPO_CONFIG_DIR" ] || die "opencode package not found: $REPO_CONFIG_DIR"
command -v stow >/dev/null 2>&1 || die "stow is not installed"

cat <<EOF
This will:
  1. Stop the OpenCode background service (if installed).
  2. Make $CONFIG_DIR a real directory.
  3. Move runtime files out of the repo:
       ${RUNTIME_FILES[*]}
  4. Re-stow the opencode package with --no-folding.
  5. Restart the OpenCode service.
EOF

if [ "$ASSUME_YES" -ne 1 ] && [ "$DRY_RUN" -ne 1 ]; then
  read -r -p "Continue? [y/N] " reply
  case "$reply" in
    y|Y|yes|YES) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

# 1. Stop the service so it releases the config directory.
if command -v opencode >/dev/null 2>&1; then
  run opencode service stop >/dev/null 2>&1 || true
fi

# 2. Unfold: remove the directory symlink only if it points into the repo.
if [ -L "$CONFIG_DIR" ]; then
  if [ -e "$CONFIG_DIR" ]; then
    resolved="$(cd "$CONFIG_DIR" && pwd -P)"
    dotfiles_real="$(cd "$DOTFILES_DIR" && pwd -P)"
    case "$resolved" in
      "$dotfiles_real"/*)
        echo "Unfolding $CONFIG_DIR (was -> $(readlink "$CONFIG_DIR"))"
        run rm "$CONFIG_DIR"
        ;;
      *)
        die "$CONFIG_DIR is a symlink outside the dotfiles repo ($resolved); refusing to remove it"
        ;;
    esac
  else
    echo "Removing dangling symlink $CONFIG_DIR"
    run rm "$CONFIG_DIR"
  fi
fi
run mkdir -p "$CONFIG_DIR"

# 3. Move runtime artifacts out of the repo. Never overwrite an existing file.
for f in "${RUNTIME_FILES[@]}"; do
  src="$REPO_CONFIG_DIR/$f"
  dst="$CONFIG_DIR/$f"
  if [ -e "$src" ] || [ -L "$src" ]; then
    dst_exists=0
    if [ -e "$dst" ] || [ -L "$dst" ]; then
      dst_exists=1
    fi
    # In a dry run the directory is still folded, so $dst resolves into the repo.
    if [ "$DRY_RUN" -eq 1 ] && [ -L "$CONFIG_DIR" ]; then
      dst_exists=0
    fi
    if [ "$dst_exists" -eq 1 ]; then
      echo "Skipping $f: $dst already exists"
    else
      echo "Moving $f out of the repo"
      run mv "$src" "$dst"
    fi
  fi
done

# 4. Clear anything that would block Stow from linking the config files.
for f in "${CONFIG_FILES[@]}"; do
  # In a dry run the directory is still folded, so these resolve into the repo.
  if [ "$DRY_RUN" -eq 1 ] && [ -L "$CONFIG_DIR" ]; then
    continue
  fi
  dst="$CONFIG_DIR/$f"
  if [ -L "$dst" ]; then
    run rm "$dst"
  elif [ -e "$dst" ]; then
    backup="$dst.bak.$(date +%Y%m%d_%H%M%S)"
    echo "Backing up $dst -> $backup"
    run mv "$dst" "$backup"
  fi
done

# 5. Re-stow without folding so the directory stays real.
cd "$DOTFILES_DIR"
run stow --no-folding --target="$HOME" --dir="$DOTFILES_DIR" opencode

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry run complete; nothing was changed."
  exit 0
fi

# 6. Verify the end state.
fail=0
if [ -L "$CONFIG_DIR" ]; then
  echo "ERROR: $CONFIG_DIR is still a symlink" >&2
  fail=1
fi
for f in "${CONFIG_FILES[@]}"; do
  if [ ! -L "$CONFIG_DIR/$f" ]; then
    echo "ERROR: $CONFIG_DIR/$f is not a symlink into the repo" >&2
    fail=1
  fi
done
if [ -e "$REPO_CONFIG_DIR/service.json" ]; then
  echo "ERROR: service.json is still inside the repo" >&2
  fail=1
fi

# 7. Restart the service.
if command -v opencode >/dev/null 2>&1; then
  opencode service start >/dev/null 2>&1 || true
fi

if [ "$fail" -ne 0 ]; then
  die "verification failed; inspect the messages above"
fi

echo "Done. Runtime secrets now live in $CONFIG_DIR, outside the repo."
