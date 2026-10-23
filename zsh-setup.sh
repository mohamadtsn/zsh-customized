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

if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  SCRIPT_DIR=""
fi
RAW_REPO_URL="https://raw.githubusercontent.com/mohamadtsn/zsh-customized/main"
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

# Check eza (available in apt on Ubuntu 24.04/26.04; handled via binary/exa fallback on 22.04)
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
      
      # Ensure universe repository is enabled on Ubuntu (required for bat, fd-find, fzf, eza)
      if command -v add-apt-repository &>/dev/null; then
        $SUDO_CMD add-apt-repository -y universe &>/dev/null || true
      fi

      $SUDO_CMD apt-get update -q || warn "apt-get update failed, trying to proceed with existing packages..."

      # Filter packages to only those present in apt repos to prevent missing packages (e.g. eza on 22.04) from breaking the whole install
      INSTALLABLE_PKGS=()
      for pkg in "${NEEDED_PKGS[@]}"; do
        if apt-cache show "$pkg" &>/dev/null; then
          INSTALLABLE_PKGS+=("$pkg")
        elif [ "$pkg" = "eza" ] && apt-cache show exa &>/dev/null; then
          # Ubuntu 22.04 fallback package
          INSTALLABLE_PKGS+=("exa")
        else
          warn "Package '$pkg' is not available in current apt repositories."
        fi
      done

      if [ ${#INSTALLABLE_PKGS[@]} -gt 0 ]; then
        warn "Installing available packages via apt: ${INSTALLABLE_PKGS[*]}"
        $SUDO_CMD apt-get install -y -q "${INSTALLABLE_PKGS[@]}" build-essential </dev/null || warn "Some packages failed to install via apt-get."
      fi
    else
      warn "Missing packages (${NEEDED_PKGS[*]}), but insufficient privileges to run apt-get."
    fi
  else
    warn "apt-get not found. Ensure missing packages are installed: ${NEEDED_PKGS[*]}"
  fi
fi

# Install / verify eza (handles Ubuntu 22.04 where eza is not in apt)
if ! command -v eza &>/dev/null; then
  if [ -n "$OFFLINE_DIR" ] && [ -f "$OFFLINE_DIR/eza.tar.gz" ]; then
    tar -xzf "$OFFLINE_DIR/eza.tar.gz" -C "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin/eza" 2>/dev/null || true
    ok "eza installed from offline directory"
  elif [ -n "$MIRROR_URL" ] && curl -fsSL "$MIRROR_URL/eza.tar.gz" -o /tmp/eza.tar.gz 2>/dev/null; then
    tar -xzf /tmp/eza.tar.gz -C "$HOME/.local/bin/"
    rm -f /tmp/eza.tar.gz
    chmod +x "$HOME/.local/bin/eza" 2>/dev/null || true
    ok "eza installed from HTTP mirror"
  else
    # Try downloading prebuilt binary from GitHub releases
    ARCH="$(uname -m)"
    EZA_ARCH=""
    case "$ARCH" in
      x86_64)  EZA_ARCH="x86_64-unknown-linux-gnu" ;;
      aarch64) EZA_ARCH="aarch64-unknown-linux-gnu" ;;
      armv7l)  EZA_ARCH="arm-unknown-linux-gnueabihf" ;;
    esac

    if [ -n "$EZA_ARCH" ] && command -v curl &>/dev/null; then
      EZA_URL="https://github.com/eza-community/eza/releases/latest/download/eza_${EZA_ARCH}.tar.gz"
      if curl -fsSL "$EZA_URL" -o /tmp/eza.tar.gz 2>/dev/null; then
        tar -xzf /tmp/eza.tar.gz -C "$HOME/.local/bin/" 2>/dev/null || true
        rm -f /tmp/eza.tar.gz
        chmod +x "$HOME/.local/bin/eza" 2>/dev/null || true
      fi
    fi
  fi
fi

# Fallback: symlink exa -> eza if eza binary is missing but exa is installed (Ubuntu 22.04)
if ! command -v eza &>/dev/null && command -v exa &>/dev/null; then
  ln -sf "$(command -v exa)" "$HOME/.local/bin/eza"
  ok "Created symlink for eza -> exa"
elif command -v eza &>/dev/null; then
  ok "eza is available"
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
      STARSHIP_INSTALL_SH="$(curl -fsSL https://starship.rs/install.sh)"
      sh -c "$STARSHIP_INSTALL_SH" -- --yes --bin-dir "$HOME/.local/bin" </dev/null
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
    sh -c "$SH_INSTALL_SCRIPT" "" --unattended --keep-zshrc </dev/null
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
ZSHRC_SOURCE=""
TMP_ZSHRC=""

if [ -n "$OFFLINE_DIR" ] && [ -s "$OFFLINE_DIR/.zshrc" ]; then
  ZSHRC_SOURCE="$OFFLINE_DIR/.zshrc"
elif [ -n "$SCRIPT_DIR" ] && [ -s "$SCRIPT_DIR/.zshrc" ]; then
  ZSHRC_SOURCE="$SCRIPT_DIR/.zshrc"
else
  TMP_ZSHRC="$(mktemp)"
  ZSHRC_URL="$RAW_REPO_URL/.zshrc"
  if [ -n "$MIRROR_URL" ]; then
    ZSHRC_URL="$MIRROR_URL/.zshrc"
  fi

  if command -v curl &>/dev/null && curl -fsSL "$ZSHRC_URL" -o "$TMP_ZSHRC" 2>/dev/null && [ -s "$TMP_ZSHRC" ]; then
    ZSHRC_SOURCE="$TMP_ZSHRC"
  elif command -v wget &>/dev/null && wget -qO "$TMP_ZSHRC" "$ZSHRC_URL" 2>/dev/null && [ -s "$TMP_ZSHRC" ]; then
    ZSHRC_SOURCE="$TMP_ZSHRC"
  else
    rm -f "$TMP_ZSHRC"
    err "Failed to fetch .zshrc from $ZSHRC_URL. Installation aborted to prevent incomplete setup."
    exit 1
  fi
fi

if [ -f "$HOME/.zshrc" ]; then
  if cmp -s "$ZSHRC_SOURCE" "$HOME/.zshrc"; then
    ok "~/.zshrc is already up to date (no changes needed)"
  else
    BACKUP_FILE="$HOME/.zshrc.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$HOME/.zshrc" "$BACKUP_FILE"
    cp "$ZSHRC_SOURCE" "$HOME/.zshrc"
    ok "Updated ~/.zshrc (previous version backed up to $BACKUP_FILE)"
  fi
else
  cp "$ZSHRC_SOURCE" "$HOME/.zshrc"
  ok "Custom .zshrc copied to $HOME/.zshrc"
fi

[ -n "$TMP_ZSHRC" ] && rm -f "$TMP_ZSHRC"

# 6. Set Zsh as default shell
step "6. Verifying Default Shell"
ZSH_BIN="$(command -v zsh || true)"
if [ -n "$ZSH_BIN" ]; then
  if [ "$SHELL" = "$ZSH_BIN" ]; then
    ok "Zsh is already default shell ($SHELL)"
  else
    CURRENT_USER="${USER:-$(id -un)}"
    if command -v sudo &>/dev/null && [ "$EUID" -ne 0 ]; then
      if [ -r /dev/tty ]; then
        sudo chsh -s "$ZSH_BIN" "$CURRENT_USER" </dev/tty 2>/dev/null || chsh -s "$ZSH_BIN" </dev/tty || true
      else
        sudo chsh -s "$ZSH_BIN" "$CURRENT_USER" 2>/dev/null || chsh -s "$ZSH_BIN" || true
      fi
    else
      if [ -r /dev/tty ]; then
        chsh -s "$ZSH_BIN" </dev/tty 2>/dev/null || true
      else
        chsh -s "$ZSH_BIN" 2>/dev/null || true
      fi
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
  if command -v python3 &>/dev/null; then
    TMP_MERGED="$(mktemp)"
    MIGRATED_OUT="$(python3 - "${HIST_SOURCES[@]}" "$HOME/.zsh_history" "$TMP_MERGED" 2>/dev/null << 'PYEOF'
import sys
import os
import re
import time

sources = sys.argv[1:-2]
zsh_hist_path = sys.argv[-2]
out_path = sys.argv[-1]

def parse_bash_history(filepath):
    if not os.path.exists(filepath):
        return []
    with open(filepath, "r", encoding="utf-8", errors="replace") as f:
        lines = f.readlines()
    entries = []
    current_cmd = []
    current_ts = None
    in_single_quote = False
    in_double_quote = False
    in_heredoc = False
    heredoc_delimiter = ""
    keyword_depth = 0

    for line in lines:
        line_clean = line.rstrip("\r\n")
        line_stripped = line_clean.strip()

        # Bash timestamp header (#1712345678)
        if not current_cmd and re.match(r"^#[0-9]{9,12}$", line_stripped):
            current_ts = int(line_stripped[1:])
            continue

        current_cmd.append(line_clean)

        # Heredoc detection (e.g. <<EOF, <<- 'EOF')
        if not in_heredoc:
            hd_match = re.search(r"<<-?\s*['\"]?([A-Za-z0-9_]+)['\"]?", line_clean)
            if hd_match:
                in_heredoc = True
                heredoc_delimiter = hd_match.group(1)
        elif line_stripped == heredoc_delimiter:
            in_heredoc = False
            heredoc_delimiter = ""

        # Backslash line continuation
        bs_match = re.search(r"\\+$", line_clean)
        ends_with_backslash = bool(bs_match and (len(bs_match.group(0)) % 2 == 1))

        # Shell control structures (for/do/done, if/then/fi, etc.)
        tokens = re.findall(r"\b(if|then|elif|else|fi|for|while|until|do|done|case|esac)\b", line_clean)
        for tok in tokens:
            if tok in ("if", "for", "while", "until", "case"):
                keyword_depth += 1
            elif tok in ("fi", "done", "esac"):
                keyword_depth = max(0, keyword_depth - 1)

        # Quote balance check
        escaped = False
        for ch in line_clean:
            if ch == "\\" and not in_single_quote:
                escaped = not escaped
                continue
            if ch == "'" and not in_double_quote and not escaped:
                in_single_quote = not in_single_quote
            elif ch == '"' and not in_single_quote and not escaped:
                in_double_quote = not in_double_quote
            escaped = False

        is_continuation = ends_with_backslash or in_single_quote or in_double_quote or in_heredoc or (keyword_depth > 0)
        if not is_continuation:
            entries.append((current_ts, "\n".join(current_cmd)))
            current_cmd = []
            current_ts = None
            keyword_depth = 0

    if current_cmd:
        entries.append((current_ts, "\n".join(current_cmd)))
    return entries

def parse_zsh_history(filepath):
    if not os.path.exists(filepath):
        return []
    with open(filepath, "r", encoding="utf-8", errors="replace") as f:
        lines = f.readlines()
    entries = []
    current_cmd_lines = []
    current_ts = 0
    current_dur = 0
    header_regex = re.compile(r"^: ([0-9]+):([0-9]+);(.*)$")

    for line in lines:
        line_clean = line.rstrip("\r\n")
        if not current_cmd_lines:
            m = header_regex.match(line_clean)
            if m:
                current_ts = int(m.group(1))
                current_dur = int(m.group(2))
                cmd_first_line = m.group(3)
                if cmd_first_line.endswith("\\"):
                    current_cmd_lines.append(cmd_first_line[:-1])
                else:
                    entries.append((current_ts, current_dur, cmd_first_line))
                    current_cmd_lines = []
            else:
                entries.append((0, 0, line_clean))
        else:
            if line_clean.endswith("\\"):
                current_cmd_lines.append(line_clean[:-1])
            else:
                current_cmd_lines.append(line_clean)
                entries.append((current_ts, current_dur, "\n".join(current_cmd_lines)))
                current_cmd_lines = []

    if current_cmd_lines:
        entries.append((current_ts, current_dur, "\n".join(current_cmd_lines)))
    return entries

def format_zsh_entry(ts, dur, cmd_text):
    lines = cmd_text.split("\n")
    if not lines:
        return ""
    if len(lines) == 1:
        clean = lines[0]
        if clean.endswith("\\") and not clean.endswith("\\\\"):
            clean = clean + "\\"
        return f": {ts}:{dur};{clean}\n"
    else:
        out = []
        for i, l in enumerate(lines):
            if i == 0:
                out.append(f": {ts}:{dur};{l}\\")
            elif i < len(lines) - 1:
                out.append(f"{l}\\")
            else:
                clean = l
                if clean.endswith("\\") and not clean.endswith("\\\\"):
                    clean = clean + "\\"
                out.append(clean)
        return "\n".join(out) + "\n"

existing_zsh = parse_zsh_history(zsh_hist_path)
seen_cmds = {cmd.strip() for _, _, cmd in existing_zsh if cmd.strip()}

new_legacy_entries = []
# Fallback timestamp starting 30 days ago to preserve chronological flow
base_ts = int(time.time()) - (86400 * 30)

for src in sources:
    parsed_src = parse_bash_history(src)
    for ts, cmd in parsed_src:
        cmd_stripped = cmd.strip()
        if not cmd_stripped:
            continue
        if cmd_stripped not in seen_cmds:
            effective_ts = ts if (ts and ts > 0) else base_ts
            base_ts += 1
            new_legacy_entries.append((effective_ts, 0, cmd))
            seen_cmds.add(cmd_stripped)

if not new_legacy_entries:
    sys.exit(10)

with open(out_path, "w", encoding="utf-8") as f:
    for ts, dur, cmd in new_legacy_entries:
        f.write(format_zsh_entry(ts, dur, cmd))
    for ts, dur, cmd in existing_zsh:
        f.write(format_zsh_entry(ts, dur, cmd))

print(len(new_legacy_entries))
PYEOF
)"
    PY_STATUS=$?
    if [ $PY_STATUS -eq 0 ]; then
      [ -f "$HOME/.zsh_history" ] && cp "$HOME/.zsh_history" "$HOME/.zsh_history.bak.$(date +%Y%m%d_%H%M%S)"
      mv "$TMP_MERGED" "$HOME/.zsh_history"
      chmod 600 "$HOME/.zsh_history"
      ok "Migrated $MIGRATED_OUT new history entries from previous shell(s) into ~/.zsh_history"
    elif [ $PY_STATUS -eq 10 ]; then
      rm -f "$TMP_MERGED"
      ok "Shell history is already up to date (no new entries to migrate)"
    else
      rm -f "$TMP_MERGED"
      warn "History migration parser encountered an issue (preserved existing history)."
    fi
  else
    warn "python3 not found; skipping history migration to prevent multi-line command corruption."
  fi
else
  ok "No previous shell history files found to migrate"
fi

echo -e "\n${GREEN}${BOLD}✔ Setup Complete! Restart your terminal or run: zsh${RESET}"
