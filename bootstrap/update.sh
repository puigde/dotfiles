#!/bin/sh
set -e
cd "$(cd "$(dirname "$0")/.." && pwd)"

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Error: uncommitted changes in dotfiles repo. Commit or stash first."
    exit 1
fi

git pull
stow -R . -t ~
nvim --headless "+Lazy! update" +qa
echo "Dotfiles updated!"
