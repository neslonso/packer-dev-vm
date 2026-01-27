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

    # Instalar extensiones básicas
    EXTENSIONS=(
        "ms-azuretools.vscode-docker"
        "ms-vscode-remote.remote-containers"
        "eamodio.gitlens"
        "mhutchie.git-graph"
        "EditorConfig.EditorConfig"
        "redhat.vscode-yaml"
    )

    log_task "Installing VS Code extensions..."
    for ext in "${EXTENSIONS[@]}"; do
        if run_as_user "code --install-extension ${ext} --force" 2>&1; then
            log_success "Installed extension: ${ext}"
        else
            log_warning "Failed to install extension: ${ext}"
        fi
    done

    log_success "VS Code instalado"
}

# Ejecutar
install_vscode
