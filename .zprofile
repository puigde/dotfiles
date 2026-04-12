# Login shell setup
[ -f "$HOME/.config/shell/profile" ] && . "$HOME/.config/shell/profile"

# Obsidian CLI (macOS only)
[ -d "/Applications/Obsidian.app" ] && export PATH="$PATH:/Applications/Obsidian.app/Contents/MacOS"
