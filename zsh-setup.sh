#!/usr/bin/env bash
# =============================================================================
#  Oh My Zsh + Starship Bootstrap Script for Fresh System
#  Supports Online, HTTP Mirror, and Offline Local Install modes.
# =============================================================================
set -e

BOLD='\033[1m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'
step() { echo -e "\n${CYAN}${BOLD}▶ $1${RESET}"; }
ok()   { echo -e "${GREEN}✔ $1${RESET}"; }
warn() { echo -e "${YELLOW}⚠ $1${RESET}"; }
err()  { echo -e "${RED}✖ $1${RESET}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIRROR_URL=""
OFFLINE_DIR=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -m|--mirror)
      MIRROR_URL="${2%/}"
      shift 2
      ;;
    -o|--offline-dir)
      OFFLINE_DIR="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: ./zsh-setup.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  -m, --mirror URL       Use an HTTP mirror base URL for fetching resources."
      echo "                         Example: ./zsh-setup.sh --mirror http://192.168.1.10:8080"
      echo "  -o, --offline-dir DIR  Use a local offline directory containing pre-downloaded assets."
      echo "                         Example: ./zsh-setup.sh --offline-dir ./mirror_data"
      echo "  -h, --help             Show this help message."
      exit 0
      ;;
    *)
      err "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Ensure ~/.local/bin is in PATH
mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

# 1. Install System Dependencies & CLI tools
step "1. Installing System Packages"
if command -v apt-get &>/dev/null; then
  if [ -w /var/lib/dpkg/lock-frontend ] || [ "$EUID" -eq 0 ] || command -v sudo &>/dev/null; then
    SUDO_CMD=""
    [ "$EUID" -ne 0 ] && command -v sudo &>/dev/null && SUDO_CMD="sudo"
    
    $SUDO_CMD apt-get update -q || warn "apt-get update failed, trying to proceed with existing packages..."
    $SUDO_CMD apt-get install -y -q zsh git curl wget unzip fzf bat eza fd-find build-essential || warn "Some packages failed to install via apt-get."
  else
    warn "Skipping apt-get package installation: insufficient privileges."
  fi
else
  warn "apt-get not found. Ensure zsh, git, curl, fzf, etc. are installed."
fi

# Fix fd & bat aliases/symlinks on Ubuntu/Debian
if ! command -v fd &>/dev/null && command -v fdfind &>/dev/null; then
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
  ok "Created symlink for fd -> fdfind"
fi

if ! command -v bat &>/dev/null && command -v batcat &>/dev/null; then
  ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
  ok "Created symlink for bat -> batcat"
fi

ok "Dependencies setup verified"

# 2. Install Starship Prompt
step "2. Installing Starship Prompt"
if ! command -v starship &>/dev/null; then
  if [ -n "$OFFLINE_DIR" ] && [ -f "$OFFLINE_DIR/starship.tar.gz" ]; then
    tar -xzf "$OFFLINE_DIR/starship.tar.gz" -C "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin/starship"
    ok "Starship installed from offline directory"
  elif [ -n "$MIRROR_URL" ]; then
    curl -fsSL "$MIRROR_URL/starship.tar.gz" -o /tmp/starship.tar.gz
    tar -xzf /tmp/starship.tar.gz -C "$HOME/.local/bin/"
    rm -f /tmp/starship.tar.gz
    chmod +x "$HOME/.local/bin/starship"
    ok "Starship installed from HTTP mirror"
  else
    if command -v curl &>/dev/null; then
      curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"
      ok "Starship installed via official script"
    else
      warn "curl not found, skipping Starship installation."
    fi
  fi
else
  ok "Starship already installed"
fi

# 3. Install Oh My Zsh
step "3. Installing Oh My Zsh"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  if [ -n "$OFFLINE_DIR" ] && [ -f "$OFFLINE_DIR/ohmyzsh.tar.gz" ]; then
    tar -xzf "$OFFLINE_DIR/ohmyzsh.tar.gz" -C "$HOME"
    ok "Oh My Zsh extracted from offline archive"
  elif [ -n "$MIRROR_URL" ] && curl -fsSL "$MIRROR_URL/ohmyzsh.tar.gz" -o /tmp/ohmyzsh.tar.gz 2>/dev/null; then
    tar -xzf /tmp/ohmyzsh.tar.gz -C "$HOME"
    rm -f /tmp/ohmyzsh.tar.gz
    ok "Oh My Zsh installed from HTTP mirror archive"
  else
    SH_INSTALL_SCRIPT=""
    if [ -n "$MIRROR_URL" ]; then
      SH_INSTALL_SCRIPT="$(curl -fsSL "$MIRROR_URL/omz-install.sh" 2>/dev/null || true)"
    fi
    if [ -z "$SH_INSTALL_SCRIPT" ]; then
      SH_INSTALL_SCRIPT="$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi
    sh -c "$SH_INSTALL_SCRIPT" "" --unattended --keep-zshrc
    ok "Oh My Zsh installed"
  fi
else
  ok "Oh My Zsh already installed"
fi

# 4. Install Custom Plugins for Oh My Zsh
step "4. Installing Custom OMZ Plugins"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
mkdir -p "$ZSH_CUSTOM/plugins"

plugins_info=(
  "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions.git"
  "zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting.git"
  "zsh-completions|https://github.com/zsh-users/zsh-completions.git"
  "fzf-tab|https://github.com/Aloxaf/fzf-tab.git"
)

for item in "${plugins_info[@]}"; do
  IFS="|" read -r p_name p_repo <<< "$item"
  target_dir="$ZSH_CUSTOM/plugins/$p_name"
  
  if [ ! -d "$target_dir" ]; then
    if [ -n "$OFFLINE_DIR" ] && [ -f "$OFFLINE_DIR/plugins/$p_name.tar.gz" ]; then
      mkdir -p "$target_dir"
      tar -xzf "$OFFLINE_DIR/plugins/$p_name.tar.gz" -C "$target_dir" --strip-components=1
      ok "Plugin $p_name installed from offline archive"
    elif [ -n "$MIRROR_URL" ] && curl -fsSL "$MIRROR_URL/plugins/$p_name.tar.gz" -o "/tmp/$p_name.tar.gz" 2>/dev/null; then
      mkdir -p "$target_dir"
      tar -xzf "/tmp/$p_name.tar.gz" -C "$target_dir" --strip-components=1
      rm -f "/tmp/$p_name.tar.gz"
      ok "Plugin $p_name installed from HTTP mirror archive"
    else
      repo_url="$p_repo"
      if [ -n "$MIRROR_URL" ]; then
        repo_url="$MIRROR_URL/git/$p_name.git"
      fi
      git clone --depth 1 "$repo_url" "$target_dir" || warn "Failed to clone $p_name"
      ok "Plugin $p_name cloned"
    fi
  else
    ok "Plugin $p_name already present"
  fi
done

# 5. Deploy Custom .zshrc
step "5. Deploying Custom .zshrc"
if [ -f "$SCRIPT_DIR/.zshrc" ]; then
  if [ -f "$HOME/.zshrc" ] && ! cmp -s "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"; then
    BACKUP_FILE="$HOME/.zshrc.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$HOME/.zshrc" "$BACKUP_FILE"
    ok "Existing ~/.zshrc backed up to $BACKUP_FILE"
  fi
  cp "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
  ok "Custom .zshrc copied to $HOME/.zshrc"
fi

# 6. Set Zsh as default shell
step "6. Setting Zsh as Default Shell"
ZSH_BIN="$(command -v zsh || true)"
if [ -n "$ZSH_BIN" ] && [ "$SHELL" != "$ZSH_BIN" ]; then
  if command -v sudo &>/dev/null && [ "$EUID" -ne 0 ]; then
    sudo chsh -s "$ZSH_BIN" "$USER" 2>/dev/null || chsh -s "$ZSH_BIN" || true
  else
    chsh -s "$ZSH_BIN" 2>/dev/null || true
  fi
  
  if [ -f "$HOME/.bash_history" ] && [ ! -s "$HOME/.zsh_history" ]; then
    cat "$HOME/.bash_history" >> "$HOME/.zsh_history" 2>/dev/null || true
  fi
  ok "Default shell updated to Zsh"
else
  ok "Zsh is already default shell or couldn't be automatically changed"
fi

echo -e "\n${GREEN}${BOLD}✔ Setup Complete! Restart your terminal or run: zsh${RESET}"
