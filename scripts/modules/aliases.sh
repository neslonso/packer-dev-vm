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
# description: Ejecutar docker
alias d="docker"
# description: Gestionar docker compose
alias dc="docker compose"
# description: Listar contenedores activos
alias dps="docker ps --format \"table {{.Names}}\t{{.Status}}\t{{.Ports}}\""
# description: Listar todos los contenedores
alias dpsa="docker ps -a"
# description: Listar imágenes de docker
alias di="docker images"
# description: Ejecutar comando en contenedor
alias dex="docker exec -it"
# description: Ver logs de un contenedor
alias dlogs="docker logs -f"
# description: Limpiar sistema docker
alias dprune="docker system prune -af"
# description: Levantar servicios compose
alias dcup="docker compose up -d"
# description: Bajar servicios compose
alias dcdown="docker compose down"
# description: Ver logs de compose
alias dclogs="docker compose logs -f"
# description: Reconstruir servicios compose
alias dcbuild="docker compose build --no-cache"

# ==============================================================================
# Git Aliases
# ==============================================================================
# description: Ejecutar git
alias g="git"
# description: Ver estado de git
alias gs="git status"
# description: Añadir archivos al commit
alias ga="git add"
# description: Crear un commit
alias gc="git commit"
# description: Subir cambios al repo
alias gp="git push"
# description: Bajar cambios del repo
alias gl="git pull"
# description: Ver diferencias
alias gd="git diff"
# description: Cambiar de rama/archivo
alias gco="git checkout"
# description: Ver historial gráfico
alias glog="git log --oneline --graph --decorate -20"
# description: Interfaz TUI para git
alias lg="lazygit"
# description: Interfaz TUI para docker
alias lzd="lazydocker"

# ==============================================================================
# Navigation
# ==============================================================================
# description: Listado detallado de archivos
alias ll="ls -la"
# description: Subir un nivel de directorio
alias ..="cd .."
# description: Subir dos niveles de directorio
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
