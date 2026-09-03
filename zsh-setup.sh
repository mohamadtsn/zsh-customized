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
    -u|--update)
      # Re-run / update mode: all tasks are idempotent and will sync updates
      shift 1
      ;;
    -h|--help)
      echo "Usage: ./zsh-setup.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  -u, --update           Re-run script to update plugins, configs, and shell environment."
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
step "1. Checking & Installing System Packages"
NEEDED_PKGS=()
for cmd in zsh git curl wget unzip fzf; do
  if ! command -v "$cmd" &>/dev/null; then
    NEEDED_PKGS+=("$cmd")
  fi
done

# Check bat / batcat
if ! command -v bat &>/dev/null && ! command -v batcat &>/dev/null; then
  NEEDED_PKGS+=("bat")
fi

# Check fd / fdfind
if ! command -v fd &>/dev/null && ! command -v fdfind &>/dev/null; then
  NEEDED_PKGS+=("fd-find")
fi

# Check eza
if ! command -v eza &>/dev/null; then
  NEEDED_PKGS+=("eza")
fi

if [ ${#NEEDED_PKGS[@]} -eq 0 ]; then
  ok "All core CLI tools and packages already installed"
else
  if command -v apt-get &>/dev/null; then
    if [ -w /var/lib/dpkg/lock-frontend ] || [ "$EUID" -eq 0 ] || command -v sudo &>/dev/null; then
      SUDO_CMD=""
      [ "$EUID" -ne 0 ] && command -v sudo &>/dev/null && SUDO_CMD="sudo"
      
      warn "Missing packages detected: ${NEEDED_PKGS[*]}"
      $SUDO_CMD apt-get update -q || warn "apt-get update failed, trying to proceed with existing packages..."
      $SUDO_CMD apt-get install -y -q "${NEEDED_PKGS[@]}" build-essential || warn "Some packages failed to install via apt-get."
    else
      warn "Missing packages (${NEEDED_PKGS[*]}), but insufficient privileges to run apt-get."
    fi
  else
    warn "apt-get not found. Ensure missing packages are installed: ${NEEDED_PKGS[*]}"
  fi
fi

# Fix fd & bat aliases/symlinks on Ubuntu/Debian
if ! command -v fd &>/dev/null && command -v fdfind &>/dev/null; then
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
  ok "Created symlink for fd -> fdfind"
elif command -v fd &>/dev/null; then
  ok "fd is available"
fi

if ! command -v bat &>/dev/null && command -v batcat &>/dev/null; then
  ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
  ok "Created symlink for bat -> batcat"
elif command -v bat &>/dev/null; then
  ok "bat is available"
fi

# 2. Install Starship Prompt
step "2. Installing / Verifying Starship Prompt"
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
  ok "Starship already installed ($(starship --version 2>/dev/null | head -n1))"
fi

# 3. Install Oh My Zsh
step "3. Installing / Updating Oh My Zsh"
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
  if [ -d "$HOME/.oh-my-zsh/.git" ] && [ -z "$OFFLINE_DIR" ] && [ -z "$MIRROR_URL" ]; then
    git -C "$HOME/.oh-my-zsh" pull --quiet 2>/dev/null || true
    ok "Oh My Zsh already installed (updated to latest git)"
  else
    ok "Oh My Zsh already installed"
  fi
fi

# 4. Install Custom Plugins for Oh My Zsh
step "4. Installing / Updating Custom OMZ Plugins"
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
    if [ -d "$target_dir/.git" ] && [ -z "$OFFLINE_DIR" ] && [ -z "$MIRROR_URL" ]; then
      git -C "$target_dir" pull --quiet 2>/dev/null || true
      ok "Plugin $p_name is up to date"
    else
      ok "Plugin $p_name already present"
    fi
  fi
done

# 5. Deploy Custom .zshrc
step "5. Deploying / Updating Custom .zshrc"
if [ -f "$SCRIPT_DIR/.zshrc" ]; then
  if [ -f "$HOME/.zshrc" ]; then
    if cmp -s "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"; then
      ok "~/.zshrc is already up to date (no changes needed)"
    else
      BACKUP_FILE="$HOME/.zshrc.bak.$(date +%Y%m%d_%H%M%S)"
      cp "$HOME/.zshrc" "$BACKUP_FILE"
      cp "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
      ok "Updated ~/.zshrc (previous version backed up to $BACKUP_FILE)"
    fi
  else
    cp "$SCRIPT_DIR/.zshrc" "$HOME/.zshrc"
    ok "Custom .zshrc copied to $HOME/.zshrc"
  fi
fi

# 6. Set Zsh as default shell
step "6. Verifying Default Shell"
ZSH_BIN="$(command -v zsh || true)"
if [ -n "$ZSH_BIN" ]; then
  if [ "$SHELL" = "$ZSH_BIN" ]; then
    ok "Zsh is already default shell ($SHELL)"
  else
    CURRENT_USER="${USER:-$(id -un)}"
    if command -v sudo &>/dev/null && [ "$EUID" -ne 0 ]; then
      sudo chsh -s "$ZSH_BIN" "$CURRENT_USER" 2>/dev/null || chsh -s "$ZSH_BIN" || true
    else
      chsh -s "$ZSH_BIN" 2>/dev/null || true
    fi
    ok "Default shell updated to Zsh ($ZSH_BIN)"
  fi
else
  warn "Zsh binary not found in PATH"
fi

# 7. Migrate Previous Shell History & Environment (.profile)
step "7. Migrating Previous Shell History & Environment"

# 7.1 Environment & Profile Migration
ZPROFILE="$HOME/.zprofile"
PROFILE_TARGET=""
if [ -f "$HOME/.profile" ]; then
  PROFILE_TARGET="$HOME/.profile"
elif [ -f "$HOME/.bash_profile" ]; then
  PROFILE_TARGET="$HOME/.bash_profile"
fi

if [ -n "$PROFILE_TARGET" ]; then
  if [ ! -f "$ZPROFILE" ]; then
    cat << 'EOF' > "$ZPROFILE"
# Source shell profile for environment variables & PATH compatibility
if [ -f "$HOME/.profile" ]; then
  emulate sh -c 'source "$HOME/.profile"'
elif [ -f "$HOME/.bash_profile" ]; then
  emulate sh -c 'source "$HOME/.bash_profile"'
fi
EOF
    ok "Created ~/.zprofile sourcing $(basename "$PROFILE_TARGET")"
  elif ! grep -qE 'source.*(\.profile|\.bash_profile)' "$ZPROFILE" 2>/dev/null; then
    cat << 'EOF' >> "$ZPROFILE"

# Source shell profile for environment variables & PATH compatibility
if [ -f "$HOME/.profile" ]; then
  emulate sh -c 'source "$HOME/.profile"'
elif [ -f "$HOME/.bash_profile" ]; then
  emulate sh -c 'source "$HOME/.bash_profile"'
fi
EOF
    ok "Added profile sourcing to existing ~/.zprofile"
  else
    ok "~/.zprofile already configured to source profile (skipped)"
  fi
else
  ok "No previous ~/.profile or ~/.bash_profile found"
fi

# 7.2 Shell History Migration
HIST_SOURCES=()
for h_file in "$HOME/.bash_history" "$HOME/.sh_history" "$HOME/.zhistory"; do
  [ -f "$h_file" ] && [ -s "$h_file" ] && HIST_SOURCES+=("$h_file")
done

if [ ${#HIST_SOURCES[@]} -gt 0 ]; then
  TMP_CONV="$(mktemp)"
  TMP_MERGED="$(mktemp)"
  
  # Format each history file into Zsh EXTENDED_HISTORY format
  for src in "${HIST_SOURCES[@]}"; do
    tr -d '\000' < "$src" | awk '
      BEGIN { ts = 0 }
      /^#[0-9]{9,12}$/ {
        sub(/^#/, "", $0);
        ts = $0;
        next;
      }
      {
        if (/^: [0-9]+:[0-9]+;/) {
          print $0;
        } else if (NF > 0) {
          if (ts > 0) {
            print ": " ts ":0;" $0;
            ts = 0;
          } else {
            print ": 0:0;" $0;
          }
        }
      }
    ' >> "$TMP_CONV"
  done
  
  EXISTING_COUNT=0
  if [ -f "$HOME/.zsh_history" ] && [ -s "$HOME/.zsh_history" ]; then
    EXISTING_COUNT=$(wc -l < "$HOME/.zsh_history" 2>/dev/null || echo 0)
    # Merge: legacy history first (chronologically older), then existing zsh history
    cat "$TMP_CONV" "$HOME/.zsh_history" | awk '!seen[$0]++' > "$TMP_MERGED"
  else
    awk '!seen[$0]++' "$TMP_CONV" > "$TMP_MERGED"
  fi
  
  TOTAL_COUNT=$(wc -l < "$TMP_MERGED" 2>/dev/null || echo 0)
  NEW_ENTRIES=$((TOTAL_COUNT - EXISTING_COUNT))
  
  if [ "$NEW_ENTRIES" -gt 0 ]; then
    [ -f "$HOME/.zsh_history" ] && cp "$HOME/.zsh_history" "$HOME/.zsh_history.bak.$(date +%Y%m%d_%H%M%S)"
    mv "$TMP_MERGED" "$HOME/.zsh_history"
    chmod 600 "$HOME/.zsh_history"
    ok "Migrated $NEW_ENTRIES new history entries from previous shell(s) into ~/.zsh_history"
  else
    rm -f "$TMP_MERGED"
    ok "Shell history is already up to date (no new entries to migrate)"
  fi
  rm -f "$TMP_CONV"
else
  ok "No previous shell history files found to migrate"
fi

echo -e "\n${GREEN}${BOLD}✔ Setup Complete! Restart your terminal or run: zsh${RESET}"
