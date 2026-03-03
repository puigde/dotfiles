# Interactive zsh config

# Source shared config if not already loaded via .zprofile
# (handles non-login interactive shells like some tmux configs)
[ -z "$EDITOR" ] && [ -f "$HOME/.config/shell/profile" ] && . "$HOME/.config/shell/profile"

# Aliases and functions
[ -f "$HOME/.config/shell/aliases" ] && . "$HOME/.config/shell/aliases"
[ -f "$HOME/.config/shell/functions" ] && . "$HOME/.config/shell/functions"

# Prompt
PROMPT='%n@%1~ %% '

# History
HISTFILE="${HOME}/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE SHARE_HISTORY

# opencode
export PATH=/Users/puigde-epfl/.opencode/bin:$PATH

# bun completions
[ -s "/Users/puigde-epfl/.bun/_bun" ] && source "/Users/puigde-epfl/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
