#!/bin/sh
# macOS-specific setup
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
echo "macOS: disabled press-and-hold for key repeat"
