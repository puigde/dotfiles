# Interactive bash config
[ -z "$PS1" ] && return  # bail if non-interactive

[ -f "$HOME/.config/shell/aliases" ] && . "$HOME/.config/shell/aliases"
[ -f "$HOME/.config/shell/functions" ] && . "$HOME/.config/shell/functions"

PS1='\u@\W \$ '

HISTSIZE=10000
HISTFILESIZE=10000
HISTCONTROL=ignoredups:ignorespace

# Linux essentials
if [ "$(uname)" = "Linux" ]; then
    [ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"
    if [ -x /usr/bin/dircolors ]; then
        test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
        alias ls='ls --color=auto'
        alias grep='grep --color=auto'
    fi
    # bash completion
    if ! shopt -oq posix; then
        [ -f /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion
    fi
fi
