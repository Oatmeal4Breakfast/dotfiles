# ============================================================
# PATH Configuration
# ============================================================
# Homebrew
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# LM Studio CLI
export PATH="$PATH:$HOME/.lmstudio/bin"

# Local bin (if it exists)
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# ============================================================
# Modern Shell Tools
# ============================================================
# Starship prompt
eval "$(starship init zsh)"

# fzf fuzzy finder
eval "$(fzf --zsh)"

# ============================================================
# Aliases (muscle memory only)
# ============================================================
alias ls="eza --icons --git"
alias cat="bat"
alias lg="lazygit"

# ============================================================
# Functions
# ============================================================
# SSH with tmux auto-attach
sshtmux() {
  TERM=xterm-256color ssh -t "$1" "tmux new -A -s main"
}
# ============================================================
# History Configuration
# ============================================================
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# ============================================================
# Completion
# ============================================================
autoload -Uz compinit && compinit

# UV CLI
export PATH="$HOME/.local/bin:$PATH"

# expand the file descripter limit for my shell
ulimit -n 10240

if [ -n "${HOMEBREW_PREFIX:-}" ] &&
  [ -f "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
  source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# opencode
export PATH="$HOME/.opencode/bin:$PATH"
# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
if [ -n "${HOMEBREW_PREFIX:-}" ]; then
  export PATH="$HOMEBREW_PREFIX/opt/curl/bin:$PATH"
fi
export VISUAL="nvim"
export EDITOR="$VISUAL"
