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
CMAKE_VERSION="3.31.6"
NVIM_MIN_VERSION="0.10.0"
NODE_MIN_VERSION="18.0.0"
TRY_VERSION="1.5.3"
GLOW_VERSION="2.1.2"
TREE_SITTER_VERSION="0.26.8"
LIBEVENT_VERSION="2.1.12-stable"
TMUX_VERSION="3.5a"

# --- Platform ---
case "$OS/$ARCH" in
    Linux/x86_64)  fzf_arch="linux_amd64";  rg_target="x86_64-unknown-linux-musl"; nvim_platform="linux-x86_64"; bw_platform="linux"; node_platform="linux-x64";   tree_sitter_asset="tree-sitter-cli-linux-x64.zip" ;;
    Linux/aarch64) fzf_arch="linux_arm64";  rg_target="aarch64-unknown-linux-gnu"; nvim_platform="linux-arm64";  bw_platform="linux"; node_platform="linux-arm64"; tree_sitter_asset="tree-sitter-cli-linux-arm64.zip" ;;
    Darwin/x86_64) fzf_arch="darwin_amd64"; rg_target="x86_64-apple-darwin";       nvim_platform="macos-x86_64"; bw_platform="macos"; node_platform="darwin-x64";  tree_sitter_asset="tree-sitter-cli-macos-x64.zip" ;;
    Darwin/arm64)  fzf_arch="darwin_arm64"; rg_target="aarch64-apple-darwin";      nvim_platform="macos-arm64";  bw_platform="macos"; node_platform="darwin-arm64"; tree_sitter_asset="tree-sitter-cli-macos-arm64.zip" ;;
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
      tar xzf "$tmp/fzf.tar.gz" -C "$BIN" )
    echo "  → fzf ${FZF_VERSION}"
fi

# ripgrep — single binary inside a directory
if ! command -v rg >/dev/null 2>&1; then
    echo "Installing ripgrep ${RG_VERSION}..."
    ( tmp=$(mktemp -d) && trap "rm -rf '$tmp'" EXIT
      fetch "https://github.com/BurntSushi/ripgrep/releases/download/${RG_VERSION}/ripgrep-${RG_VERSION}-${rg_target}.tar.gz" "$tmp/rg.tar.gz"
      tar xzf "$tmp/rg.tar.gz" -C "$tmp"
      cp "$tmp"/ripgrep-*/rg "$BIN/" )
    echo "  → ripgrep ${RG_VERSION}"
fi

# glow — static Go binary, works on any glibc
if ! command -v glow >/dev/null 2>&1; then
    glow_arch="$ARCH"; [ "$glow_arch" = "aarch64" ] && glow_arch="arm64"
    echo "Installing glow ${GLOW_VERSION}..."
    ( tmp=$(mktemp -d) && trap "rm -rf '$tmp'" EXIT
      fetch "https://github.com/charmbracelet/glow/releases/download/v${GLOW_VERSION}/glow_${GLOW_VERSION}_${OS}_${glow_arch}.tar.gz" "$tmp/glow.tar.gz"
      tar xzf "$tmp/glow.tar.gz" -C "$tmp"
      cp "$tmp"/glow_*/glow "$BIN/" || cp "$tmp/glow" "$BIN/"
      chmod +x "$BIN/glow" )
    echo "  → glow ${GLOW_VERSION}"
fi

# Rust toolchain — needed for source-building tree-sitter-cli on Linux
if ! command -v cargo >/dev/null 2>&1 || ! command -v rustc >/dev/null 2>&1; then
    echo "Installing Rust (stable, minimal profile)..."
    ( tmp=$(mktemp -d) && trap "rm -rf '$tmp'" EXIT
      fetch "https://sh.rustup.rs" "$tmp/rustup-init.sh"
      sh "$tmp/rustup-init.sh" -y --profile minimal --default-toolchain stable --no-modify-path >/dev/null )
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
    echo "  → cargo $(cargo --version)"
    echo "  → rustc $(rustc --version)"
fi

# cmake — prebuilt binary, needed for building neovim on Linux
if [ "$OS" = "Linux" ] && ! command -v cmake >/dev/null 2>&1; then
    echo "Installing cmake ${CMAKE_VERSION}..."
    ( tmp=$(mktemp -d) && trap "rm -rf '$tmp'" EXIT
      fetch "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-${ARCH}.tar.gz" "$tmp/cmake.tar.gz"
      rm -rf "$LOCAL/cmake"
      mkdir -p "$LOCAL/cmake"
      tar xzf "$tmp/cmake.tar.gz" -C "$LOCAL/cmake" --strip-components=1 )
    ln -sf "$LOCAL/cmake/bin/cmake" "$BIN/cmake"
    echo "  → cmake ${CMAKE_VERSION}"
fi

# neovim — build from source on Linux (prebuilt binaries need glibc 2.34+), tarball on macOS
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
    rm -rf "$LOCAL/nvim"
    # Clear stale plugin cache — old plugins break across major nvim versions
    rm -rf "$HOME/.local/share/nvim/lazy" "$HOME/.local/state/nvim/lazy"
    if [ "$OS" = "Linux" ]; then
        # Prebuilt binaries need glibc 2.34+; build from source for portability
        # Requires: git, cmake, make, gcc, g++
        tmp=$(mktemp -d)
        git clone --depth 1 --branch stable https://github.com/neovim/neovim.git "$tmp/neovim"
        make -C "$tmp/neovim" CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="$LOCAL/nvim" -j"$(nproc 2>/dev/null || echo 2)"
        make -C "$tmp/neovim" CMAKE_INSTALL_PREFIX="$LOCAL/nvim" install
        rm -rf "$tmp"
        ln -sf "$LOCAL/nvim/bin/nvim" "$BIN/nvim"
    else
        ( tmp=$(mktemp -d) && trap "rm -rf '$tmp'" EXIT
          fetch "https://github.com/neovim/neovim/releases/latest/download/nvim-${nvim_platform}.tar.gz" "$tmp/nvim.tar.gz"
          mkdir -p "$LOCAL/nvim"
          tar xzf "$tmp/nvim.tar.gz" -C "$LOCAL/nvim" --strip-components=1 )
        ln -sf "$LOCAL/nvim/bin/nvim" "$BIN/nvim"
    fi
    # Verify it actually runs (no pipe — set -e catches failure)
    "$BIN/nvim" --version > /dev/null 2>&1
    echo "  → nvim $("$BIN/nvim" --version | head -n 1)"
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
    )
    echo "  → bw"
fi

# tmux — build locally on Linux if missing
tmux_path="$(command -v tmux 2>/dev/null || true)"
if [ -z "$tmux_path" ]; then
    if [ "$OS" = "Darwin" ]; then
        echo ""
        echo "tmux not found (optional — needed for remarimo)."
        echo "  Install: brew install tmux"
    else
        echo "Installing libevent ${LIBEVENT_VERSION} for local tmux build..."
        ( tmp=$(mktemp -d) && trap "rm -rf '$tmp'" EXIT
          fetch "https://github.com/libevent/libevent/releases/download/release-${LIBEVENT_VERSION}/libevent-${LIBEVENT_VERSION}.tar.gz" "$tmp/libevent.tar.gz"
          tar xzf "$tmp/libevent.tar.gz" -C "$tmp"
          cd "$tmp/libevent-${LIBEVENT_VERSION}"
          ./configure --prefix="$LOCAL" >/dev/null
          make -j"$(nproc 2>/dev/null || echo 2)" >/dev/null
          make install >/dev/null )

        echo "Installing tmux ${TMUX_VERSION}..."
        ( tmp=$(mktemp -d) && trap "rm -rf '$tmp'" EXIT
          fetch "https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz" "$tmp/tmux.tar.gz"
          tar xzf "$tmp/tmux.tar.gz" -C "$tmp"
          cd "$tmp/tmux-${TMUX_VERSION}"
          export PKG_CONFIG_PATH="$LOCAL/lib/pkgconfig:$LOCAL/lib64/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
          export CPPFLAGS="-I$LOCAL/include${CPPFLAGS:+ $CPPFLAGS}"
          export LDFLAGS="-L$LOCAL/lib -L$LOCAL/lib64${LDFLAGS:+ $LDFLAGS}"
          ./configure --prefix="$LOCAL" >/dev/null
          make -j"$(nproc 2>/dev/null || echo 2)" >/dev/null
          make install >/dev/null )
        echo "  → tmux $("$BIN/tmux" -V)"
    fi
elif [ "${tmux_path#"$HOME/miniconda3/"}" != "$tmux_path" ]; then
    echo "tmux $(tmux -V) found at $tmux_path"
    echo "  Note: this tmux comes from miniconda and will disappear if miniconda is removed."
else
    echo "tmux $(tmux -V) found — 3.2+ recommended for full config support."
fi

# node — prebuilt tarball to ~/.local/node, symlinked into bin
install_node=false
if ! command -v node >/dev/null 2>&1; then
    install_node=true
else
    node_ver="$(node --version | sed 's/^v//')"
    if ! version_ge "$node_ver" "$NODE_MIN_VERSION"; then
        echo "node $node_ver found but ${NODE_MIN_VERSION}+ required"
        install_node=true
    fi
fi
if [ "$install_node" = true ]; then
    echo "Installing node ${NODE_VERSION}..."
    rm -rf "$LOCAL/node"
    ( tmp=$(mktemp -d) && trap "rm -rf '$tmp'" EXIT
      fetch "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-${node_platform}.tar.gz" "$tmp/node.tar.gz"
      mkdir -p "$LOCAL/node"
      tar xzf "$tmp/node.tar.gz" -C "$LOCAL/node" --strip-components=1 )
    ln -sf "$LOCAL/node/bin/node" "$BIN/node"
    ln -sf "$LOCAL/node/bin/npm" "$BIN/npm"
    ln -sf "$LOCAL/node/bin/npx" "$BIN/npx"
    echo "  → node $("$BIN/node" --version)"
fi

# claude-code — standalone installer (no Node required)
if ! command -v claude >/dev/null 2>&1; then
    echo "Installing claude-code..."
    ( tmp=$(mktemp -d) && trap "rm -rf '$tmp'" EXIT
      fetch "https://claude.ai/install.sh" "$tmp/install.sh"
      bash "$tmp/install.sh" )
    echo "  → claude"
fi

# codex — npm global (--prefix ensures binaries go to ~/.local/bin)
if ! command -v codex >/dev/null 2>&1; then
    echo "Installing codex..."
    "$BIN/npm" install -g --prefix="$LOCAL" @openai/codex
fi

# pi — npm global
if ! command -v pi >/dev/null 2>&1; then
    echo "Installing pi..."
    "$BIN/npm" install -g --prefix="$LOCAL" @mariozechner/pi-coding-agent
fi

# tree-sitter — needed by nvim-treesitter to compile parsers
if ! command -v tree-sitter >/dev/null 2>&1 || ! tree-sitter --version >/dev/null 2>&1; then
    # Remove stale or incompatible local binary before retrying.
    [ -e "$BIN/tree-sitter" ] && rm -f "$BIN/tree-sitter"
    echo "Installing tree-sitter-cli ${TREE_SITTER_VERSION}..."
    if [ "$OS" = "Linux" ] && command -v cargo >/dev/null 2>&1; then
        if cargo install \
            --root="$LOCAL" \
            --force \
            --locked \
            tree-sitter-cli \
            --version "$TREE_SITTER_VERSION" \
            --no-default-features; then
            echo "  → tree-sitter $(tree-sitter --version)"
        else
            echo "  Skipped: cargo build of tree-sitter-cli failed" >&2
        fi
    elif ( tmp=$(mktemp -d) && trap "rm -rf '$tmp'" EXIT
        fetch "https://github.com/tree-sitter/tree-sitter/releases/download/v${TREE_SITTER_VERSION}/${tree_sitter_asset}" "$tmp/tree-sitter.zip"
        if command -v unzip >/dev/null 2>&1; then
            unzip -o "$tmp/tree-sitter.zip" -d "$tmp/tree-sitter-out" >/dev/null
        elif command -v python3 >/dev/null 2>&1; then
            python3 -c "import zipfile; zipfile.ZipFile('$tmp/tree-sitter.zip').extractall('$tmp/tree-sitter-out')"
        else
            echo "  Skipped: need unzip or python3 to extract tree-sitter-cli" >&2
            exit 1
        fi
        if "$tmp/tree-sitter-out/tree-sitter" --version >/dev/null 2>&1; then
            cp "$tmp/tree-sitter-out/tree-sitter" "$BIN/"
            chmod +x "$BIN/tree-sitter"
        else
            echo "  Skipped: prebuilt tree-sitter-cli is incompatible on this system" >&2
            exit 1
        fi ); then
        echo "  → tree-sitter $(tree-sitter --version)"
    fi
fi

# try-cli — build from source (prebuilt binaries are Nix-linked, not portable)
if ! command -v try >/dev/null 2>&1; then
    echo "Installing try-cli ${TRY_VERSION}..."
    tmp=$(mktemp -d)
    fetch "https://github.com/tobi/try-cli/archive/refs/tags/v${TRY_VERSION}.tar.gz" "$tmp/try-src.tar.gz"
    tar xzf "$tmp/try-src.tar.gz" -C "$tmp"
    make -C "$tmp/try-cli-${TRY_VERSION}" -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu)"
    cp "$tmp/try-cli-${TRY_VERSION}/dist/try" "$BIN/"
    chmod +x "$BIN/try"
    rm -rf "$tmp"
    echo "  → try ${TRY_VERSION}"
fi

# --- Config ---

# Pick up any existing vault paths so re-runs don't clobber them
[ -f "$HOME/.dotfiles.local" ] && . "$HOME/.dotfiles.local"

lab_default="${LAB_VAULT:-}"
[ -z "$lab_default" ] && [ -d "$HOME/Documents/lab" ] && lab_default="$HOME/Documents/lab"
life_default="${LIFE_VAULT:-}"
[ -z "$life_default" ] && [ -d "$HOME/Documents/life" ] && life_default="$HOME/Documents/life"

# Ask for vault paths (enter keeps the current/default value)
if [ -t 0 ]; then
    printf 'Lab vault path? [%s] (enter to keep): ' "${lab_default:-skip}"
    read -r lab_input
    lab_vault="${lab_input:-$lab_default}"
    printf 'Life vault path? [%s] (enter to keep): ' "${life_default:-skip}"
    read -r life_input
    life_vault="${life_input:-$life_default}"
else
    lab_vault="$lab_default"
    life_vault="$life_default"
fi

# Write local config
mkdir -p "$HOME/.local/state"
cat > "$HOME/.dotfiles.local" << EOF
# Machine-local dotfiles config
EOF
[ -n "$lab_vault" ]  && echo "export LAB_VAULT=\"$lab_vault\""   >> "$HOME/.dotfiles.local"
[ -n "$life_vault" ] && echo "export LIFE_VAULT=\"$life_vault\"" >> "$HOME/.dotfiles.local"

# Pi auth (command-based secret resolution, no keys on disk)
mkdir -p "$HOME/.pi/agent"
cat > "$HOME/.pi/agent/auth.json" << 'EOF'
{
  "openai": { "type": "api_key", "key": "!bw get password OPENAI_API_KEY" },
  "xai":    { "type": "api_key", "key": "!bw get password XAI_API_KEY" }
}
EOF
chmod 600 "$HOME/.pi/agent/auth.json"

# Pi extension: expose PI_SESSION_ID to child processes.
mkdir -p "$HOME/.pi/extensions"
cat > "$HOME/.pi/extensions/session-env.ts" << 'EOF'
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
    pi.on("session_start", async (_event, ctx) => {
        process.env.PI_SESSION_ID = ctx.sessionManager.getSessionId();
    });
}
EOF

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
backup "$HOME/.inputrc"
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
git -C "$DOTFILES_DIR" update-index --skip-worktree .config/nvim/lazy-lock.json

echo "Dotfiles installed!"

# macOS-specific setup
if [ "$OS" = "Darwin" ]; then
    sh "$DOTFILES_DIR/bootstrap/macos.sh"
fi
