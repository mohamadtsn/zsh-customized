# =============================================================================
#  ~/.zshrc — Complete Oh My Zsh Configuration (Tested & Error-Free)
# =============================================================================

# ── Environment & PATH ────────────────────────────────────────────────────────
typeset -U PATH path
export PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:$PATH"
export ZSH="$HOME/.oh-my-zsh"

# ── Legacy Shell Compatibility (.profile & .bash_aliases) ────────────────────
# Ensure environment variables, PATH, and exports from previous shell are loaded
if [ -f "$HOME/.profile" ]; then
  emulate sh -c 'source "$HOME/.profile"'
elif [ -f "$HOME/.bash_profile" ]; then
  emulate sh -c 'source "$HOME/.bash_profile"'
fi

# Source custom aliases from previous bash configuration if present
if [ -f "$HOME/.bash_aliases" ]; then
  source "$HOME/.bash_aliases"
fi

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
elif command -v exa &>/dev/null; then
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'exa --tree --color=always $realpath 2>/dev/null | head -40'
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
  alias la='eza -a --icons'
elif command -v exa &>/dev/null; then
  alias ls='exa --icons --group-directories-first'
  alias ll='exa -lah --icons --group-directories-first --git'
  alias lt='exa --tree --icons --level=2'
  alias la='exa -a --icons'
else
  alias ls='ls --color=auto'
  alias ll='ls -la'
  alias la='ls -A'
fi

if command -v batcat &>/dev/null; then
  alias cat='batcat --style=plain'
elif command -v bat &>/dev/null; then
  alias cat='bat --style=plain'
fi

alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias cd..='cd ..'
alias mkdir='mkdir -p'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias df='df -h'
alias free='free -h'
alias cls='clear'
alias reload='source ~/.zshrc'
alias path='echo -e ${PATH//:/\\n}'

# ── Aliases — System & Monitoring ────────────────────────────────────────────
alias pscpu='ps auxf | sort -nr -k 3 | head -10'
alias psmem='ps auxf | sort -nr -k 4 | head -10'
alias ports='sudo ss -tulanp'
alias myip='curl -fsSL ifconfig.me 2>/dev/null || curl -fsSL ipinfo.io/ip 2>/dev/null'
alias ping='ping -c 5'
alias untar='tar -zxvf'
alias mktar='tar -zcvf'

# ── Aliases — Git ────────────────────────────────────────────────────────────
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gc='git commit -m'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gcan='git commit --amend --no-edit'
alias gcl='git clone'
alias gp='git push'
alias gl='git log --oneline --graph --decorate -15'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias gsw='git switch'
alias gswc='git switch -c'
alias gsta='git stash push'
alias gstp='git stash pop'
alias gstl='git stash list'
alias gundo='git reset --soft HEAD~1'

# ── Aliases — Docker ─────────────────────────────────────────────────────────
alias dk='docker'
alias dkc='docker compose'
alias dkps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dkpsa='docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dklogs='docker logs -f'
alias dkexec='docker exec -it'
alias dkstop='docker stop $(docker ps -q)'
alias dkclean='docker system prune -f'
alias dkcleanall='docker system prune -af --volumes'
alias dkstats='docker stats --no-stream'

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
