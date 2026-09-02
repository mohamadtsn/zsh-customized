#!/usr/bin/env bash
# =============================================================================
#  Download & Mirror Script for Oh My Zsh + Starship Setup
# =============================================================================
set -e

BOLD='\033[1m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'
step() { echo -e "\n${CYAN}${BOLD}▶ $1${RESET}"; }
ok()   { echo -e "${GREEN}✔ $1${RESET}"; }
warn() { echo -e "${YELLOW}⚠ $1${RESET}"; }
err()  { echo -e "${RED}✖ $1${RESET}"; }

OUT_DIR="mirror_data"

while [[ $# -gt 0 ]]; do
  case $1 in
    -o|--output)
      OUT_DIR="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: ./download-mirror.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  -o, --output DIR    Set output directory for mirror data (Default: mirror_data)"
      echo "  -h, --help          Show this help message"
      exit 0
      ;;
    *)
      err "Unknown option: $1"
      exit 1
      ;;
  esac
done

mkdir -p "$OUT_DIR/plugins"
TEMP_BUILD_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TEMP_BUILD_DIR"
}
trap cleanup EXIT

# 1. Download Starship
step "1. Downloading Starship Assets"
STARSHIP_URL="https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz"
echo "Fetching Starship binary from $STARSHIP_URL ..."
if curl -fsSL "$STARSHIP_URL" -o "$OUT_DIR/starship.tar.gz"; then
  ok "Saved $OUT_DIR/starship.tar.gz"
else
  err "Failed to download Starship binary."
  exit 1
fi

curl -fsSL https://starship.rs/install.sh -o "$OUT_DIR/starship-install.sh"
ok "Saved $OUT_DIR/starship-install.sh"

# 2. Download Oh My Zsh
step "2. Archiving Oh My Zsh Core"
OMZ_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
curl -fsSL "$OMZ_INSTALL_URL" -o "$OUT_DIR/omz-install.sh"
ok "Saved $OUT_DIR/omz-install.sh"

echo "Cloning Oh My Zsh repository..."
OMZ_TEMP="$TEMP_BUILD_DIR/ohmyzsh"
git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$OMZ_TEMP"
tar -czf "$OUT_DIR/ohmyzsh.tar.gz" -C "$TEMP_BUILD_DIR" .oh-my-zsh 2>/dev/null || \
  ( mv "$OMZ_TEMP" "$TEMP_BUILD_DIR/.oh-my-zsh" && tar -czf "$OUT_DIR/ohmyzsh.tar.gz" -C "$TEMP_BUILD_DIR" .oh-my-zsh )
ok "Saved $OUT_DIR/ohmyzsh.tar.gz"

# 3. Download OMZ Custom Plugins
step "3. Archiving Custom OMZ Plugins"
plugins=(
  "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions.git"
  "zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting.git"
  "zsh-completions|https://github.com/zsh-users/zsh-completions.git"
  "fzf-tab|https://github.com/Aloxaf/fzf-tab.git"
)

for item in "${plugins[@]}"; do
  IFS="|" read -r p_name p_repo <<< "$item"
  echo "Cloning $p_name..."
  p_temp="$TEMP_BUILD_DIR/$p_name"
  git clone --depth 1 "$p_repo" "$p_temp"
  tar -czf "$OUT_DIR/plugins/$p_name.tar.gz" -C "$p_temp" .
  ok "Saved $OUT_DIR/plugins/$p_name.tar.gz"
done

step "Mirror Data Created Successfully!"
echo -e "${GREEN}${BOLD}Output directory:${RESET} $(realpath "$OUT_DIR")"
echo ""
echo -e "${BOLD}Usage Scenarios:${RESET}"
echo "1. Offline Server (Local Directory Copy):"
echo "   Transfer this repository + '$OUT_DIR' folder to the target server, then run:"
echo -e "   ${CYAN}./zsh-setup.sh --offline-dir ./$OUT_DIR${RESET}"
echo ""
echo "2. HTTP Mirror Server:"
echo "   Serve '$OUT_DIR' via HTTP (e.g. using python, nginx, or caddy):"
echo -e "   ${CYAN}python3 -m http.server 8080 -d ./$OUT_DIR${RESET}"
echo "   Then on the restricted target server, run:"
echo -e "   ${CYAN}./zsh-setup.sh --mirror http://<MIRROR_HOST>:8080${RESET}"
