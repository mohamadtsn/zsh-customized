# zsh-customized

Bootstrap toolkit for deploying a customized Zsh environment (Oh My Zsh + Starship prompt) on Linux hosts, with three install modes: direct online, HTTP mirror, and air-gapped offline. Four files, no build system, no CI, no test suite — verification is shell syntax checks.

## Files

- `zsh-setup.sh` — main installer: system packages, Starship, Oh My Zsh, 4 custom plugins, `.zshrc` deploy, default-shell change, history/profile migration from bash.
- `.zshrc` — the deployed Zsh config; the repo copy is the source of truth for `~/.zshrc`.
- `download-mirror.sh` — clones/downloads all remote assets into `mirror_data/` for mirror and offline installs.
- `README.md` — user-facing install docs; keep in sync with script flags.

## Commands

Syntax check (the only automated verification — run after every edit):

```bash
bash -n zsh-setup.sh && bash -n download-mirror.sh && zsh -n .zshrc
```

Run the installer (mutates the host machine — see Pitfalls):

```bash
./zsh-setup.sh                # online
./zsh-setup.sh -u             # idempotent re-run / update
./zsh-setup.sh --mirror http://<host>:8080
./zsh-setup.sh --offline-dir ./mirror_data
./download-mirror.sh --output mirror_data
python3 -m http.server 8080 -d ./mirror_data   # serve mirror_data
```

## Conventions

- Both scripts share the same header pattern: `set -e`, ANSI color vars, `step()/ok()/warn()/err()` logging helpers, argument parsing via `while [[ $# -gt 0 ]]; do case $1 in ... esac; done`. Match this style; print messages through the helpers, not bare `echo`.
- Idempotency is a hard requirement: every step checks before acting (`command -v`, `[ -d ]`, `cmp -s` before copying) so `-u/--update` re-runs are safe. Preserve this in any change.
- Backups use timestamped suffixes, e.g. `~/.zshrc.bak.YYYYMMDD_HHMMSS`.
- `.zshrc` uses `# ── Section ──` banner comments; aliases are grouped per tool (General, Docker, Laravel/PHP, FZF).
- Debian/Ubuntu binary renames are handled twice: the script symlinks `fdfind`/`batcat` into `~/.local/bin`, and `.zshrc` falls back via `command -v` between `bat`/`batcat` and `fd`/`fdfind`. Follow this dual-detection pattern for new tools.
- Commits follow Conventional Commits with a scope, e.g. `fix(setup): fallback to id -un when USER environment variable is unset`.

## Pitfalls

- Never run `./zsh-setup.sh` casually on a dev machine: it apt-installs with sudo, overwrites `~/.zshrc` (with backup), runs `chsh`, and rewrites `~/.zsh_history`. For testing, stick to syntax checks or a disposable container/VM.
- The 4 custom plugins (zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions, fzf-tab) are listed in TWO places — `plugins_info` in `zsh-setup.sh` and `plugins` in `download-mirror.sh`. Adding or removing one requires editing both, plus the `plugins=(...)` array in `.zshrc`.
- `.zshrc` also enables built-in OMZ plugins (git, docker, nvm, pyenv, rbenv, ...) that `zsh-setup.sh` does NOT install; only the 4 custom ones are fetched.
- `download-mirror.sh` hardcodes the Starship tarball to `x86_64-unknown-linux-gnu` — mirror/offline installs break on other architectures.
- `mirror_data/` and `*.tar.gz` are gitignored; never commit mirror artifacts.
- A missing Starship binary is a supported state: `.zshrc` falls back to `ZSH_THEME="robbyrussell"`. Keep that fallback intact.
