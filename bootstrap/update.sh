#!/bin/sh
set -e
cd "$(cd "$(dirname "$0")/.." && pwd)"

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Error: uncommitted changes in dotfiles repo. Commit or stash first."
    exit 1
fi

git pull
stow -R . -t ~
command -v nvim >/dev/null 2>&1 && nvim --headless "+Lazy! update" +qa
echo "Dotfiles updated!"
