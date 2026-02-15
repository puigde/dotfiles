#!/bin/sh
set -e

# Detect OS
OS="$(uname -s)"
echo "Detected OS: $OS"

# Install dependencies
if [ "$OS" = "Darwin" ]; then
    if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew not found. Install it first: https://brew.sh"
        exit 1
    fi
    brew install stow fzf ruby ripgrep nvim tmux </dev/null
elif [ "$OS" = "Linux" ]; then
    sudo apt install -y stow fzf ruby ripgrep neovim tmux </dev/null
else
    echo "Unsupported OS: $OS"
    exit 1
fi

# Ruby-based tools (use brew ruby on macOS since it's keg-only)
if [ "$OS" = "Darwin" ]; then
    /opt/homebrew/opt/ruby/bin/gem install try-cli </dev/null
else
    gem install try-cli </dev/null
fi

# Ask for vault paths
printf 'Lab vault path? [~/Documents/lab] (enter to skip): '
read lab_vault
printf 'Life vault path? [~/Documents/life] (enter to skip): '
read life_vault

# Write local config
mkdir -p "$HOME/.local/state"
cat > "$HOME/.dotfiles.local" << EOF
# Machine-local dotfiles config
EOF

if [ -n "$lab_vault" ]; then
    echo "export LAB_VAULT=\"$lab_vault\"" >> "$HOME/.dotfiles.local"
elif [ -d "$HOME/Documents/lab" ]; then
    echo "export LAB_VAULT=\"\$HOME/Documents/lab\"" >> "$HOME/.dotfiles.local"
fi

if [ -n "$life_vault" ]; then
    echo "export LIFE_VAULT=\"$life_vault\"" >> "$HOME/.dotfiles.local"
elif [ -d "$HOME/Documents/life" ]; then
    echo "export LIFE_VAULT=\"\$HOME/Documents/life\"" >> "$HOME/.dotfiles.local"
fi

# Backup existing conflicting files
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d)"
backup() {
    if [ -e "$1" ] && [ ! -L "$1" ]; then
        mkdir -p "$BACKUP_DIR"
        echo "Backing up $1 → $BACKUP_DIR/"
        mv "$1" "$BACKUP_DIR/"
    fi
}

backup "$HOME/.zshrc"
backup "$HOME/.zshenv"
backup "$HOME/.zprofile"
backup "$HOME/.bashrc"
backup "$HOME/.bash_profile"
backup "$HOME/.vimrc"
backup "$HOME/.config/nvim/init.lua"
backup "$HOME/.config/ghostty/config"
backup "$HOME/.config/shell/aliases"
backup "$HOME/.config/shell/functions"
backup "$HOME/.config/shell/profile"
backup "$HOME/.config/git/config"
backup "$HOME/.config/git/ignore"
backup "$HOME/.config/tmux/tmux.conf"
backup "$HOME/.tmux.conf"

# Backup obs-* scripts (stow manages these now)
for f in "$HOME"/.local/bin/obs-*; do
    backup "$f"
done
# Stow
DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DOTFILES_DIR"
stow .

echo "Dotfiles installed!"

# macOS-specific setup
if [ "$OS" = "Darwin" ]; then
    sh "$DOTFILES_DIR/bootstrap/macos.sh"
fi
