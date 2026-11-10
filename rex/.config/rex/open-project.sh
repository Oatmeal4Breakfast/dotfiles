#!/bin/zsh
# Pick a project folder with fzf and switch to a session named after it, creating
# the session first if it isn't open. Run by the "Open Project" palette action.
# zsh rather than sh so fzf picks up FZF_DEFAULT_OPTS from .zshenv.
set -eu

roots=()
for root in "$HOME/dev" "$HOME/dotfiles" "$HOME/Documents" "$HOME/Downloads" "$HOME/homelab"; do
  [[ -d "$root" ]] && roots+=("$root")
done
if ((${#roots} == 0)); then
  printf 'No project directories found. Press Return to close.'
  read -r _
  exit 0
fi

label=$(find "${roots[@]}" -mindepth 1 -maxdepth 1 -type d -not -name '.*' |
  sed "s|^$HOME|~|" | sort | fzf --prompt 'Project: ') || exit 0
dir="$HOME${label#\~}"

session=$(rex ls --json | jq -r --arg label "$label" '[.sessions[] | select(.label == $label)][0].session_id // empty')
if [ -z "$session" ]; then
  session=$(rex new "$label" -c "$dir" --json | jq -r '.session_id')
fi

"$(dirname "$0")/select-session.sh" "$session" "$label"
