#!/bin/bash
# Dotfiles Installation Script
# Usage: curl -fsSL https://raw.githubusercontent.com/Oatmeal4Breakfast/dotfiles/main/install_script.sh | bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DOTFILES_DIR="$HOME/dotfiles"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_LABEL="com.${USER}.brew-update"
PLIST_DEST="$LAUNCH_AGENTS_DIR/$PLIST_LABEL.plist"

if [[ "$OSTYPE" != "darwin"* ]]; then
  echo -e "${RED}This script is designed for macOS${NC}"
  exit 1
fi

# Install Homebrew if not installed
if ! command -v brew &>/dev/null; then
  echo -e "${YELLOW}Installing Homebrew...${NC}"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo -e "${GREEN}✓ Homebrew already installed${NC}"
fi

# Clone dotfiles repo if not exists, otherwise pull
if [ ! -d "$DOTFILES_DIR" ]; then
  echo -e "${YELLOW}Cloning dotfiles repository...${NC}"
  git clone https://github.com/Oatmeal4Breakfast/dotfiles.git "$DOTFILES_DIR"
else
  echo -e "${GREEN}✓ Dotfiles directory exists${NC}"
  git -C "$DOTFILES_DIR" pull
fi

# Install packages from Brewfile (includes stow)
echo -e "${YELLOW}Installing packages from Brewfile...${NC}"
brew bundle --file="$DOTFILES_DIR/Brewfile"

# Install fzf key bindings
echo -e "${YELLOW}Setting up fzf...${NC}"
"$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc

# Set zsh as default shell
if [ "$SHELL" != "$(which zsh)" ]; then
  echo -e "${YELLOW}Setting zsh as default shell...${NC}"
  chsh -s "$(which zsh)"
fi

# ── Stow packages ────────────────────────────────────────────────────────────

echo -e "${YELLOW}Symlinking dotfiles with stow...${NC}"

# Remove a symlink or back up a real file/dir so stow can take ownership.
clear_stow_target() {
  local target="$1"
  if [ -L "$target" ]; then
    rm "$target"
  elif [ -d "$target" ]; then
    echo -e "${YELLOW}Backing up $target${NC}"
    mv "$target" "$target.backup.$(date +%Y%m%d_%H%M%S)"
  elif [ -f "$target" ]; then
    echo -e "${YELLOW}Backing up $target${NC}"
    mv "$target" "$target.backup.$(date +%Y%m%d_%H%M%S)"
  fi
}

# Packages whose top-level stow targets are dotfiles directly in $HOME
clear_stow_target "$HOME/.zshrc"
clear_stow_target "$HOME/.tmux.conf"
clear_stow_target "$HOME/.aerospace.toml"

# Packages whose top-level stow targets are dirs inside $HOME/.config
clear_stow_target "$HOME/.config/ghostty"
clear_stow_target "$HOME/.config/nvim"

stow --target="$HOME" --dir="$DOTFILES_DIR" aerospace ghostty nvim tmux zsh
echo -e "${GREEN}✓ Stowed all packages${NC}"

# ── LaunchAgent for brew-update ──────────────────────────────────────────────

echo -e "${YELLOW}Installing brew-update LaunchAgent...${NC}"

mkdir -p "$LAUNCH_AGENTS_DIR"

# Generate plist from template, substituting __HOME__ and __USER__
sed \
  -e "s|__HOME__|$HOME|g" \
  -e "s|__USER__|$USER|g" \
  "$DOTFILES_DIR/brew-update.plist.template" > "$DOTFILES_DIR/$PLIST_LABEL.plist"

# Symlink into LaunchAgents, backing up any existing real file
if [ -e "$PLIST_DEST" ] && [ ! -L "$PLIST_DEST" ]; then
  mv "$PLIST_DEST" "$PLIST_DEST.backup.$(date +%Y%m%d_%H%M%S)"
fi

ln -sf "$DOTFILES_DIR/$PLIST_LABEL.plist" "$PLIST_DEST"
echo -e "${GREEN}✓ Linked $PLIST_DEST${NC}"

# Load (or reload) the agent
launchctl unload "$PLIST_DEST" 2>/dev/null || true
launchctl load "$PLIST_DEST"
echo -e "${GREEN}✓ LaunchAgent loaded (runs daily at 09:00)${NC}"

# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Dotfiles installation complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Restart your terminal or run: source ~/.zshrc"
echo "2. Install Ghostty from https://ghostty.org if not already installed"
echo "3. Open Neovim and let LazyVim install plugins"
echo ""
