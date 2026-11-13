#!/usr/bin/env bash
# Prepare an existing machine for the Stow-based installer.
# Dry-run by default; pass --apply to make changes.

set -uo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
APPLY=0
PRUNE_BACKUPS=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FOLD_PACKAGES=(aerospace ghostty git lazygit nvim starship tmux zsh)
UNFOLD_PACKAGES=(opencode rex)

usage() {
  cat <<'EOF'
Usage: migrate-to-stow.sh [options]

Remove legacy links and back up known config paths that prevent GNU Stow from
owning this repository's packages. The default is a dry run.

Options:
  --apply          make the reported changes
  --prune-backups  remove stale *.backup.* links pointing into this repository
                   (requires --apply to actually remove them)
  --dotfiles DIR   use a checkout other than ~/dotfiles
  -h, --help       show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply)
      APPLY=1
      ;;
    --prune-backups)
      PRUNE_BACKUPS=1
      ;;
    --dotfiles)
      shift
      [ "$#" -gt 0 ] && [ -n "$1" ] || {
        printf '%s\n' "error: --dotfiles requires a directory" >&2
        exit 2
      }
      DOTFILES_DIR="$1"
      ;;
    --dotfiles=*)
      DOTFILES_DIR="${1#*=}"
      [ -n "$DOTFILES_DIR" ] || {
        printf '%s\n' "error: --dotfiles requires a directory" >&2
        exit 2
      }
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'error: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

DOTFILES_DIR="${DOTFILES_DIR%/}"
[ -d "$DOTFILES_DIR/.git" ] || {
  printf "${RED}error: %s is not a dotfiles checkout${NC}\n" "$DOTFILES_DIR" >&2
  exit 1
}

REPO_REAL="$(cd "$DOTFILES_DIR" && pwd -P)"
REPO_BASE="$(basename "$REPO_REAL")"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

FOLD_TARGETS=(
  "$HOME/.aerospace.toml"
  "$HOME/.config/ghostty"
  "$HOME/.config/lazygit"
  "$HOME/.config/nvim"
  "$HOME/.config/starship.toml"
  "$HOME/.gitconfig"
  "$HOME/.tmux.conf"
  "$HOME/.zshrc"
)

UNFOLD_DIRS=(
  "$HOME/.config/opencode"
  "$HOME/.config/rex"
)

LAUNCH_AGENT_LINKS=(
  "$HOME/Library/LaunchAgents/com.${USER:-$(id -un)}.brew-update.plist"
  "$HOME/Library/LaunchAgents/com.${USER:-$(id -un)}.wallsync.plist"
)

LEGACY_GENERATED_PLISTS=(
  "$REPO_REAL/com.${USER:-$(id -un)}.brew-update.plist"
  "$REPO_REAL/com.${USER:-$(id -un)}.wallsync.plist"
)

show_path() {
  case "$1" in
    "$HOME") printf '~' ;;
    "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;;
    *) printf '%s' "$1" ;;
  esac
}

points_into_repo() {
  local link="$1" raw resolved
  raw="$(readlink "$link" 2>/dev/null)" || return 1

  case "$raw" in
    "$REPO_REAL"|"$REPO_REAL"/*|"$DOTFILES_DIR"|"$DOTFILES_DIR"/*) return 0 ;;
  esac

  resolved="$(realpath "$link" 2>/dev/null || true)"
  case "$resolved" in
    "$REPO_REAL"|"$REPO_REAL"/*) return 0 ;;
  esac

  case "$raw" in
    "$REPO_BASE"|"$REPO_BASE"/*|../"$REPO_BASE"|../"$REPO_BASE"/*|../../"$REPO_BASE"|../../"$REPO_BASE"/*)
      return 0
      ;;
  esac
  return 1
}

is_legacy_link() {
  local link="$1" raw
  points_into_repo "$link" || return 1
  raw="$(readlink "$link")"
  case "$raw" in
    /*) return 0 ;;
  esac
  [ -e "$link" ] && return 1
  return 0
}

backup_name() {
  local target="$1" candidate="$target.backup.$TIMESTAMP" suffix=1
  while [ -e "$candidate" ] || [ -L "$candidate" ]; do
    candidate="$target.backup.$TIMESTAMP.$suffix"
    suffix=$((suffix + 1))
  done
  printf '%s' "$candidate"
}

removed=0
backed_up=0
skipped=0
pruned=0
runtime_moved=0

remove_legacy_link() {
  local target="$1"
  if [ ! -L "$target" ]; then
    return 1
  fi
  if ! is_legacy_link "$target"; then
    printf "${YELLOW}SKIP${NC}    %s -> %s (not a legacy link)\n" \
      "$(show_path "$target")" "$(readlink "$target")"
    skipped=$((skipped + 1))
    return 0
  fi
  if [ "$APPLY" -eq 1 ]; then
    rm "$target"
    printf "${GREEN}REMOVED${NC} %s\n" "$(show_path "$target")"
  else
    printf 'WOULD REMOVE  %s -> %s\n' "$(show_path "$target")" "$(readlink "$target")"
  fi
  removed=$((removed + 1))
  return 0
}

backup_target() {
  local target="$1" backup
  backup="$(backup_name "$target")"
  if [ "$APPLY" -eq 1 ]; then
    mv "$target" "$backup"
    printf "${GREEN}BACKED UP${NC} %s -> %s\n" \
      "$(show_path "$target")" "$(show_path "$backup")"
  else
    printf 'WOULD BACK UP  %s -> %s\n' \
      "$(show_path "$target")" "$(show_path "$backup")"
  fi
  backed_up=$((backed_up + 1))
}

unfold_package_dir() {
  local target="$1"
  if ! points_into_repo "$target"; then
    printf "${YELLOW}SKIP${NC}    %s -> %s (points outside this repository)\n" \
      "$(show_path "$target")" "$(readlink "$target")"
    skipped=$((skipped + 1))
    return 1
  fi

  if [ "$APPLY" -eq 1 ]; then
    rm "$target"
    mkdir -p "$target"
    printf "${GREEN}UNFOLDED${NC} %s\n" "$(show_path "$target")"
  else
    printf 'WOULD UNFOLD  %s -> %s\n' "$(show_path "$target")" "$(readlink "$target")"
  fi
  removed=$((removed + 1))
  return 0
}

move_runtime_entry() {
  local source="$1" destination="$2" preserved
  if [ ! -e "$source" ] && [ ! -L "$source" ]; then
    return
  fi

  if [ "$APPLY" -eq 0 ]; then
    printf 'WOULD MOVE    %s -> %s\n' \
      "$(show_path "$source")" "$(show_path "$destination")"
    runtime_moved=$((runtime_moved + 1))
    return
  fi

  mkdir -p "$(dirname "$destination")"
  if [ -e "$destination" ] || [ -L "$destination" ]; then
    preserved="$(backup_name "$destination.from-repo")"
    mv "$source" "$preserved"
    printf "${GREEN}PRESERVED${NC} %s -> %s (destination already existed)\n" \
      "$(show_path "$source")" "$(show_path "$preserved")"
  else
    mv "$source" "$destination"
    printf "${GREEN}MOVED${NC}    %s -> %s\n" \
      "$(show_path "$source")" "$(show_path "$destination")"
  fi
  runtime_moved=$((runtime_moved + 1))
}

printf 'Dotfiles repo: %s\n' "$REPO_REAL"
if [ "$APPLY" -eq 1 ]; then
  printf '%s\n' "Mode: apply"
else
  printf '%s\n' "Mode: dry run (re-run with --apply)"
fi

printf '\n== Folded package targets\n'
for target in "${FOLD_TARGETS[@]}"; do
  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    continue
  fi
  if [ -L "$target" ]; then
    remove_legacy_link "$target" || true
    continue
  fi
  # Real files and directories at folded package roots are preserved as a
  # backup. Stow can then create the package's intended top-level link.
  backup_target "$target"
done

printf '\n== Unfolded package targets\n'
for index in "${!UNFOLD_PACKAGES[@]}"; do
  package="${UNFOLD_PACKAGES[$index]}"
  config_dir="${UNFOLD_DIRS[$index]}"
  repo_config_dir="$REPO_REAL/$package/.config/$package"
  folded_dry_run=0

  if [ -L "$config_dir" ]; then
    if unfold_package_dir "$config_dir"; then
      [ "$APPLY" -eq 1 ] || folded_dry_run=1
    else
      continue
    fi
  elif [ -e "$config_dir" ] && [ ! -d "$config_dir" ]; then
    backup_target "$config_dir"
    [ "$APPLY" -eq 0 ] || mkdir -p "$config_dir"
  elif [ ! -e "$config_dir" ] && [ "$APPLY" -eq 1 ]; then
    mkdir -p "$config_dir"
  fi

  # OpenCode creates these entries at runtime. Older folded installations may
  # have written them through the directory link and into the package itself.
  if [ "$package" = "opencode" ]; then
    for runtime_entry in node_modules package.json package-lock.json .gitignore service.json; do
      move_runtime_entry \
        "$repo_config_dir/$runtime_entry" \
        "$config_dir/$runtime_entry"
    done
  fi

  # During a dry run, child paths still resolve through the folded link and
  # would look like conflicting real files even though they are the sources.
  if [ "$folded_dry_run" -eq 1 ]; then
    continue
  fi

  while IFS= read -r source; do
    [ -n "$source" ] || continue
    relative="${source#"$repo_config_dir"/}"
    target="$config_dir/$relative"

    if [ ! -e "$target" ] && [ ! -L "$target" ]; then
      continue
    fi
    if [ -L "$target" ]; then
      remove_legacy_link "$target" || true
    else
      backup_target "$target"
    fi
  done < <(find "$repo_config_dir" -type f -print 2>/dev/null)
done

printf '\n== Legacy LaunchAgent links\n'
for target in "${LAUNCH_AGENT_LINKS[@]}"; do
  if [ -L "$target" ]; then
    remove_legacy_link "$target" || true
  fi
done

for target in "${LEGACY_GENERATED_PLISTS[@]}"; do
  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    continue
  fi
  if [ "$APPLY" -eq 1 ]; then
    rm -f "$target"
    printf "${GREEN}REMOVED${NC} %s (legacy generated plist)\n" "$(show_path "$target")"
  else
    printf 'WOULD REMOVE  %s (legacy generated plist)\n' "$(show_path "$target")"
  fi
  removed=$((removed + 1))
done

if [ "$PRUNE_BACKUPS" -eq 1 ]; then
  printf '\n== Stale backup links\n'
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    points_into_repo "$target" || continue
    if [ "$APPLY" -eq 1 ]; then
      rm "$target"
      printf "${GREEN}REMOVED${NC} %s\n" "$(show_path "$target")"
    else
      printf 'WOULD REMOVE  %s -> %s\n' "$(show_path "$target")" "$(readlink "$target")"
    fi
    pruned=$((pruned + 1))
  done < <(find "$HOME" -maxdepth 3 -name '*.backup.*' -type l \
    -not -path "$REPO_REAL/*" 2>/dev/null)
fi

printf '\n== Summary\n'
printf '  links:   %d\n' "$removed"
printf '  backups: %d\n' "$backed_up"
printf '  runtime: %d\n' "$runtime_moved"
printf '  pruned:  %d\n' "$pruned"
printf '  skipped: %d (left untouched)\n' "$skipped"

if [ "$APPLY" -eq 0 ]; then
  printf '\n'
  if [ "$removed" -eq 0 ] && [ "$backed_up" -eq 0 ] &&
    [ "$runtime_moved" -eq 0 ] && [ "$pruned" -eq 0 ]; then
    printf "${GREEN}Nothing to migrate.${NC}\n"
  else
    printf "${YELLOW}Dry run: nothing changed.${NC} Re-run with --apply.\n"
  fi
  exit 0
fi

if ! command -v stow >/dev/null 2>&1; then
  printf '\nStow is not installed; skipping verification.\n'
  exit 0
fi

printf '\n== Verifying with Stow\n'
if stow --simulate --target="$HOME" --dir="$REPO_REAL" \
  --ignore='\.DS_Store' "${FOLD_PACKAGES[@]}" >/dev/null 2>&1 &&
  stow --simulate --no-folding --target="$HOME" --dir="$REPO_REAL" \
    --ignore='\.DS_Store' "${UNFOLD_PACKAGES[@]}" >/dev/null 2>&1; then
  printf "${GREEN}OK:${NC} Stow reports no remaining conflicts.\n"
  printf 'Run %s/install_script.sh to finish the installation.\n' "$REPO_REAL"
  exit 0
fi

printf "${RED}Conflicts remain.${NC} Stow reports:\n" >&2
stow --simulate --verbose --target="$HOME" --dir="$REPO_REAL" \
  --ignore='\.DS_Store' "${FOLD_PACKAGES[@]}" 2>&1 | sed 's/^/  /'
stow --simulate --verbose --no-folding --target="$HOME" --dir="$REPO_REAL" \
  --ignore='\.DS_Store' "${UNFOLD_PACKAGES[@]}" 2>&1 | sed 's/^/  /'
exit 1
