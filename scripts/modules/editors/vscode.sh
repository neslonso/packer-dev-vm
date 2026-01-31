#!/bin/bash
# ==============================================================================
# VSCODE.SH - Instalación de Visual Studio Code
# ==============================================================================
# Requiere: common.sh
# ==============================================================================

install_vscode() {
    if [[ "${INSTALL_VSCODE}" != "true" ]]; then
        log_task "Saltando instalación de VS Code (deshabilitado)"
        return 0
    fi

    log_section "Instalando VS Code..."

    # Microsoft GPG key
    if ! download_and_verify_gpg_key "https://packages.microsoft.com/keys/microsoft.asc" "/usr/share/keyrings/packages.microsoft.gpg" "$MICROSOFT_GPG_FINGERPRINT" "Microsoft GPG key"; then
        log_msg "ERROR: Failed to verify Microsoft GPG key"
        exit 1
    fi
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list

    apt-get update
    apt-get install -y code

    # Apply settings
    apply_vscode_settings "Code"

    # Instalar extensiones desde variable
    if [[ -n "${VSCODE_EXTENSIONS}" ]]; then
        log_task "Instalando extensiones de VS Code..."
        IFS=',' read -ra EXTENSIONS <<< "${VSCODE_EXTENSIONS}"
        for ext in "${EXTENSIONS[@]}"; do
            if run_as_user "code --install-extension ${ext} --force" 2>&1; then
                log_success "Extensión instalada: ${ext}"
            else
                log_warning "Error instalando extensión: ${ext}"
            fi
        done
    fi

    log_success "VS Code instalado"
}

# Ejecutar
install_vscode
