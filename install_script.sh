#!/bin/bash
# Dotfiles Installation Script
# Usage: curl -fsSL https://raw.githubusercontent.com/yourusername/dotfiles/main/install.sh | bash

set -e

echo "🚀 Setting up your development environment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Dotfiles directory
DOTFILES_DIR="$HOME/dotfiles"

# Check if running on macOS
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

# Clone dotfiles repo if not exists
if [ ! -d "$DOTFILES_DIR" ]; then
  echo -e "${YELLOW}Cloning dotfiles repository...${NC}"
  git clone https://github.com/yourusername/dotfiles.git "$DOTFILES_DIR"
else
  echo -e "${GREEN}✓ Dotfiles directory exists${NC}"
  cd "$DOTFILES_DIR"
  git pull
fi

cd "$DOTFILES_DIR"

# Install essential tools
echo -e "${YELLOW}Installing essential tools...${NC}"
brew install \
  git \
  neovim \
  tmux \
  starship \
  fzf \
  bat \
  eza \
  ripgrep \
  fd \
  jq

# Install Ghostty (if not installed)
if [ ! -d "/Applications/Ghostty.app" ]; then
  echo -e "${YELLOW}Note: Install Ghostty manually from https://ghostty.org${NC}"
fi

# Backup existing configs
backup_if_exists() {
  if [ -f "$1" ] || [ -d "$1" ]; then
    echo -e "${YELLOW}Backing up existing $1${NC}"
    mv "$1" "$1.backup.$(date +%Y%m%d_%H%M%S)"
  fi
}

# Create symlinks
create_symlink() {
  local source="$DOTFILES_DIR/$1"
  local target="$2"

  backup_if_exists "$target"

  # Create parent directory if needed
  mkdir -p "$(dirname "$target")"

  ln -sf "$source" "$target"
  echo -e "${GREEN}✓ Linked $1${NC}"
}

# Symlink all config files
echo -e "${YELLOW}Creating symlinks...${NC}"

create_symlink "zsh/.zshrc" "$HOME/.zshrc"
create_symlink "tmux/.tmux.conf" "$HOME/.tmux.conf"
create_symlink "ghostty/config" "$HOME/.config/ghostty/config"
create_symlink "starship/starship.toml" "$HOME/.config/starship.toml"
create_symlink "nvim" "$HOME/.config/nvim"

# Install fzf key bindings
echo -e "${YELLOW}Setting up fzf...${NC}"
$(brew --prefix)/opt/fzf/install --key-bindings --completion --no-update-rc

# Set zsh as default shell
if [ "$SHELL" != "$(which zsh)" ]; then
  echo -e "${YELLOW}Setting zsh as default shell...${NC}"
  chsh -s "$(which zsh)"
fi

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
echo -e "${YELLOW}Useful commands:${NC}"
echo "  sshtmux user@host  - SSH with automatic tmux session"
echo "  Ctrl+R             - Search command history with fzf"
echo "  Ctrl+T             - Fuzzy find files"
echo ""
