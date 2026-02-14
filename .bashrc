# Interactive bash config
[ -z "$PS1" ] && return  # bail if non-interactive

[ -f "$HOME/.config/shell/aliases" ] && . "$HOME/.config/shell/aliases"
[ -f "$HOME/.config/shell/functions" ] && . "$HOME/.config/shell/functions"

PS1='\u@\W \$ '

HISTSIZE=10000
HISTFILESIZE=10000
HISTCONTROL=ignoredups:ignorespace

# try
command -v ruby >/dev/null && [ -f "$HOME/.local/bin/try.rb" ] && \
    eval "$(ruby "$HOME/.local/bin/try.rb" init "$HOME/src/tries")"
