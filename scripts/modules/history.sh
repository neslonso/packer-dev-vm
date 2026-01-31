#!/bin/bash
# ==============================================================================
# HISTORY.SH - Configuración del historial de shell
# ==============================================================================
# Configura: historial ilimitado, timestamps ISO con TZ, sincro multi-terminal
# Soporta: bash y zsh
# Requiere: common.sh
# ==============================================================================

configure_history() {
    log_task "Configurando historial de shell..."

    # -------------------------------------------------------------------------
    # Configuración para BASH
    # -------------------------------------------------------------------------
    BASH_HISTORY_CONFIG='
# ==============================================================================
# HISTORIAL: Ilimitado, ISO+TZ, Multi-Terminal
# ==============================================================================
# Ilimitado: variable vacía = sin límite (según man bash)
HISTSIZE=
HISTFILESIZE=

# Timestamp ISO con timezone
HISTTIMEFORMAT="%F %T %Z -> "

# Evitar espacios iniciales y duplicados inmediatos
HISTCONTROL=ignoreboth

# Asegurar append (no sobrescribir)
shopt -s histappend

# Utilidad para no machacar PROMPT_COMMAND si ya viene con cosas
_pc_add() {
    if [[ -n "$PROMPT_COMMAND" ]]; then
        PROMPT_COMMAND="$PROMPT_COMMAND; $1"
    else
        PROMPT_COMMAND="$1"
    fi
}

# Sincronización segura entre terminales:
# -n: leer nuevas del fichero (las que no tengamos en memoria)
# -a: escribir las nuevas que tengamos en memoria al fichero
# -c: limpia memoria
# -r: recarga del fichero
_pc_add "history -n"
_pc_add "history -a"
_pc_add "history -c"
_pc_add "history -r"
# ==============================================================================
'

    # -------------------------------------------------------------------------
    # Configuración para ZSH
    # -------------------------------------------------------------------------
    ZSH_HISTORY_CONFIG='
# ==============================================================================
# HISTORIAL: Grande, ISO+TZ, Multi-Terminal
# ==============================================================================
# Historial muy grande (zsh no soporta ilimitado como bash)
HISTSIZE=1000000
SAVEHIST=1000000
HISTFILE="${HOME}/.zsh_history"

# Timestamps en historial (formato extendido de zsh)
setopt EXTENDED_HISTORY

# Añadir al historial, no sobrescribir
setopt APPEND_HISTORY

# Escribir al historial inmediatamente, no al salir
setopt INC_APPEND_HISTORY

# Compartir historial entre todas las sesiones
setopt SHARE_HISTORY

# No guardar duplicados
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS

# No guardar comandos que empiezan con espacio
setopt HIST_IGNORE_SPACE

# Eliminar espacios extra
setopt HIST_REDUCE_BLANKS

# No ejecutar inmediatamente al expandir historial
setopt HIST_VERIFY
# ==============================================================================
'

    # Aplicar configuración según el shell
    if [[ "${SHELL_TYPE}" == "zsh" ]]; then
        echo "${ZSH_HISTORY_CONFIG}" >> "${HOME_DIR}/.zshrc"
    else
        echo "${BASH_HISTORY_CONFIG}" >> "${HOME_DIR}/.bashrc"
    fi

    # Fix ownership
    chown "${USERNAME}:${USERNAME}" "${HOME_DIR}/.zshrc" 2>/dev/null || true
    chown "${USERNAME}:${USERNAME}" "${HOME_DIR}/.bashrc" 2>/dev/null || true

    log_success "Historial de shell configurado"
}

# Ejecutar
configure_history
