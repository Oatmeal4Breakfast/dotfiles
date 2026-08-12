# ============================================================
# PATH Configuration
# ============================================================
# Homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# LM Studio CLI
export PATH="$PATH:/Users/elvinsalcedo/.lmstudio/bin"

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

source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

<<<<<<< Updated upstream
# opencode
export PATH=/Users/thoughts/.opencode/bin:$PATH
=======
# bun completions
[ -s "/Users/elvinsalcedo/.bun/_bun" ] && source "/Users/elvinsalcedo/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
>>>>>>> Stashed changes
