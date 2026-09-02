# Customized Zsh Setup & Mirroring Toolkit

A lightweight, shell setup script and `.zshrc` configuration for **Oh My Zsh** and **Starship Prompt**. Supports **Online**, **HTTP Mirror**, and **Offline (Local Directory)** installation modes.

## Repository Contents

- `zsh-setup.sh`: Primary bootstrap script for dependencies, Oh My Zsh, Starship, plugins, and `.zshrc`.
- `.zshrc`: Customized Zsh configuration (Starship prompt, fzf-tab, tool aliases, plugin settings).
- `download-mirror.sh`: Downloader script to fetch and bundle all remote assets for restricted environments.
- `.gitignore`: Standard git ignore rules.

---

## Installation Modes

### 1. Direct Online Installation

Use when the target machine has direct internet access:

```bash
git clone https://github.com/your-username/zsh-customized.git
cd zsh-customized
chmod +x zsh-setup.sh download-mirror.sh
./zsh-setup.sh
```

---

### 2. HTTP Mirror Installation (Restricted Networks)

Use when the destination server cannot reach GitHub or starship.rs directly, but can reach an internal HTTP server.

#### Step 1: Download assets on an internet-connected host

```bash
./download-mirror.sh --output mirror_data
```

This archives Starship binaries, Oh My Zsh core, and all 4 custom plugins into `./mirror_data`.

#### Step 2: Serve `mirror_data` via HTTP

Serve the directory using Python, Nginx, or Caddy:

```bash
python3 -m http.server 8080 -d ./mirror_data
```

#### Step 3: Run setup on the target machine

```bash
./zsh-setup.sh --mirror http://<MIRROR_HOST>:8080
```

---

### 3. Fully Offline Installation (Air-Gapped Hosts)

Use when the destination host has no network connectivity:

1. Run `./download-mirror.sh --output mirror_data` on an internet-connected machine.
2. Copy this repository directory (including `mirror_data`) to the target machine via SCP/RSYNC/USB.
3. Run the installer pointing to the local mirror directory:

```bash
./zsh-setup.sh --offline-dir ./mirror_data
```

---

## Configured Plugins & Aliases

- **Prompt**: Starship (falls back to `robbyrussell` if starship binary is missing).
- **Plugins**: `zsh-autosuggestions`, `zsh-syntax-highlighting`, `zsh-completions`, `fzf-tab`.
- **System Tool Fallbacks**:
  - `bat` / `batcat` automatic alias detection.
  - `fd` / `fdfind` automatic symlinking and `fzf` command integration.
  - `eza` tree previews for `fzf-tab`.
