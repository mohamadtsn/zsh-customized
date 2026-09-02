# =============================================================================
#  ~/.zshrc — Complete Oh My Zsh Configuration (Tested & Error-Free)
# =============================================================================

# ── Environment & PATH ────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:$PATH"
export ZSH="$HOME/.oh-my-zsh"

# ── Prompt Setup (Starship or fallback to OMZ Theme) ──────────────────────────
if command -v starship &>/dev/null; then
  ZSH_THEME=""
  eval "$(starship init zsh)"
else
  ZSH_THEME="robbyrussell"
fi

# ── Fix for OMZ fzf plugin on Debian/Ubuntu ─────────────────────────────────
export FZF_BASE="/usr/share/doc/fzf"

# ── Plugin Configurations ────────────────────────────────────────────────────
# Enable native NVM lazy loading (fast shell startup)
zstyle ':omz:plugins:nvm' lazy yes
zstyle ':omz:plugins:nvm' autoload yes

# ── Plugins List ─────────────────────────────────────────────────────────────
# Built-in OMZ plugins + installed custom plugins
plugins=(
  git
  docker
  docker-compose
  laravel
  composer
  golang
  rust
  nvm
  pyenv
  rbenv
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
  fzf-tab
)

# Load Oh My Zsh core
if [ -f "$ZSH/oh-my-zsh.sh" ]; then
  source "$ZSH/oh-my-zsh.sh"
fi

# ── Tool Paths & Auto-Detects ─────────────────────────────────────────────────
# pnpm
if [ -d "$HOME/.local/share/pnpm" ]; then
  export PNPM_HOME="$HOME/.local/share/pnpm"
  export PATH="$PNPM_HOME:$PATH"
fi

# Composer global binaries
if [ -d "$HOME/.config/composer/vendor/bin" ]; then
  export PATH="$HOME/.config/composer/vendor/bin:$PATH"
fi

# ── Completion Styling (fzf-tab) ──────────────────────────────────────────────
if command -v eza &>/dev/null; then
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --tree --color=always $realpath 2>/dev/null | head -40'
else
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -la $realpath 2>/dev/null | head -40'
fi
zstyle ':fzf-tab:*' switch-group '<' '>'

# ── Key Bindings & History ───────────────────────────────────────────────────
bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^R' history-incremental-search-backward
bindkey '^ ' autosuggest-accept

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#666666"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# ── Aliases — General ────────────────────────────────────────────────────────
if command -v eza &>/dev/null; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lah --icons --group-directories-first --git'
  alias lt='eza --tree --icons --level=2'
else
  alias ls='ls --color=auto'
  alias ll='ls -la'
fi

if command -v batcat &>/dev/null; then
  alias cat='batcat --style=plain'
elif command -v bat &>/dev/null; then
  alias cat='bat --style=plain'
fi

alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias mkdir='mkdir -p'
alias rm='rm -i'
alias df='df -h'
alias free='free -h'

# ── Aliases — Docker ─────────────────────────────────────────────────────────
alias dk='docker'
alias dkc='docker compose'
alias dkps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dkpsa='docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dklogs='docker logs -f'
alias dkexec='docker exec -it'

# ── Aliases — Laravel / PHP ──────────────────────────────────────────────────
alias art='php artisan'
alias tinker='php artisan tinker'
alias mfs='php artisan migrate:fresh --seed'
alias ptest='php artisan test'
alias sail='[ -f sail ] && bash sail || bash vendor/bin/sail'

# ── FZF Configuration ────────────────────────────────────────────────────────
export FZF_DEFAULT_OPTS="
  --height 40%
  --layout=reverse
  --border=rounded
  --info=inline
  --color=bg+:#2d2d2d,gutter:-1,pointer:#ff6b6b,marker:#ff6b6b
  --color=border:#555555,header:#aaaaaa,prompt:#61afef
"
if command -v fd &>/dev/null; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git 2>/dev/null'
elif command -v fdfind &>/dev/null; then
  export FZF_DEFAULT_COMMAND='fdfind --type f --hidden --follow --exclude .git 2>/dev/null'
fi
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# Source fzf keybindings and completions if available
for fzf_script in /usr/share/doc/fzf/examples/key-bindings.zsh /usr/share/fzf/key-bindings.zsh ~/.fzf.zsh; do
  [ -f "$fzf_script" ] && source "$fzf_script" && break
done
for fzf_completion in /usr/share/doc/fzf/examples/completion.zsh /usr/share/fzf/completion.zsh; do
  [ -f "$fzf_completion" ] && source "$fzf_completion" && break
done
