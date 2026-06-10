# My Dotfiles

Personal configuration files for macOS development environment, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's Included

- **Zsh** - Shell configuration with Starship prompt
- **Tmux** - Terminal multiplexer for session management
- **Ghostty** - Fast, modern terminal emulator
- **Neovim** - LazyVim configuration
- **Starship** - Cross-shell prompt (default config)
- **AeroSpace** - i3-style tiling window manager
- **btop** - Resource monitor TUI
- **lazygit** - Git TUI
- **uv** - Python environment management
- and much more (see `Brewfile`)

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/Oatmeal4Breakfast/dotfiles/main/install_script.sh | bash
```

The script will:
1. Install Homebrew (if needed)
2. Clone this repo to `~/dotfiles`
3. Install all packages from `Brewfile` (includes `stow`)
4. Use stow to symlink each config package into `$HOME`
5. Generate and install the `brew-update` LaunchAgent for daily Homebrew maintenance

## Structure

Each top-level directory is a stow package. The internal layout mirrors `$HOME`, so stow knows exactly where to create symlinks.

```
dotfiles/
├── aerospace/          → ~/.aerospace.toml
│   └── .aerospace.toml
├── ghostty/            → ~/.config/ghostty/
│   └── .config/ghostty/
│       ├── config
│       └── shaders/
├── nvim/               → ~/.config/nvim/
│   └── .config/nvim/
│       ├── init.lua
│       └── lua/
├── tmux/               → ~/.tmux.conf
│   └── .tmux.conf
├── zsh/                → ~/.zshrc
│   └── .zshrc
├── brew-update.plist.template   (LaunchAgent template — __HOME__/__USER__ substituted at install)
├── brew-update.sh               (called by the LaunchAgent daily at 09:00)
└── Brewfile
```

## Manual Stow Usage

To symlink a single package after install:

```bash
stow --target="$HOME" --dir="$HOME/dotfiles" <package>
```

To remove a package's symlinks:

```bash
stow --delete --target="$HOME" --dir="$HOME/dotfiles" <package>
```

## LaunchAgent

The `brew-update` LaunchAgent runs `brew-update.sh` daily at 09:00. The install script generates `com.$USER.brew-update.plist` from the template (substituting your actual `$HOME` and `$USER`) and loads it into `~/Library/LaunchAgents/`.

Logs are written to `~/Library/Logs/brew-maintenance.log`.
