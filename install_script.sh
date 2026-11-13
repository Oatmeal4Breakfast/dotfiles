#!/usr/bin/env bash
# Bootstrap and update this macOS dotfiles installation.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Oatmeal4Breakfast/dotfiles/main/install_script.sh | bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
REPO_URL="${REPO_URL:-https://github.com/Oatmeal4Breakfast/dotfiles.git}"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

FOLD_PACKAGES=(aerospace ghostty git lazygit nvim starship tmux zsh)
UNFOLD_PACKAGES=(opencode rex)

info() {
  printf "${YELLOW}%s${NC}\n" "$*"
}

success() {
  printf "${GREEN}✓ %s${NC}\n" "$*"
}

warning() {
  printf "${YELLOW}warning: %s${NC}\n" "$*" >&2
}

die() {
  printf "${RED}error: %s${NC}\n" "$*" >&2
  exit 1
}

if [ "$(uname -s)" != "Darwin" ]; then
  die "this script is designed for macOS"
fi

# Git and Homebrew require the Xcode Command Line Tools.
if ! xcode-select -p >/dev/null 2>&1; then
  info "Installing Xcode Command Line Tools..."
  xcode-select --install
  printf '%s\n' "Re-run this script after the installer finishes."
  exit 0
fi

if ! command -v brew >/dev/null 2>&1; then
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Homebrew is not automatically added to PATH in a non-interactive shell.
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
else
  die "Homebrew was not found after installation"
fi
success "Homebrew is available"

if [ -d "$DOTFILES_DIR/.git" ]; then
  success "Dotfiles checkout exists at $DOTFILES_DIR"
  if [ -n "$(git -C "$DOTFILES_DIR" status --porcelain)" ]; then
    info "Local changes found; skipping git pull."
  else
    info "Updating dotfiles checkout..."
    git -C "$DOTFILES_DIR" pull --ff-only
  fi
elif [ -e "$DOTFILES_DIR" ]; then
  die "$DOTFILES_DIR exists but is not a Git checkout"
else
  info "Cloning dotfiles repository..."
  git clone "$REPO_URL" "$DOTFILES_DIR"
fi

brew_bundle_failed=0
info "Installing packages from Brewfile..."
if brew bundle --file="$DOTFILES_DIR/Brewfile"; then
  success "Homebrew packages are installed"
else
  brew_bundle_failed=1
  warning "Some Brewfile items failed; continuing with configuration."
fi

if ! command -v opencode >/dev/null 2>&1; then
  info "Installing OpenCode..."
  curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path
  export PATH="$HOME/.opencode/bin:$PATH"
fi
success "OpenCode is available"

command -v stow >/dev/null 2>&1 || die "GNU Stow is required but was not installed"

mkdir -p "$HOME/.config"
for package in "${UNFOLD_PACKAGES[@]}"; do
  config_dir="$HOME/.config/$package"
  if [ ! -e "$config_dir" ] && [ ! -L "$config_dir" ]; then
    mkdir -p "$config_dir"
  fi
done

info "Restowing dotfiles..."
if ! stow --restow --target="$HOME" --dir="$DOTFILES_DIR" \
  --ignore='\.DS_Store' "${FOLD_PACKAGES[@]}"; then
  printf "${RED}%s${NC}\n" "Stow found a conflicting path." >&2
  printf '%s\n' "Preview the safe migration with:"
  printf '  %s/migrate-to-stow.sh\n' "$DOTFILES_DIR"
  printf '%s\n' "Then apply it with:"
  printf '  %s/migrate-to-stow.sh --apply\n' "$DOTFILES_DIR"
  exit 1
fi

if ! stow --restow --no-folding --target="$HOME" --dir="$DOTFILES_DIR" \
  --ignore='\.DS_Store' "${UNFOLD_PACKAGES[@]}"; then
  printf "${RED}%s${NC}\n" "Stow found a conflicting path." >&2
  printf 'Run %s/migrate-to-stow.sh to inspect it.\n' "$DOTFILES_DIR"
  exit 1
fi
success "All dotfile packages are stowed"

# Escape replacement text used by sed with "|" as its delimiter.
sed_replacement() {
  printf '%s' "$1" | sed 's/[&|]/\\&/g'
}

install_launch_agent() {
  local template_name="$1"
  local label="$2"
  local template="$DOTFILES_DIR/$template_name"
  local destination="$LAUNCH_AGENTS_DIR/$label.plist"
  local temporary="$destination.tmp.$$"
  local escaped_home escaped_user escaped_dotfiles_dir

  [ -f "$template" ] || die "LaunchAgent template not found: $template"

  escaped_home="$(sed_replacement "$HOME")"
  escaped_user="$(sed_replacement "${USER:-$(id -un)}")"
  escaped_dotfiles_dir="$(sed_replacement "$DOTFILES_DIR")"

  sed \
    -e "s|__HOME__|$escaped_home|g" \
    -e "s|__USER__|$escaped_user|g" \
    -e "s|__DOTFILES_DIR__|$escaped_dotfiles_dir|g" \
    "$template" >"$temporary"
  chmod 644 "$temporary"

  if command -v plutil >/dev/null 2>&1; then
    if ! plutil -lint "$temporary" >/dev/null; then
      rm -f "$temporary"
      die "generated LaunchAgent is invalid: $label"
    fi
  fi

  # The exact label and destination are owned by this installer.
  launchctl bootout "gui/$(id -u)/$label" >/dev/null 2>&1 || true
  mv -f "$temporary" "$destination"

  if launchctl bootstrap "gui/$(id -u)" "$destination"; then
    launchctl kickstart -k "gui/$(id -u)/$label" >/dev/null 2>&1 || true
    success "Installed LaunchAgent $label"
  else
    info "Could not load $label; the rendered plist is at $destination"
  fi
}

mkdir -p "$LAUNCH_AGENTS_DIR" "$HOME/Library/Logs"
chmod +x "$DOTFILES_DIR/brew-update.sh" "$DOTFILES_DIR/wallsync.sh"

info "Installing LaunchAgents..."
install_launch_agent "brew-update.plist.template" "com.${USER:-$(id -un)}.brew-update"
install_launch_agent "wallsync.plist.template" "com.${USER:-$(id -un)}.wallsync"

zsh_path="$(command -v zsh)"
if [ "${SHELL:-}" != "$zsh_path" ]; then
  info "Setting zsh as the default shell..."
  if ! chsh -s "$zsh_path"; then
    info "Could not change the shell; run 'chsh -s $zsh_path' manually."
  fi
fi

printf '\n'
if [ "$brew_bundle_failed" -eq 1 ]; then
  printf "${YELLOW}%s${NC}\n" "========================================"
  printf "${YELLOW}%s${NC}\n" "Dotfiles installation completed with warnings."
  printf "${YELLOW}%s${NC}\n" "Re-run 'brew bundle --file=\"$DOTFILES_DIR/Brewfile\"' to retry."
  printf "${YELLOW}%s${NC}\n" "========================================"
  exit 1
fi

printf "${GREEN}%s${NC}\n" "========================================"
printf "${GREEN}%s${NC}\n" "✓ Dotfiles installation complete!"
printf "${GREEN}%s${NC}\n" "========================================"
printf '\n'
printf '%s\n' "Restart your terminal, then open Neovim to install its plugins."
