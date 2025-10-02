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

# ============================================================
# Functions
# ============================================================
# SSH with tmux auto-attach
sshtmux() {
  ssh -t "$1" "tmux new -A -s main"
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


source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
