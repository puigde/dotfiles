#!/bin/sh
set -e

OS="$(uname -s)"
ARCH="$(uname -m)"
echo "Detected: $OS/$ARCH"

LOCAL="$HOME/.local"
BIN="$LOCAL/bin"
mkdir -p "$BIN"

# Ensure ~/.local/bin is in PATH for this session
case ":$PATH:" in *":$BIN:"*) ;; *) export PATH="$BIN:$PATH" ;; esac

# --- Pinned versions (update as needed) ---
STOW_VERSION="2.4.1"
FZF_VERSION="0.71.0"
RG_VERSION="15.1.0"
NODE_VERSION="22.15.0"
NVIM_MIN_VERSION="0.10.0"

# --- Platform ---
case "$OS/$ARCH" in
    Linux/x86_64)  fzf_arch="linux_amd64"  rg_target="x86_64-unknown-linux-musl"  nvim_platform="linux-x86_64"  bw_platform="linux"  node_platform="linux-x64"   ;;
    Linux/aarch64) fzf_arch="linux_arm64"   rg_target="aarch64-unknown-linux-gnu"  nvim_platform="linux-arm64"   bw_platform="linux"  node_platform="linux-arm64" ;;
    Darwin/x86_64) fzf_arch="darwin_amd64"  rg_target="x86_64-apple-darwin"        nvim_platform="macos-x86_64"  bw_platform="macos"  node_platform="darwin-x64"  ;;
    Darwin/arm64)  fzf_arch="darwin_arm64"  rg_target="aarch64-apple-darwin"       nvim_platform="macos-arm64"   bw_platform="macos"  node_platform="darwin-arm64" ;;
    *) echo "Unsupported: $OS/$ARCH"; exit 1 ;;
esac

# --- Helpers ---
fetch() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$2" "$1"
    else
        echo "Error: curl or wget required" >&2
        exit 1
    fi
}

# version_ge "0.8.0" "0.10.0" → false (returns 1 if $1 < $2)
version_ge() {
    [ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n 1)" = "$2" ]
}

# --- Tools (all go to ~/.local, no sudo needed) ---

# stow — Perl script, build from GNU tarball (critical — failure aborts)
if ! command -v stow >/dev/null 2>&1; then
    echo "Installing stow ${STOW_VERSION}..."
    ( tmp=$(mktemp -d) && trap "rm -rf '$tmp'" EXIT
      fetch "https://ftp.gnu.org/gnu/stow/stow-${STOW_VERSION}.tar.gz" "$tmp/stow.tar.gz"
      tar xzf "$tmp/stow.tar.gz" -C "$tmp"
      cd "$tmp/stow-${STOW_VERSION}"
      ./configure --prefix="$LOCAL" >/dev/null
      make install >/dev/null 2>&1 )
    echo "  → stow ${STOW_VERSION}"
fi

# fzf — single binary
if ! command -v fzf >/dev/null 2>&1; then
    echo "Installing fzf ${FZF_VERSION}..."
    ( tmp=$(mktemp -d) && trap "rm -rf '$tmp'" EXIT
      fetch "https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-${fzf_arch}.tar.gz" "$tmp/fzf.tar.gz"
      tar xzf "$tmp/fzf.tar.gz" -C "$BIN"
    ) || { echo "  Warning: fzf install failed, skipping"; }
    echo "  → fzf ${FZF_VERSION}"
fi

# ripgrep — single binary inside a directory
if ! command -v rg >/dev/null 2>&1; then
    echo "Installing ripgrep ${RG_VERSION}..."
    ( tmp=$(mktemp -d) && trap "rm -rf '$tmp'" EXIT
      fetch "https://github.com/BurntSushi/ripgrep/releases/download/${RG_VERSION}/ripgrep-${RG_VERSION}-${rg_target}.tar.gz" "$tmp/rg.tar.gz"
      tar xzf "$tmp/rg.tar.gz" -C "$tmp"
      cp "$tmp"/ripgrep-*/rg "$BIN/"
    ) || { echo "  Warning: ripgrep install failed, skipping"; }
    echo "  → ripgrep ${RG_VERSION}"
fi

# neovim — isolated prefix at ~/.local/nvim, symlinked into bin
install_nvim=false
if ! command -v nvim >/dev/null 2>&1; then
    install_nvim=true
else
    nvim_ver="$(nvim --version | head -n 1 | sed 's/[^0-9]*\([0-9][0-9.]*\).*/\1/')"
    if ! version_ge "$nvim_ver" "$NVIM_MIN_VERSION"; then
        echo "nvim $nvim_ver found but ${NVIM_MIN_VERSION}+ required (treesitter, etc.)"
        install_nvim=true
    fi
fi
if [ "$install_nvim" = true ]; then
    echo "Installing neovim (latest stable)..."
    ( tmp=$(mktemp -d) && trap "rm -rf '$tmp'" EXIT
      fetch "https://github.com/neovim/neovim/releases/latest/download/nvim-${nvim_platform}.tar.gz" "$tmp/nvim.tar.gz"
      rm -rf "$LOCAL/nvim"
      mkdir -p "$LOCAL/nvim"
      tar xzf "$tmp/nvim.tar.gz" -C "$LOCAL/nvim" --strip-components=1 )
    ln -sf "$LOCAL/nvim/bin/nvim" "$BIN/nvim"
    echo "  → nvim $(nvim --version | head -n 1)"
fi

# bitwarden-cli — single binary in a zip
if ! command -v bw >/dev/null 2>&1; then
    echo "Installing bitwarden-cli..."
    ( tmp=$(mktemp -d) && trap "rm -rf '$tmp'" EXIT
      fetch "https://vault.bitwarden.com/download/?app=cli&platform=${bw_platform}" "$tmp/bw.zip"
      if command -v unzip >/dev/null 2>&1; then
          unzip -o "$tmp/bw.zip" -d "$tmp/bw-out" >/dev/null
      elif command -v python3 >/dev/null 2>&1; then
          python3 -c "import zipfile; zipfile.ZipFile('$tmp/bw.zip').extractall('$tmp/bw-out')"
      else
          echo "  Skipped: need unzip or python3 to extract" >&2
          exit 1
      fi
      cp "$tmp/bw-out/bw" "$BIN/"
      chmod +x "$BIN/bw"
    ) || { echo "  Warning: bitwarden-cli install failed, skipping"; }
    [ -x "$BIN/bw" ] && echo "  → bw"
fi

# tmux — needs system libraries, just advise
if ! command -v tmux >/dev/null 2>&1; then
    echo ""
    echo "tmux not found (optional — needed for remarimo)."
    if [ "$OS" = "Darwin" ]; then
        echo "  Install: brew install tmux"
    else
        echo "  Install: sudo apt install tmux  (or ask sysadmin)"
    fi
else
    echo "tmux $(tmux -V) found — 3.2+ recommended for full config support."
fi

# node — prebuilt tarball to ~/.local/node, symlinked into bin
if ! command -v node >/dev/null 2>&1; then
    echo "Installing node ${NODE_VERSION}..."
    ( tmp=$(mktemp -d) && trap "rm -rf '$tmp'" EXIT
      fetch "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-${node_platform}.tar.gz" "$tmp/node.tar.gz"
      mkdir -p "$LOCAL/node"
      tar xzf "$tmp/node.tar.gz" -C "$LOCAL/node" --strip-components=1 )
    ln -sf "$LOCAL/node/bin/node" "$BIN/node"
    ln -sf "$LOCAL/node/bin/npm" "$BIN/npm"
    ln -sf "$LOCAL/node/bin/npx" "$BIN/npx"
    echo "  → node $(node --version)"
fi

# claude-code — standalone installer (no Node required)
if ! command -v claude >/dev/null 2>&1; then
    echo "Installing claude-code..."
    ( tmp=$(mktemp -d) && trap "rm -rf '$tmp'" EXIT
      fetch "https://claude.ai/install.sh" "$tmp/install.sh"
      bash "$tmp/install.sh" ) || { echo "  Warning: claude-code install failed, skipping"; }
    command -v claude >/dev/null 2>&1 && echo "  → claude $(claude --version 2>/dev/null || echo '(installed)')"
fi

# codex — npm global
if ! command -v codex >/dev/null 2>&1; then
    echo "Installing codex..."
    npm install -g @openai/codex 2>/dev/null || { echo "  Warning: codex install failed, skipping"; }
fi

# pi — npm global
if ! command -v pi >/dev/null 2>&1; then
    echo "Installing pi..."
    npm install -g @mariozechner/pi-coding-agent 2>/dev/null || { echo "  Warning: pi install failed, skipping"; }
fi

# Ruby/try-cli (macOS only, needs Homebrew Ruby)
if [ "$OS" = "Darwin" ] && [ -x /opt/homebrew/opt/ruby/bin/gem ]; then
    /opt/homebrew/opt/ruby/bin/gem install try-cli </dev/null 2>/dev/null || true
fi

# --- Config ---

# Ask for vault paths
printf 'Lab vault path? [~/Documents/lab] (enter to skip): '
read -r lab_vault
printf 'Life vault path? [~/Documents/life] (enter to skip): '
read -r life_vault

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

# Pi auth (command-based secret resolution, no keys on disk)
mkdir -p "$HOME/.pi/agent"
cat > "$HOME/.pi/agent/auth.json" << 'EOF'
{
  "openai": { "type": "api_key", "key": "!bw get password OPENAI_API_KEY" }
}
EOF
chmod 600 "$HOME/.pi/agent/auth.json"

# --- Backup conflicting files ---
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d)"
backup() {
    # Skip if file doesn't exist, is a symlink, or is inside a symlinked parent (stow-managed)
    if [ -e "$1" ] && [ ! -L "$1" ]; then
        local dir="$1"
        local inside_symlink=false
        while dir="$(dirname "$dir")" && [ "$dir" != "$HOME" ] && [ "$dir" != "/" ]; do
            if [ -L "$dir" ]; then inside_symlink=true; break; fi
        done
        if [ "$inside_symlink" = false ]; then
            mkdir -p "$BACKUP_DIR"
            echo "Backing up $1 → $BACKUP_DIR/"
            mv "$1" "$BACKUP_DIR/"
        fi
    fi
}

backup "$HOME/.zshrc"
backup "$HOME/.zshenv"
backup "$HOME/.zprofile"
backup "$HOME/.bashrc"
backup "$HOME/.bash_profile"
backup "$HOME/.vimrc"
backup "$HOME/.config/nvim/init.lua"
backup "$HOME/.config/nvim/lazy-lock.json"
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

# Skip local-only changes for machine-specific configs
git -C "$DOTFILES_DIR" update-index --skip-worktree .config/ghostty/config

echo "Dotfiles installed!"

# macOS-specific setup
if [ "$OS" = "Darwin" ]; then
    sh "$DOTFILES_DIR/bootstrap/macos.sh"
fi
