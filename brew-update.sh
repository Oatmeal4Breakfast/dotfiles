#!/bin/zsh

echo "Updating Homebrew..."

DOTFILES_DIR="$HOME/dotfiles"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

brew update

echo "Upgrading formulae.."
brew upgrade --formula || true

echo "Upgrading casks.."
brew upgrade --cask || true

echo "cleaning up Homebrew cache.."
brew cleanup --prune=all

echo "dumping out current config"
brew bundle dump --file="$DOTFILES_DIR/Brewfile" --force --describe

echo "Committing Brewfile..."

cd "$DOTFILES_DIR"
git add Brewfile
git dif --cached --quite || git commit -m "chore: update Brewfile"
git push || echo "git push failed check ssh agent"

echo "Done."
