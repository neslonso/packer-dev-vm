#!/bin/bash
# ==============================================================================
# ANTIGRAVITY.SH - Instalación de Google Antigravity IDE
# ==============================================================================
# Requiere: common.sh
# ==============================================================================

install_antigravity() {
    if [[ "${INSTALL_ANTIGRAVITY}" != "true" ]]; then
        log_task "Saltando instalación de Google Antigravity IDE (deshabilitado)"
        return 0
    fi

    log_section "Instalando Google Antigravity IDE..."

    # Download and add Google Antigravity repository GPG key
    curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | gpg --dearmor -o /etc/apt/keyrings/antigravity-repo-key.gpg

    # Add Antigravity official repository
    echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev antigravity-debian main" > /etc/apt/sources.list.d/antigravity.list

    apt-get update
    apt-get install -y antigravity

    log_success "Google Antigravity IDE installed successfully"

    # Configure Antigravity settings
    apply_vscode_settings "Antigravity"

    # Configure desktop launcher
    if [[ -f "/usr/share/applications/antigravity.desktop" ]]; then
        run_as_user "mkdir -p '${HOME_DIR}/.local/share/applications'"
        cp /usr/share/applications/antigravity.desktop "${HOME_DIR}/.local/share/applications/"
        chown "${USERNAME}:${USERNAME}" "${HOME_DIR}/.local/share/applications/antigravity.desktop"
    fi

    log_success "Google Antigravity IDE configurado"
}

# Ejecutar
install_antigravity
