#!/bin/bash
# ==============================================================================
# FONTS.SH - Instalación de Nerd Fonts
# ==============================================================================
# Instala: Nerd Font seleccionada (JetBrainsMono, FiraCode, etc.)
# Requiere: common.sh
# ==============================================================================

install_nerd_font() {
    if [[ "${NERD_FONT}" == "none" ]]; then
        log_section "Saltando instalación de Nerd Font (nerd_font=none)..."
        return 0
    fi

    log_section "Instalando ${NERD_FONT} Nerd Font..."

    FONT_DIR="${HOME_DIR}/.local/share/fonts"
    run_as_user "mkdir -p '${FONT_DIR}'"

    # Try to fetch latest version from GitHub API, with fallback
    FONT_VERSION=$(curl --max-time 30 --fail --silent --show-error https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest 2>/dev/null | jq -r '.tag_name' 2>/dev/null || echo "")

    if [[ -z "$FONT_VERSION" || "$FONT_VERSION" == "null" ]]; then
        log_warning "Failed to fetch latest font version from GitHub API, using fallback"
        FONT_VERSION="v3.1.1"
    fi

    log_task "Downloading ${NERD_FONT} Nerd Font ${FONT_VERSION}..."

    FONT_FILE="/tmp/${NERD_FONT}.zip"
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/${NERD_FONT}.zip"

    if curl --max-time 120 --fail -Lo "${FONT_FILE}" "${FONT_URL}" 2>&1; then
        if validate_zip_archive "${FONT_FILE}" "${NERD_FONT} font"; then
            unzip -o "${FONT_FILE}" -d "${FONT_DIR}"
            chown -R "${USERNAME}:${USERNAME}" "${FONT_DIR}"
            log_success "${NERD_FONT} Nerd Font installed successfully"
        else
            log_msg "ERROR: ${NERD_FONT} font archive validation failed"
            exit 1
        fi
        rm "${FONT_FILE}"
    else
        log_msg "ERROR: Failed to download ${NERD_FONT} Nerd Font from ${FONT_URL}"
        exit 1
    fi

    # Actualizar cache de fuentes
    fc-cache -fv

    log_success "Nerd Font instalada"
}

# Ejecutar
install_nerd_font
