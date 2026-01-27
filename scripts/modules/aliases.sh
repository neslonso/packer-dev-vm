#!/bin/bash
# ==============================================================================
# ALIASES.SH - Configuración de aliases de shell
# ==============================================================================
# Añade aliases para Docker, Git y navegación
# Requiere: common.sh
# ==============================================================================

configure_aliases() {
    log_task "Configurando aliases..."

    ALIASES_CONTENT='
# ==============================================================================
# Docker Aliases
# ==============================================================================
alias d="docker"
alias dc="docker compose"
alias dps="docker ps --format \"table {{.Names}}\t{{.Status}}\t{{.Ports}}\""
alias dpsa="docker ps -a"
alias di="docker images"
alias dex="docker exec -it"
alias dlogs="docker logs -f"
alias dprune="docker system prune -af"
alias dcup="docker compose up -d"
alias dcdown="docker compose down"
alias dclogs="docker compose logs -f"
alias dcbuild="docker compose build --no-cache"

# ==============================================================================
# Git Aliases
# ==============================================================================
alias g="git"
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gp="git push"
alias gl="git pull"
alias gd="git diff"
alias gco="git checkout"
alias glog="git log --oneline --graph --decorate -20"
alias lg="lazygit"
alias lzd="lazydocker"

# ==============================================================================
# Navigation
# ==============================================================================
alias ll="ls -la"
alias ..="cd .."
alias ...="cd ../.."
'

    if [[ "${SHELL_TYPE}" == "zsh" ]]; then
        echo "${ALIASES_CONTENT}" >> "${HOME_DIR}/.zshrc"
    else
        echo "${ALIASES_CONTENT}" >> "${HOME_DIR}/.bashrc"
    fi

    # Fix ownership
    chown "${USERNAME}:${USERNAME}" "${HOME_DIR}/.zshrc" 2>/dev/null || true
    chown "${USERNAME}:${USERNAME}" "${HOME_DIR}/.bashrc" 2>/dev/null || true

    log_success "Aliases configurados"
}

# Ejecutar
configure_aliases
