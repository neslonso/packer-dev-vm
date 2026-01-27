#!/bin/bash
# ==============================================================================
# SUBLIME-MERGE.SH - Instalación de Sublime Merge
# ==============================================================================
# Requiere: common.sh
# ==============================================================================

install_sublime_merge() {
    if [[ "${INSTALL_SUBLIMEMERGE}" != "true" ]]; then
        log_task "Saltando instalación de Sublime Merge (deshabilitado)"
        return 0
    fi

    log_section "Instalando Sublime Merge..."

    # Add Sublime Text/Merge repository
    curl -fsSL https://download.sublimetext.com/sublimehq-pub.gpg | gpg --dearmor -o /etc/apt/keyrings/sublimehq.gpg

    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/sublimehq.gpg] https://download.sublimetext.com/ apt/stable/" > /etc/apt/sources.list.d/sublime-text.list

    apt-get update
    apt-get install -y sublime-merge

    log_success "Sublime Merge installed successfully"
}

# Ejecutar
install_sublime_merge
